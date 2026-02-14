import 'dart:ui';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_container.dart';
import 'individual_chat.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _searchController = TextEditingController();
  List<GroupConversation> _conversations = [];
  List<GroupConversation> _filteredConversations = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterChats);
    _loadGroups();
    _subscribeToNewMessages();

    // Ensure ChatService initialized and attempt Socket.IO connection
    ChatService.init().whenComplete(() {
      ChatService.connectSocket().catchError((_) {});
    });
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final groups = await ChatService.getUserGroups();
      if (mounted) {
        setState(() {
          _conversations = groups;
          _filteredConversations = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToNewMessages() {
    _realtimeChannel = ChatService.subscribeToAllMessages((newRecord) async {
      final groupId = newRecord['group_id'] as String?;
      if (groupId == null) return;

      // Fetch sender profile for the preview
      final senderId = newRecord['sender_id'] as String?;
      Map<String, dynamic>? senderProfile;
      if (senderId != null) {
        senderProfile = await ChatService.getProfile(senderId);
      }

      if (!mounted) return;
      setState(() {
        final idx = _conversations.indexWhere((c) => c.id == groupId);
        if (idx != -1) {
          _conversations[idx].lastMessage = ChatMessage.fromSupabaseRow(
            newRecord,
            senderProfile: senderProfile,
          );
          // Re-sort: most recent first
          _conversations.sort((a, b) {
            final aTime = a.lastMessage?.createdAt ?? DateTime(2000);
            final bTime = b.lastMessage?.createdAt ?? DateTime(2000);
            return bTime.compareTo(aTime);
          });
          _filterChats();
        }
      });
    });
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = List.from(_conversations);
      } else {
        _filteredConversations = _conversations
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  String get _baseUrl {
    final ip = dotenv.env['IP_ADDRESS'] ?? '10.0.2.2';
    return 'http://$ip:3000';
  }

  Future<String?> _getJwtToken() async {
    final session = supabase.auth.currentSession;
    return session?.accessToken;
  }

  Future<void> _showJoinGroupDialog() async {
    final codeController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF3D2A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Join a Group',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                letterSpacing: 2,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'Enter Code',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                counterStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF7C3AED),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: codeController.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, codeController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // show blocking loading dialog while joining
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          ),
        );
      }
      await _joinGroupWithCode(result.toUpperCase());
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _joinGroupWithCode(String code) async {
    try {
      final token = await _getJwtToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please log in again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      // Call backend endpoint to join group by invite code
      final response = await http.post(
        Uri.parse('$_baseUrl/group/0/join'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'invite_code': code}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final groupData = responseData['group'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Joined "${groupData['name']}"!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadGroups();
        }
      } else if (response.statusCode == 400) {
        final errorData = jsonDecode(response.body);
        final errorMsg =
            errorData['error'] ?? 'Invalid invite code or already a member';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      } else {
        throw Exception('Failed to join group: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining group: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF3D2A5C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Create Group',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'Enter group name',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF7C3AED),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'Enter group description',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF7C3AED),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameController,
            builder: (_, value, __) => ElevatedButton(
              onPressed: value.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      // show blocking loading dialog while creating
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          ),
        );
      }
      final groupData = await _createGroup(
        nameController.text.trim(),
        descController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Navigate to chat if creation was successful
        if (groupData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                groupId: groupData['id'],
                name: groupData['name'],
                avatar: groupData['initials'],
                memberCount: 1,
                inviteCode: groupData['code'] as String?,
              ),
            ),
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _createGroup(
    String name,
    String description,
  ) async {
    try {
      final token = await _getJwtToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please log in again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return null;
      }

      // Call backend endpoint to create group
      final response = await http.post(
        Uri.parse('$_baseUrl/group/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'description': description.isEmpty ? null : description,
          'avatar_url': null,
        }),
      );

      if (response.statusCode == 201) {
        final groupData = jsonDecode(response.body);
        final groupId = groupData['id'];
        final inviteCode = groupData['invite_code'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Group "$name" created!\nInvite Code: $inviteCode'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Calculate initials for avatar
        final parts = name.trim().split(' ');
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name.toUpperCase();

        _loadGroups();

        return {
          'id': groupId,
          'name': name,
          'initials': initials,
          'code': inviteCode,
        };
      } else {
        throw Exception(
          'Failed to create group: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating group: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${timestamp.month}/${timestamp.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.black.withOpacity(
                0.2,
              ), // Darker glass header
              elevation: 0,
              title: const Text(
                'Chats',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.group_add_outlined),
                  tooltip: 'Join Group',
                  onPressed: _showJoinGroupDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create Group',
                  onPressed: _showCreateGroupDialog,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: kToolbarHeight + MediaQuery.of(context).padding.top + 10,
            ), // Space for extended app bar
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: GlassContainer(
                opacity: 0.1,
                borderRadius: BorderRadius.circular(24),
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search groups...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    border: InputBorder.none, // Glass container handles border
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF7C3AED),
                      ),
                    )
                  : _conversations.isEmpty
                  ? _buildEmptyState()
                  : _filteredConversations.isEmpty &&
                        _searchController.text.isNotEmpty
                  ? _buildNoResults()
                  : RefreshIndicator(
                      onRefresh: _loadGroups,
                      color: const Color(0xFF7C3AED),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _filteredConversations.length,
                        itemBuilder: (context, index) {
                          return _buildGroupTile(_filteredConversations[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7C3AED),
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'No groups yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a group or join one with an invite code',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showCreateGroupDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(130, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GlassContainer(
                opacity: 0.1,
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(22),
                child: TextButton.icon(
                  onPressed: _showJoinGroupDialog,
                  icon: const Icon(
                    Icons.group_add,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Join',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(130, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No groups found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(GroupConversation group) {
    final lastMsg = group.lastMessage;
    final preview = lastMsg != null
        ? '${lastMsg.senderDisplayName.isNotEmpty ? "${lastMsg.senderDisplayName}: " : ""}${lastMsg.content}'
        : 'No messages yet — say hello!';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GlassContainer(
        opacity: 0.08, // Subtle glass
        blur: 10,
        borderRadius: BorderRadius.circular(20),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    groupId: group.id,
                    name: group.name,
                    avatar: group.initials,
                    memberCount: group.memberCount,
                    inviteCode: group.inviteCode.isNotEmpty
                        ? group.inviteCode
                        : null,
                  ),
                ),
              );
              // Refresh when coming back
              _loadGroups();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        group.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (group.unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C3AED),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${group.unreadCount}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Timestamp
                  if (lastMsg != null)
                    Text(
                      _formatTimestamp(lastMsg.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
