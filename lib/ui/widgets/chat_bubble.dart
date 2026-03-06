/// Chattbubbla-widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/models.dart';
import '../../ui/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);

    if (message.isLoading) return _LoadingBubble();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.brandBlue
                      : theme.cardColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isUser
                        ? const Radius.circular(16)
                        : const Radius.circular(4),
                    bottomRight: isUser
                        ? const Radius.circular(4)
                        : const Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: message.errorMessage != null
                    ? _ErrorContent(message: message)
                    : MarkdownBody(
                        data: message.content,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme)
                            .copyWith(
                          p: theme.textTheme.bodyMedium?.copyWith(
                            color: isUser ? Colors.white : null,
                          ),
                          strong: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isUser ? Colors.white : null,
                          ),
                        ),
                      ),
              ),
              if (message.toolCalls.isNotEmpty) ...[
                const SizedBox(height: 4),
                _ToolCallBadges(toolCalls: message.toolCalls),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  height: 12, width: 180, color: Colors.white),
              const SizedBox(height: 6),
              Container(
                  height: 12, width: 120, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 16, color: AppTheme.errorColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolCallBadges extends StatelessWidget {
  const _ToolCallBadges({required this.toolCalls});

  final List<McpToolCall> toolCalls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: toolCalls
          .map((t) => Tooltip(
                message: '${t.durationMs ?? '?'}ms',
                child: Chip(
                  avatar: Icon(
                    t.succeeded
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 14,
                    color: t.succeeded
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                  label: Text(
                    t.toolName,
                    style: const TextStyle(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ))
          .toList(),
    );
  }
}
