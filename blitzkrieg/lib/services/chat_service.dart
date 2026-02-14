import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';

// ===================== MODELS =====================

class ChatMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderUsername;
  final String senderDisplayName;
  final String? senderAvatarUrl;
  final String messageType;
  final String content;
  final String? mediaUrl;
  final String? replyToId;
  final bool isEdited;
  final bool isOptimistic; // true for locally-added messages not yet confirmed
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderUsername,
    required this.senderDisplayName,
    this.senderAvatarUrl,
    this.messageType = 'text',
    required this.content,
    this.mediaUrl,
    this.replyToId,
    this.isEdited = false,
    this.isOptimistic = false,
    required this.createdAt,
  });

  factory ChatMessage.fromSupabaseRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? senderProfile,
  }) {
    final sender = row['profiles'] ?? senderProfile;
    return ChatMessage(
      id: row['id'] ?? '',
      groupId: row['group_id'] ?? '',
      senderId: sender?['id'] ?? row['sender_id'] ?? '',
      senderUsername: sender?['username'] ?? '',
      senderDisplayName: sender?['display_name'] ?? '',
      senderAvatarUrl: sender?['avatar_url'],
      messageType: row['message_type'] ?? 'text',
      content: row['content'] ?? '',
      mediaUrl: row['media_url'],
      replyToId: row['reply_to_id'],
      isEdited: row['is_edited'] ?? false,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory ChatMessage.fromSocketEvent(Map<String, dynamic> data) {
    final sender = data['sender'] as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: data['id'] ?? '',
      groupId: data['groupId'] ?? data['group_id'] ?? '',
      senderId: sender['id'] ?? data['senderId'] ?? '',
      senderUsername: sender['username'] ?? '',
      senderDisplayName: sender['displayName'] ?? sender['display_name'] ?? '',
      senderAvatarUrl: sender['avatarUrl'] ?? sender['avatar_url'],
      messageType: data['messageType'] ?? data['message_type'] ?? 'text',
      content: data['content'] ?? '',
      mediaUrl: data['mediaUrl'] ?? data['media_url'],
      replyToId: data['replyToId'] ?? data['reply_to_id'],
      isEdited: data['isEdited'] ?? data['is_edited'] ?? false,
      createdAt:
          DateTime.tryParse(
            data['createdAt']?.toString() ??
                data['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }
}

class GroupConversation {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String inviteCode;
  final int memberCount;
  ChatMessage? lastMessage;
  int unreadCount;

  GroupConversation({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.inviteCode,
    this.memberCount = 0,
    this.lastMessage,
    this.unreadCount = 0,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
  }
}

// ===================== CHAT SERVICE =====================

class ChatService {
  static IO.Socket? _socket;
  static bool _isConnected = false;
  static String? _currentProfileId;
  static String? _currentUsername;
  static String? _currentDisplayName;
  static const _uuid = Uuid();

  // Stream controllers for Socket.IO events
  static final _socketMessageController =
      StreamController<ChatMessage>.broadcast();
  static final _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _connectionController = StreamController<bool>.broadcast();

  static String get _baseUrl {
    final ip = dotenv.env['IP_ADDRESS'] ?? '10.0.2.2';
    return 'http://$ip:3000';
  }

  static bool get isConnected => _isConnected;
  static String? get currentProfileId => _currentProfileId;

  // Streams
  static Stream<ChatMessage> get onSocketMessage =>
      _socketMessageController.stream;
  static Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  static Stream<bool> get onConnectionChange => _connectionController.stream;

  // ==================== INIT ====================

  /// Initialize the service - cache user profile ID.
  /// Auto-creates a profile row if the user doesn't have one yet.
  static Future<void> init() async {
    if (_currentProfileId != null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Try to fetch existing profile
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (data != null && data['id'] != null) {
        // Profile exists
        _currentProfileId = data['id'];
        _currentUsername = data['username'];
        _currentDisplayName = data['display_name'];
        return;
      }
    } catch (_) {}

    // Profile doesn't exist — create one
    try {
      final username =
          user.email?.split('@').first ?? 'user_${user.id.substring(0, 6)}';
      final displayName = user.email?.split('@').first ?? 'User';

      final created = await supabase
          .from('profiles')
          .insert({
            'auth_id': user.id,
            'username': username,
            'display_name': displayName,
            'email': user.email ?? '',
          })
          .select()
          .single();

      _currentProfileId = created['id'];
      _currentUsername = created['username'];
      _currentDisplayName = created['display_name'];
      print('✅ Profile auto-created: $_currentProfileId');
    } catch (e) {
      print('❌ Failed to create profile: $e');
      // Last resort: try fetching again (maybe concurrent creation)
      try {
        final data = await supabase
            .from('profiles')
            .select()
            .eq('auth_id', user.id)
            .single();
        _currentProfileId = data['id'];
        _currentUsername = data['username'];
        _currentDisplayName = data['display_name'];
      } catch (_) {}
    }
  }

  // ==================== SOCKET.IO ====================

  /// Connect to Socket.IO server (call when backend is running)
  static Future<void> connectSocket() async {
    if (_socket != null && _isConnected) {
      print('🔌 Socket already connected');
      return;
    }
    await init();

    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) {
      print('❌ No auth token available for Socket.IO connection');
      return;
    }

    print('🔌 Attempting to connect to Socket.IO server at $_baseUrl');

    _socket = IO.io(
      _baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ Socket.IO connected successfully');
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('❌ Socket.IO disconnected');
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      print('❌ Socket.IO connection error: $error');
      _connectionController.add(false);
    });

    _socket!.on('message:new', (data) {
      print('📨 Received new message via Socket.IO: $data');
      _socketMessageController.add(
        ChatMessage.fromSocketEvent(Map<String, dynamic>.from(data)),
      );
    });

    _socket!.on('typing:user', (data) {
      print('⌨️ Received typing indicator: $data');
      _typingController.add(Map<String, dynamic>.from(data));
    });

    _socket!.on('error', (data) {
      print('❌ Socket.IO error: $data');
    });

    _socket!.connect();
    print('🔌 Socket.IO connection initiated...');
  }

  static void joinGroupRoom(String groupId) =>
      _socket?.emit('join:group', groupId);
  static void leaveGroupRoom(String groupId) =>
      _socket?.emit('leave:group', groupId);
  static void startTyping(String groupId) =>
      _socket?.emit('typing:start', groupId);
  static void stopTyping(String groupId) =>
      _socket?.emit('typing:stop', groupId);
  static void markAsRead(String messageId) =>
      _socket?.emit('message:read', {'messageId': messageId});

  static void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  // ==================== SUPABASE DATA ====================

  /// Get all groups the current user belongs to, with last message
  static Future<List<GroupConversation>> getUserGroups() async {
    await init();
    if (_currentProfileId == null) return [];

    try {
      // Fetch group memberships with group details
      final memberData = await supabase
          .from('group_members')
          .select(
            'group_id, groups(id, name, description, avatar_url, invite_code)',
          )
          .eq('user_id', _currentProfileId!);

      final List<GroupConversation> conversations = [];

      for (final row in memberData) {
        final group = row['groups'];
        if (group == null) continue;
        final groupId = group['id'] as String;

        // Get member count
        final countData = await supabase
            .from('group_members')
            .select('id')
            .eq('group_id', groupId);

        // Get last message
        ChatMessage? lastMsg;
        try {
          final msgData = await supabase
              .from('chat_messages')
              .select('*, profiles(id, username, display_name, avatar_url)')
              .eq('group_id', groupId)
              .eq('is_deleted', false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (msgData != null) {
            lastMsg = ChatMessage.fromSupabaseRow(msgData);
          }
        } catch (_) {}

        conversations.add(
          GroupConversation(
            id: groupId,
            name: group['name'] ?? 'Unknown',
            description: group['description'],
            avatarUrl: group['avatar_url'],
            inviteCode: group['invite_code'] ?? '',
            memberCount: countData.length,
            lastMessage: lastMsg,
          ),
        );
      }

      // Sort by last message time (most recent first)
      conversations.sort((a, b) {
        final aTime = a.lastMessage?.createdAt ?? DateTime(2000);
        final bTime = b.lastMessage?.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      return conversations;
    } catch (e) {
      print('Error fetching groups: $e');
      return [];
    }
  }

  /// Fetch messages for a group (chronological order, oldest first)
  static Future<List<ChatMessage>> getGroupMessages(
    String groupId, {
    int limit = 50,
  }) async {
    try {
      final data = await supabase
          .from('chat_messages')
          .select('*, profiles(id, username, display_name, avatar_url)')
          .eq('group_id', groupId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(limit);

      return data
          .map<ChatMessage>((row) => ChatMessage.fromSupabaseRow(row))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message by inserting directly into Supabase.
  /// Returns the created ChatMessage or null on failure.
  /// NOTE: Requires RLS policy allowing authenticated inserts on chat_messages,
  /// or RLS disabled for development.
  static Future<ChatMessage?> sendMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? replyToId,
  }) async {
    await init();
    if (_currentProfileId == null) return null;

    print('📤 Sending message: "$content" to group $groupId');

    // Check if this is a game command - if so, send via Socket.IO
    if (_isGameCommand(content)) {
      print('🎮 Game command detected, routing via Socket.IO');
      return _sendGameCommandViaSocket(
        groupId,
        content,
        messageType,
        mediaUrl,
        replyToId,
      );
    }

    print('💬 Regular message, sending via Supabase');
    try {
      final row = await supabase
          .from('chat_messages')
          .insert({
            'group_id': groupId,
            'sender_id': _currentProfileId,
            'message_type': messageType,
            'content': content,
            'media_url': mediaUrl,
            'reply_to_id': replyToId,
          })
          .select('*, profiles(id, username, display_name, avatar_url)')
          .single();

      return ChatMessage.fromSupabaseRow(row);
    } catch (e) {
      print('Error sending message via Supabase: $e');

      // Fallback: try via Socket.IO if connected
      if (_isConnected && _socket != null) {
        _socket!.emit('message:send', {
          'groupId': groupId,
          'content': content,
          'messageType': messageType,
          'mediaUrl': mediaUrl,
          'replyToId': replyToId,
          'tempId': _uuid.v4(),
        });
      }
      return null;
    }
  }

  /// Check if a message contains a game command
  static bool _isGameCommand(String content) {
    final trimmedContent = content.trim().toLowerCase();
    final isGameCommand =
        trimmedContent.startsWith('/truth') ||
        trimmedContent.startsWith('/dare') ||
        trimmedContent.startsWith('/sike');

    print('🎮 Game command check: "$content" -> isGameCommand: $isGameCommand');
    return isGameCommand;
  }

  /// Send game command via Socket.IO to trigger game processing
  static Future<ChatMessage?> _sendGameCommandViaSocket(
    String groupId,
    String content,
    String messageType,
    String? mediaUrl,
    String? replyToId,
  ) async {
    print('🎮 Attempting to send game command via Socket.IO...');

    if (!_isConnected || _socket == null) {
      print(
        '❌ Socket not connected, cannot send game command. _isConnected: $_isConnected, _socket: $_socket',
      );
      return null;
    }

    print('✅ Socket is connected, sending game command: $content');

    // Create optimistic message
    final optimisticMessage = createOptimisticMessage(
      groupId: groupId,
      content: content,
      messageType: messageType,
      mediaUrl: mediaUrl,
      replyToId: replyToId,
    );

    // Send via Socket.IO to trigger game command processing
    _socket!.emit('message:send', {
      'groupId': groupId,
      'content': content,
      'messageType': messageType,
      'mediaUrl': mediaUrl,
      'replyToId': replyToId,
      'tempId': optimisticMessage.id,
    });

    print('🎮 Game command sent via Socket.IO: $content');
    return optimisticMessage;
  }

  /// Subscribe to new messages in a group via Supabase Realtime.
  /// Returns the RealtimeChannel so the caller can unsubscribe.
  ///
  /// IMPORTANT: Enable Realtime for the `chat_messages` table in Supabase Dashboard:
  /// Database → Replication → Enable `chat_messages`, OR run:
  /// ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  static RealtimeChannel subscribeToGroupMessages(
    String groupId,
    void Function(Map<String, dynamic> newRecord) onNewMessage,
  ) {
    final channel = supabase.channel('chat:$groupId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (PostgresChangePayload payload) {
            onNewMessage(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  /// Subscribe to new messages across ALL groups (for chat list page).
  static RealtimeChannel subscribeToAllMessages(
    void Function(Map<String, dynamic> newRecord) onNewMessage,
  ) {
    final channel = supabase.channel('chat:all');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (PostgresChangePayload payload) {
            onNewMessage(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  /// Get a user profile by ID (with caching)
  static final Map<String, Map<String, dynamic>> _profileCache = {};

  static Future<Map<String, dynamic>?> getProfile(String userId) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId];
    try {
      final data = await supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', userId)
          .single();
      _profileCache[userId] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Get members of a group
  static Future<List<Map<String, dynamic>>> getGroupMembers(
    String groupId,
  ) async {
    try {
      final data = await supabase
          .from('group_members')
          .select('profiles(id, username, display_name, avatar_url, email)')
          .eq('group_id', groupId);

      return List<Map<String, dynamic>>.from(
        data.map((row) => row['profiles'] as Map<String, dynamic>),
      );
    } catch (e) {
      print('Error fetching group members: $e');
      return [];
    }
  }

  /// Create an optimistic message (shown immediately in UI before DB confirms)
  static ChatMessage createOptimisticMessage({
    required String groupId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
    String? replyToId,
  }) {
    return ChatMessage(
      id: 'temp-${_uuid.v4()}',
      groupId: groupId,
      senderId: _currentProfileId ?? '',
      senderUsername: _currentUsername ?? '',
      senderDisplayName: _currentDisplayName ?? 'You',
      messageType: messageType,
      content: content,
      mediaUrl: mediaUrl,
      replyToId: replyToId,
      isOptimistic: true,
      createdAt: DateTime.now(),
    );
  }
}
