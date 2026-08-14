import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Centred spinner for a screen that is still loading its first data.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
}

/// Something failed. Always shows the API's own message plus a way to recover —
/// never a raw exception.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// No data yet — says what is missing and offers the action that fixes it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: AppColors.subtleFill, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style:
                    ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gold points badge. Bounties are the one place the UI leaves blue behind.
class PointsBadge extends StatelessWidget {
  const PointsBadge({super.key, required this.points, this.label});

  final int points;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.points.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            label ?? '$points',
            style: const TextStyle(
              color: Color(0xFF92660A),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Up/down arrows with the running score between them.
class VoteControl extends StatelessWidget {
  const VoteControl({
    super.key,
    required this.count,
    required this.myVote,
    required this.onVote,
    this.horizontal = false,
    this.enabled = true,
  });

  final int count;
  final int myVote;
  final ValueChanged<int> onVote;
  final bool horizontal;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final children = [
      _arrow(Icons.keyboard_arrow_up_rounded, 1),
      Padding(
        padding: EdgeInsets.symmetric(
            horizontal: horizontal ? 4 : 0, vertical: horizontal ? 0 : 2),
        child: Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: myVote == 0 ? AppColors.textSecondary : AppColors.primary,
          ),
        ),
      ),
      _arrow(Icons.keyboard_arrow_down_rounded, -1),
    ];

    return horizontal
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _arrow(IconData icon, int value) {
    final active = myVote == value;
    return InkWell(
      onTap: enabled ? () => onVote(value) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 26,
          color: !enabled
              ? AppColors.border
              : active
                  ? AppColors.primary
                  : AppColors.textMuted,
        ),
      ),
    );
  }
}
