import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import '../../widgets/glass_container.dart';
import 'timeline_page.dart';
import '../time_capsule/time_capsule_list_page.dart';
import '../vault/vault_list_page.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String name;
  final String avatar;
  final int memberCount;
  final String? inviteCode;

  const ChatScreen({
    Key? key,
    required this.groupId,
    required this.name,
    required this.avatar,
    this.memberCount = 0,
    this.inviteCode,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const String _geminiBotId = '00000000-0000-0000-0000-000000000001';

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _realtimeChannel;
  StreamSubscription? _typingSub;

  final Map<String, String> _typingUsers = {};
  Timer? _typingDebounce;
  bool _isTyping = false;

  final Map<String, Map<String, dynamic>> _profileCache = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await ChatService.init();

    if (ChatService.currentProfileId != null) {
      _profileCache[ChatService.currentProfileId!] = {
        'id': ChatService.currentProfileId,
        'username': '',
        'display_name': 'You',
        'avatar_url': null,
      };
    }

    await _loadMessages();
    _subscribeToNewMessages();

    _typingSub = ChatService.onTyping.listen((data) {
      if (!mounted) return;
      final userId = data['userId'] as String?;
      final username = data['username'] as String?;
      final isTyping = data['isTyping'] as bool? ?? false;

      if (userId == null || userId == ChatService.currentProfileId) return;

      setState(() {
        if (isTyping) {
          _typingUsers[userId] = username ?? 'Someone';
        } else {
          _typingUsers.remove(userId);
        }
      });
    });

    ChatService.joinGroupRoom(widget.groupId);
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final msgs = await ChatService.getGroupMessages(
        widget.groupId,
        limit: 100,
      );

      for (final m in msgs) {
        if (m.senderId.isNotEmpty) {
          _profileCache[m.senderId] = {
            'id': m.senderId,
            'username': m.senderUsername,
            'display_name': m.senderDisplayName,
            'avatar_url': m.senderAvatarUrl,
          };
        }
      }

      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToNewMessages() {
    _realtimeChannel = ChatService.subscribeToGroupMessages(widget.groupId, (
      newRecord,
    ) async {
      final msgId = newRecord['id'] as String?;
      if (msgId == null) return;

      if (_messages.any((m) => m.id == msgId)) return;

      final senderId = newRecord['sender_id'] as String?;
      Map<String, dynamic>? senderProfile;
      if (senderId != null) {
        senderProfile = _profileCache[senderId];
        if (senderProfile == null) {
          senderProfile = await ChatService.getProfile(senderId);
          if (senderProfile != null) _profileCache[senderId] = senderProfile;
        }
      }

      if (!mounted) return;

      final realMessage = ChatMessage.fromSupabaseRow(
        newRecord,
        senderProfile: senderProfile,
      );

      setState(() {
        _messages.removeWhere(
          (m) =>
              m.isOptimistic &&
              m.senderId == realMessage.senderId &&
              m.content == realMessage.content,
        );
        _messages.add(realMessage);
      });

      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    _inputController.clear();

    final optimistic = ChatService.createOptimisticMessage(
      groupId: widget.groupId,
      content: text,
    );

    setState(() {
      _messages.add(optimistic);
      _isSending = true;
    });
    _scrollToBottom();

    if (_isTyping) {
      ChatService.stopTyping(widget.groupId);
      _isTyping = false;
    }

    final sent = await ChatService.sendMessage(
      groupId: widget.groupId,
      content: text,
    );

    if (mounted) {
      setState(() {
        if (sent != null) {
          final idx = _messages.indexWhere((m) => m.id == optimistic.id);
          if (idx != -1) {
            _messages[idx] = sent;
          }
        }
        _isSending = false;
      });
    }
  }

  void _onTextChanged(String value) {
    if (value.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ChatService.startTyping(widget.groupId);
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        ChatService.stopTyping(widget.groupId);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  bool _isMyMessage(ChatMessage msg) {
    return msg.senderId == ChatService.currentProfileId;
  }

  bool _isBotMessage(ChatMessage msg) {
    return msg.senderId == _geminiBotId;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    _typingDebounce?.cancel();
    _typingSub?.cancel();
    _realtimeChannel?.unsubscribe();
    ChatService.leaveGroupRoom(widget.groupId);
    if (_isTyping) ChatService.stopTyping(widget.groupId);
    super.dispose();
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
              backgroundColor: Colors.black.withOpacity(0.2), // Glass App Bar
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.avatar,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.memberCount} members',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  tooltip: 'Timeline',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TimelinePage()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.hourglass_bottom_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Time Capsules',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TimeCapsuleListPage(
                          groupId: widget.groupId,
                          groupName: widget.name,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.lock_outline, color: Colors.white),
                  tooltip: 'Vaults',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VaultListPage(
                          groupId: widget.groupId,
                          groupName: widget.name,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () => _showGroupInfo(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background - assuming app defines one, else plain dark
          // Messages
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C3AED),
                          ),
                        )
                      : _messages.isEmpty
                      ? _buildEmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            kToolbarHeight +
                                MediaQuery.of(context).padding.top +
                                16,
                            16,
                            80,
                          ), // Extra padding for input bar
                          itemCount:
                              _messages.length +
                              (_typingUsers.isNotEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length &&
                                _typingUsers.isNotEmpty) {
                              return _buildTypingIndicator();
                            }

                            final msg = _messages[index];
                            final isMe = _isMyMessage(msg);
                            final isBot = _isBotMessage(msg);
                            final showSender =
                                !isMe &&
                                (index == 0 ||
                                    _messages[index - 1].senderId !=
                                        msg.senderId);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (showSender)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        bottom: 4,
                                      ),
                                      child: isBot
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.auto_awesome,
                                                  size: 14,
                                                  color: Color(0xFF06B6D4),
                                                ),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  'Gemini AI',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF06B6D4),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              msg.senderDisplayName.isNotEmpty
                                                  ? msg.senderDisplayName
                                                  : msg.senderUsername,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _getSenderColor(
                                                  msg.senderId,
                                                ),
                                              ),
                                            ),
                                    ),
                                  _buildMessageBubble(msg, isMe, isBot: isBot),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Input Bar (Glass)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassContainer(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              opacity: 0.15,
              blur: 20,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocus,
                          onChanged: _onTextChanged,
                          onSubmitted: (_) => _sendMessage(),
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isSending
                              ? Colors.grey
                              : const Color(0xFF7C3AED),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isSending
                                          ? Colors.grey
                                          : const Color(0xFF7C3AED))
                                      .withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to say something!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, {bool isBot = false}) {
    if (isMe) {
      // My messages: Solid gradient color (no glass, stands out)
      return Align(
        alignment: Alignment.centerRight,
        child: Opacity(
          opacity: msg.isOptimistic ? 0.6 : 1.0,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: _buildMessageContent(msg, isMe),
          ),
        ),
      );
    } else if (isBot) {
      // Bot messages: Special sparkly gradient
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _buildMessageContent(msg, isMe),
        ),
      );
    } else {
      // Received messages: Glassmorphism!
      return Align(
        alignment: Alignment.centerLeft,
        child: GlassContainer(
          opacity: 0.1,
          blur: 10,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: _buildMessageContent(msg, isMe),
          ),
        ),
      );
    }
  }

  Widget _buildMessageContent(ChatMessage msg, bool isMe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          msg.content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatMsgTime(msg.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            if (msg.isEdited) ...[
              const SizedBox(width: 4),
              Text(
                'edited',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (isMe && msg.isOptimistic) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.access_time,
                size: 10,
                color: Colors.white.withOpacity(0.6),
              ),
            ],
            if (isMe && !msg.isOptimistic) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.done_all,
                size: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    final names = _typingUsers.values.toList();
    final text = names.length == 1
        ? '${names[0]} is typing...'
        : '${names.join(", ")} are typing...';

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: Row(
        children: [
          _buildTypingDots(),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1.0),
            duration: Duration(milliseconds: 600 + i * 200),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Transparent for glass effect
      isScrollControlled: true,
      builder: (ctx) => GlassContainer(
        opacity: 0.2,
        blur: 20,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.memberCount} members',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Messages: ${_messages.length}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            if (widget.inviteCode != null && widget.inviteCode!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Invite Code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.inviteCode!));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text('Invite code "${widget.inviteCode}" copied!'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.inviteCode!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.copy,
                        size: 20,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to copy and share with others',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _getSenderColor(String senderId) {
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
    ];
    return colors[senderId.hashCode.abs() % colors.length];
  }

  String _formatMsgTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
