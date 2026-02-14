import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class VaultInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const VaultInputWidget({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  State<VaultInputWidget> createState() => _VaultInputWidgetState();
}

class _VaultInputWidgetState extends State<VaultInputWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        children: [
          if (_isExpanded) _buildExpandedInput(),
          Row(
            children: [
              IconButton(
                onPressed: _toggleExpanded,
                icon: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _showAttachmentOptions,
                        icon: Icon(
                          Icons.attach_file,
                          color: Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 12,
                            ),
                          ),
                          maxLines: _isExpanded ? 5 : 1,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      if (widget.controller.text.isNotEmpty)
                        IconButton(
                          onPressed: widget.isLoading ? null : _sendMessage,
                          icon: widget.isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryPurple,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  color: AppTheme.primaryPurple,
                                  size: 20,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedInput() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentButton(
                icon: Icons.image,
                label: 'Photo',
                onPressed: () => _handleAttachment('image'),
              ),
              _buildAttachmentButton(
                icon: Icons.mic,
                label: 'Voice',
                onPressed: () => _handleAttachment('voice'),
              ),
              _buildAttachmentButton(
                icon: Icons.videocam,
                label: 'Video',
                onPressed: () => _handleAttachment('video'),
              ),
              _buildAttachmentButton(
                icon: Icons.insert_drive_file,
                label: 'File',
                onPressed: () => _handleAttachment('file'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.7), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  void _sendMessage() {
    if (widget.controller.text.trim().isNotEmpty && !widget.isLoading) {
      widget.onSend();
    }
  }

  void _showAttachmentOptions() {
    _toggleExpanded();
  }

  void _handleAttachment(String type) {
    // TODO: Implement attachment handling
    // This would typically open file picker, camera, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type attachment coming soon!'),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );
    setState(() {
      _isExpanded = false;
    });
  }
}
