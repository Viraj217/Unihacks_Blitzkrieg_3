import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

// ===================== MODELS =====================

class Vault {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final bool isPrivate;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VaultCreator? creator;
  final List<VaultMessage> messages;
  final int? messageCount;

  Vault({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    this.isPrivate = false,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
    this.creator,
    this.messages = const [],
    this.messageCount,
  });

  factory Vault.fromJson(Map<String, dynamic> json) {
    // Support both nested creator and flat creator_* (from list API)
    VaultCreator? creator;
    if (json['creator'] != null && json['creator'] is Map) {
      creator = VaultCreator.fromJson(
        Map<String, dynamic>.from(json['creator'] as Map),
      );
    } else if (json['creator_username'] != null) {
      creator = VaultCreator(
        id: json['created_by']?.toString() ?? '',
        username: json['creator_username']?.toString() ?? '',
        displayName: json['creator_display_name']?.toString(),
        avatarUrl: json['creator_avatar_url']?.toString(),
      );
    }
    // message_count can be int or string (PostgreSQL bigint)
    int? messageCount;
    final mc = json['message_count'];
    if (mc != null) {
      messageCount = mc is int ? mc : int.tryParse(mc.toString());
    }
    return Vault(
      id: json['id']?.toString() ?? '',
      groupId: json['group_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      isPrivate: json['is_private'] == true,
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      creator: creator,
      messages: json['messages'] != null && json['messages'] is List
          ? (json['messages'] as List)
                .map((m) => VaultMessage.fromJson(Map<String, dynamic>.from(m as Map)))
                .toList()
          : [],
      messageCount: messageCount,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}

class VaultCreator {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  VaultCreator({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  factory VaultCreator.fromJson(Map<String, dynamic> json) {
    return VaultCreator(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
    );
  }
}

class VaultMessage {
  final String id;
  final String vaultId;
  final String senderId;
  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final String messageType;
  final String content;
  final String? mediaUrl;
  final String? replyToId;
  final bool isEdited;
  final bool isOptimistic;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultMessage({
    required this.id,
    required this.vaultId,
    required this.senderId,
    this.senderUsername,
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.messageType = 'text',
    required this.content,
    this.mediaUrl,
    this.replyToId,
    this.isEdited = false,
    this.isOptimistic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VaultMessage.fromJson(Map<String, dynamic> json) {
    return VaultMessage(
      id: json['id'] ?? '',
      vaultId: json['vault_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderUsername: json['sender_username'],
      senderDisplayName: json['sender_display_name'],
      senderAvatarUrl: json['sender_avatar_url'],
      messageType: json['message_type'] ?? 'text',
      content: json['content'] ?? '',
      mediaUrl: json['media_url'],
      replyToId: json['reply_to_id'],
      isEdited: json['is_edited'] ?? false,
      isOptimistic: false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_type': messageType,
      'content': content,
      'media_url': mediaUrl,
      'reply_to_id': replyToId,
    };
  }
}

// ===================== SERVICE =====================

class VaultService {
  static final String _baseUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://10.223.64.91:3000';
  static String get _vaultBaseUrl =>
      _baseUrl.endsWith('/vault') ? _baseUrl : '$_baseUrl/vault';

  static Map<String, String> get _headers {
    final token = SupabaseService.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Wraps an HTTP call and turns socket/IO errors into a clear message.
  static Future<T> _guardNetwork<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on SocketException catch (e) {
      throw Exception(
        'Cannot reach server. Check your connection and that the backend is running at $_vaultBaseUrl. (${e.message})',
      );
    } on HttpException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on IOException catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  // Create a new vault (optionally with an initial message)
  static Future<Vault> createVault({
    required String groupId,
    required String name,
    String? description,
    bool isPrivate = false,
    String? avatarUrl,
    String? initialMessage,
  }) async {
    final body = <String, dynamic>{
      'group_id': groupId,
      'name': name,
      'description': description,
      'is_private': isPrivate,
      'avatar_url': avatarUrl,
    };
    final trimmed = initialMessage?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body['initial_message'] = trimmed;
    }
    return _guardNetwork(() async {
      final response = await http.post(
        Uri.parse('$_vaultBaseUrl/'),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Vault.fromJson(data['data']!['vault'] as Map<String, dynamic>);
      }
      throw Exception('Failed to create vault: ${response.body}');
    });
  }

  // Get vault by ID
  static Future<Vault> getVaultById(String vaultId) async {
    return _guardNetwork(() async {
      final response = await http.get(
        Uri.parse('$_vaultBaseUrl/$vaultId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Vault.fromJson(data['data']!['vault'] as Map<String, dynamic>);
      }
      throw Exception('Failed to get vault: ${response.body}');
    });
  }

  // Get all vaults for a group
  static Future<List<Vault>> getGroupVaults(String groupId) async {
    return _guardNetwork(() async {
      final response = await http.get(
        Uri.parse('$_vaultBaseUrl/group/$groupId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final vaultsJson = data['data']!['vaults'] as List<dynamic>;
        return vaultsJson
            .map((json) => Vault.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();
      }
      throw Exception('Failed to get group vaults: ${response.body}');
    });
  }

  // Add message to vault
  static Future<VaultMessage> addMessage({
    required String vaultId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? replyToId,
  }) async {
    return _guardNetwork(() async {
      final response = await http.post(
        Uri.parse('$_vaultBaseUrl/$vaultId/messages'),
        headers: _headers,
        body: jsonEncode({
          'content': content,
          'message_type': messageType,
          'media_url': mediaUrl,
          'reply_to_id': replyToId,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VaultMessage.fromJson(
          data['data']!['message'] as Map<String, dynamic>,
        );
      }
      throw Exception('Failed to add message: ${response.body}');
    });
  }

  // Update message
  static Future<VaultMessage> updateMessage({
    required String vaultId,
    required String messageId,
    required String content,
    String? mediaUrl,
  }) async {
    return _guardNetwork(() async {
      final response = await http.put(
        Uri.parse('$_vaultBaseUrl/$vaultId/messages/$messageId'),
        headers: _headers,
        body: jsonEncode({'content': content, 'media_url': mediaUrl}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VaultMessage.fromJson(
          data['data']!['message'] as Map<String, dynamic>,
        );
      }
      throw Exception('Failed to update message: ${response.body}');
    });
  }

  // Delete message
  static Future<bool> deleteMessage({
    required String vaultId,
    required String messageId,
  }) async {
    return _guardNetwork(() async {
      final response = await http.delete(
        Uri.parse('$_vaultBaseUrl/$vaultId/messages/$messageId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    });
  }

  // Delete vault
  static Future<bool> deleteVault(String vaultId) async {
    return _guardNetwork(() async {
      final response = await http.delete(
        Uri.parse('$_vaultBaseUrl/$vaultId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    });
  }
}
