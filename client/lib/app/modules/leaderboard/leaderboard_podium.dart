import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/async_states.dart';
import '../../../models/gamification.dart';

/// The top three, on a podium. Replaces the 🥇🥈🥉 emoji that used to sit in the
/// rank column of an otherwise flat list.
///
/// Public and layout-only — like `DailyChallengeView` and `AdminDashboardView`,
/// it takes its data as arguments so `test/mobile_layout_test.dart` can pump it
/// without a session or a network call.
class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    super.key,
    required this.top3,
    this.meId,
    this.onTap,
  });

  /// Ranks 1–3 in rank order. The caller must not also render these in the list
  /// below, or they appear twice.
  final List<LeaderboardEntry> top3;

  /// Ring the signed-in user's avatar, preserving the highlight affordance the
  /// flat rows already had.
  final String? meId;

  final ValueChanged<String>? onTap;

  static const _pedestal = {1: 66.0, 2: 50.0, 3: 38.0};
  static const _avatar = {1: 26.0, 2: 21.0, 3: 21.0};

  static Color _accent(int place) => switch (place) {
        1 => AppColors.points,
        2 => AppColors.textMuted,
        _ => AppColors.streak,
      };

  static Color _tint(int place) => switch (place) {
        1 => AppColors.warningTint,
        2 => AppColors.subtleFill,
        _ => AppColors.points.withValues(alpha: 0.12),
      };

  @override
  Widget build(BuildContext context) {
    // Never render an empty plinth — a gap on the podium implies a user who
    // does not exist. The caller falls back to flat rows instead.
    if (top3.length < 3) return const SizedBox.shrink();

    // Place comes from position in the list, not from `entry.rank`. The server
    // returns these in rank order, and a tie or a missing rank sends `rank`
    // back as 0 — which used to paint all three plinths bronze and the same
    // height.
    const order = [1, 0, 2]; // 2 · 1 · 3, tallest centred

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(
            child: _Plinth(
              entry: top3[i],
              place: i + 1,
              isMe: top3[i].user.id == meId,
              onTap: onTap,
            ),
          ),
      ],
    );
  }
}

class _Plinth extends StatelessWidget {
  const _Plinth({
    required this.entry,
    required this.place,
    required this.isMe,
    this.onTap,
  });

  final LeaderboardEntry entry;

  /// 1, 2 or 3 — position on the podium, not `entry.rank`.
  final int place;

  final bool isMe;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LeaderboardPodium._accent(place);
    final height = LeaderboardPodium._pedestal[place] ?? 38.0;
    final avatarRadius = LeaderboardPodium._avatar[place] ?? 21.0;

    // Third place rises first, then second, then first.
    final delay = switch (place) { 1 => 160, 2 => 80, _ => 0 };

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(entry.user.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMe ? AppColors.primary : accent,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: AppColors.subtleFill,
                child: Text(
                  entry.user.initial,
                  style: TextStyle(
                    fontSize: place == 1 ? 18 : 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            // A plinth is only about a third of the screen, and PointsBadge is a
            // fixed-width pill — a seven-figure score overflows it at 320px.
            // Scale it down rather than ellipsing, since half a number is worse
            // than a small one.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PointsBadge(points: entry.score, label: '${entry.score}'),
            ),
            const SizedBox(height: 6),
            // The pedestal is laid out at its full height from frame 0 and only
            // *drawn* growing, via a scaleY transform.
            //
            // It used to tween the Container's height directly. That made the
            // podium's real size arrive one frame later than its final layout,
            // so the widget test — which pumps a single frame — was measuring
            // the podium at zero pedestal height and passing, while the settled
            // podium overflowed its fixed-height box by 1px with a long name and
            // by 13px at 1.5x text scale. Transform does not participate in
            // layout, so what the test measures is now what the user sees.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(
                  milliseconds: AppMotion.slow.inMilliseconds + delay),
              curve: Interval(
                delay / (AppMotion.slow.inMilliseconds + delay),
                1,
                curve: AppMotion.standard,
              ),
              builder: (context, t, child) => Transform.scale(
                scaleY: t,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
              child: Container(
                height: height,
                width: double.infinity,
                alignment: Alignment.topCenter,
                decoration: BoxDecoration(
                  color: LeaderboardPodium._tint(place),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '$place',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
