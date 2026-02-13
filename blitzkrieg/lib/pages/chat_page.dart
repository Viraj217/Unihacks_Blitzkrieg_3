import 'package:flutter/material.dart';
import 'individual_chat.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late TextEditingController _searchController;
  late List<ChatConversation> conversations;
  late List<ChatConversation> filteredConversations;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    
    // Mock data for chats
    conversations = [
    ChatConversation(
      id: '1',
      name: 'Sarah Johnson',
      avatar: 'SJ',
      lastMessage: 'That sounds great! Can\'t wait to meet up 🎉',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 2,
      isOnline: true,
    ),
    ChatConversation(
      id: '2',
      name: 'Alex Chen',
      avatar: 'AC',
      lastMessage: 'Did you see the latest posts?',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 0,
      isOnline: true,
    ),
    ChatConversation(
      id: '3',
      name: 'Emma Davis',
      avatar: 'ED',
      lastMessage: 'Thanks for the recommendation!',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 1,
      isOnline: false,
    ),
    ChatConversation(
      id: '4',
      name: 'Mike Wilson',
      avatar: 'MW',
      lastMessage: 'Let\'s catch up this weekend',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      isOnline: false,
    ),
    ChatConversation(
      id: '5',
      name: 'Jessica Brown',
      avatar: 'JB',
      lastMessage: 'See you at the event!',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
      isOnline: true,
    ),
  ];
    
    filteredConversations = conversations;
    _searchController.addListener(_filterChats);
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        filteredConversations = conversations;
      } else {
        // Show only matching chats
        filteredConversations = conversations
            .where((chat) => chat.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _createNewChat() {
    // Generate a new chat ID
    final newId = (conversations.length + 1).toString();
    final userNameController = TextEditingController();
    
    // Show dialog to select or create chat with a new user
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: TextField(
          controller: userNameController,
          decoration: const InputDecoration(
            hintText: 'Enter user name...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final userName = userNameController.text.trim();
              if (userName.isNotEmpty) {
                setState(() {
                  // Create new chat with the entered user
                  final newChat = ChatConversation(
                    id: newId,
                    name: userName,
                    avatar: _getInitials(userName),
                    lastMessage: 'Say hello!',
                    timestamp: DateTime.now(),
                    unreadCount: 0,
                    isOnline: true,
                  );
                  conversations.insert(0, newChat);
                  filteredConversations = conversations;
                  _searchController.clear();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.month}/${timestamp.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            onPressed: _createNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  _filterChats();
                },
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          // Conversations List
          Expanded(
            child: filteredConversations.isEmpty && _searchController.text.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No groups found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = filteredConversations[index];
                      return _buildChatTile(conversation);
                    },
                  ),
          ),
        ],
      ),
      // Floating Action Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7C3AED), // Purple
        onPressed: () {},
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildChatTile(ChatConversation conversation) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                name: conversation.name,
                avatar: conversation.avatar,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Avatar with online indicator
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF7C3AED), // Purple primary
                          const Color(0xFFEC4899), // Pink secondary
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        conversation.avatar,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  if (conversation.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981), // Green for online
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Chat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Timestamp and unread badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(conversation.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (conversation.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED), // Purple
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        conversation.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatConversation {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;

  ChatConversation({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
  });
}
