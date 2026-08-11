import 'package:flutter/material.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/app_strings.dart';

/// Bottom input bar for the chat room (WhatsApp-style).
class ChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback onAttachment;

  const ChatInputBar({
    super.key,
    required this.onSend,
    required this.onAttachment,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: AppColors.darkAppBar,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Input field with attachment button inside
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.darkInput,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    // Attachment button
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: widget.onAttachment,
                    ),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: AppStrings.typeMessage,
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            GestureDetector(
              onTap: _hasText ? _handleSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _hasText ? AppColors.accent : AppColors.darkInput,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _hasText ? Colors.white : AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
