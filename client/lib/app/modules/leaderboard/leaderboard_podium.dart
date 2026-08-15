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

  /// The whole podium is a fixed height, and the pedestals grow *inside* it.
  ///
  /// This is the one place in the app that animates something the layout
  /// measures, so it is boxed deliberately: the podium's contribution to its
  /// parent's constraints is constant at every frame, which keeps the 320px
  /// overflow test measuring the real geometry rather than a transient one.
  static const _height = 178.0;

  static const _pedestal = {1: 66.0, 2: 50.0, 3: 38.0};
  static const _avatar = {1: 26.0, 2: 21.0, 3: 21.0};

  static Color _accent(int rank) => switch (rank) {
        1 => AppColors.points,
        2 => AppColors.textMuted,
        _ => AppColors.streak,
      };

  static Color _tint(int rank) => switch (rank) {
        1 => AppColors.warningTint,
        2 => AppColors.subtleFill,
        _ => AppColors.points.withValues(alpha: 0.12),
      };

  @override
  Widget build(BuildContext context) {
    // Never render an empty plinth — a gap on the podium implies a user who
    // does not exist. The caller falls back to flat rows instead.
    if (top3.length < 3) return const SizedBox.shrink();

    final order = [top3[1], top3[0], top3[2]]; // 2 · 1 · 3, tallest centred

    return SizedBox(
      height: _height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in order)
            Expanded(child: _Plinth(
              entry: entry,
              isMe: entry.user.id == meId,
              onTap: onTap,
            )),
        ],
      ),
    );
  }
}

class _Plinth extends StatelessWidget {
  const _Plinth({required this.entry, required this.isMe, this.onTap});

  final LeaderboardEntry entry;
  final bool isMe;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final accent = LeaderboardPodium._accent(rank);
    final height = LeaderboardPodium._pedestal[rank] ?? 38.0;
    final avatarRadius = LeaderboardPodium._avatar[rank] ?? 21.0;

    // Third place rises first, then second, then first.
    final delay = switch (rank) { 1 => 160, 2 => 80, _ => 0 };

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(entry.user.id),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
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
                    fontSize: rank == 1 ? 18 : 15,
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: height),
              duration: Duration(
                  milliseconds: AppMotion.slow.inMilliseconds + delay),
              curve: Interval(
                delay / (AppMotion.slow.inMilliseconds + delay),
                1,
                curve: AppMotion.standard,
              ),
              builder: (context, h, _) => Container(
                height: h,
                width: double.infinity,
                alignment: Alignment.topCenter,
                decoration: BoxDecoration(
                  color: LeaderboardPodium._tint(rank),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12)),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: h < 20
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$rank',
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
