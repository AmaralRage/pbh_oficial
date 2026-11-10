import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/chat_models.dart';

bool sameChatDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool connectedChatMessages(ChatMessage a, ChatMessage? b) =>
    b != null &&
    a.senderId == b.senderId &&
    sameChatDay(a.createdAt, b.createdAt) &&
    a.createdAt.difference(b.createdAt).abs() <= const Duration(minutes: 5);
String chatDateLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (sameChatDay(date, today)) return 'Hoje';
  if (sameChatDay(date, today.subtract(const Duration(days: 1))))
    return 'Ontem';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 18),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: context.pbhColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.pbhColors.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.pbhColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}
