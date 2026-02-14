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
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

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
      child: Row(
        children: [
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
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) {
                        if (widget.controller.text.trim().isNotEmpty &&
                            !widget.isLoading) {
                          widget.onSend();
                        }
                      },
                    ),
                  ),
                  if (widget.controller.text.isNotEmpty)
                    IconButton(
                      onPressed: widget.isLoading ? null : () => _send(),
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
    );
  }

  void _send() {
    if (widget.controller.text.trim().isNotEmpty && !widget.isLoading) {
      widget.onSend();
    }
  }
}
