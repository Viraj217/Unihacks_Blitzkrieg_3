import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../services/vault_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/vault_message_widget.dart';
import '../../widgets/vault_input_widget.dart';

class VaultPage extends StatefulWidget {
  final String vaultId;
  final String? groupId;

  const VaultPage({super.key, required this.vaultId, this.groupId});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  Vault? _vault;
  List<VaultMessage> _messages = [];
  bool _isLoading = true;
  bool _isSendingMessage = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVault();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadVault() async {
    try {
      setState(() => _isLoading = true);

      final vault = await VaultService.getVaultById(widget.vaultId);
      setState(() {
        _vault = vault;
        _messages = vault.messages;
        _isLoading = false;
      });

      // Scroll to bottom when messages are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vault: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSendingMessage = true);

    // Create optimistic message
    final optimisticMessage = VaultMessage(
      id: const Uuid().v4(),
      vaultId: widget.vaultId,
      senderId: SupabaseService.currentUser!.id,
      senderUsername:
          SupabaseService.currentUser!.userMetadata?['username'] ?? 'Unknown',
      senderDisplayName:
          SupabaseService.currentUser!.userMetadata?['display_name'],
      content: content,
      messageType: 'text',
      isOptimistic: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimisticMessage);
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final sentMessage = await VaultService.addMessage(
        vaultId: widget.vaultId,
        content: content,
      );

      setState(() {
        final index = _messages.indexWhere((m) => m.id == optimisticMessage.id);
        if (index != -1) {
          _messages[index] = sentMessage;
        }
      });
    } catch (e) {
      // Remove optimistic message on error
      setState(() {
        _messages.removeWhere((m) => m.id == optimisticMessage.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSendingMessage = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteMessage(VaultMessage message) async {
    try {
      final success = await VaultService.deleteMessage(
        vaultId: widget.vaultId,
        messageId: message.id,
      );

      if (success) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editMessage(VaultMessage message) async {
    final controller = TextEditingController(text: message.content);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Edit your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null &&
        result.trim().isNotEmpty &&
        result.trim() != message.content) {
      try {
        final updatedMessage = await VaultService.updateMessage(
          vaultId: widget.vaultId,
          messageId: message.id,
          content: result.trim(),
        );

        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages[index] = updatedMessage;
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to edit message: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_vault?.name ?? 'Vault', style: const TextStyle(fontSize: 20)),
            if (_vault?.description != null)
              Text(
                _vault!.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
          ],
        ),
        actions: [
          if (_vault?.creator?.id == SupabaseService.currentUser?.id)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteVaultDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Vault'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 64,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to add a message to this vault',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isOwnMessage =
                                message.senderId ==
                                SupabaseService.currentUser?.id;

                            return VaultMessageWidget(
                              message: message,
                              isOwnMessage: isOwnMessage,
                              onEdit: isOwnMessage
                                  ? () => _editMessage(message)
                                  : null,
                              onDelete: isOwnMessage
                                  ? () => _deleteMessage(message)
                                  : null,
                            );
                          },
                        ),
                ),
                VaultInputWidget(
                  controller: _messageController,
                  isLoading: _isSendingMessage,
                  onSend: _sendMessage,
                ),
              ],
            ),
    );
  }

  Future<void> _showDeleteVaultDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vault'),
        content: const Text(
          'Are you sure you want to delete this vault? This action cannot be undone and all messages will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await VaultService.deleteVault(widget.vaultId);
        if (success && mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vault deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete vault: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
