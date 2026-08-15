import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../models/gamification.dart';
import '../../../models/quest.dart' show timeAgo;
import '../../../services/api/api_client.dart';
import '../../../services/common/gamification_service.dart';
import '../questions/question_detail.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await GamificationService.instance.notifications();
      if (mounted) setState(() => (_items = result.items, _loading = false));
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  Future<void> _markAllRead() async {
    final previous = _items;
    setState(() =>
        _items = [for (final n in _items) n.copyWith(isRead: true)]);
    try {
      await GamificationService.instance.markAllRead();
    } on ApiException catch (e) {
      if (mounted) setState(() => _items = previous);
      if (mounted) {
        showAppSnack(context, e.message, tone: SnackTone.error);
      }
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      setState(() => _items = [
            for (final n in _items)
              n.id == notification.id ? n.copyWith(isRead: true) : n
          ]);
      // Fire and forget: the row is already marked read locally, and a failed
      // mark is not worth interrupting the user for.
      GamificationService.instance.markRead(notification.id).ignore();
    }

    if (notification.opensQuest && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionDetail(questId: notification.referenceId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Notifications',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all as read',
                  style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListSkeleton(count: 5, item: NotificationRowSkeleton.new);
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nothing yet',
        message: 'Answers, accepted solutions and badges will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        // Without this, a list shorter than the screen is not scrollable and
        // pull-to-refresh silently does nothing.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _items.length,
        itemBuilder: (context, i) => _tile(_items[i]),
      ),
    );
  }

  ({IconData icon, Color color}) _visualFor(String type) => switch (type) {
        NotificationType.answerAccepted => (
            icon: Icons.check_circle_rounded,
            color: AppColors.success
          ),
        NotificationType.bountyAwarded => (
            icon: Icons.monetization_on_rounded,
            color: AppColors.points
          ),
        NotificationType.badgeEarned => (
            icon: Icons.emoji_events_rounded,
            color: AppColors.primary
          ),
        NotificationType.answerReceived => (
            icon: Icons.forum_rounded,
            color: AppColors.primary
          ),
        _ => (icon: Icons.notifications_rounded, color: AppColors.textMuted),
      };

  Widget _tile(AppNotification notification) {
    final visual = _visualFor(notification.type);

    return InkWell(
      onTap: () => _open(notification),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? AppColors.border : AppColors.primary,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, size: 18, color: visual.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      height: 1.4,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(timeAgo(notification.createdAt),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
