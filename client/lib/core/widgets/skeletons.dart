import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// Skeleton placeholders that mirror the shape of the content still loading.
///
/// These replace [LoadingState] on screens whose layout is predictable, which is
/// most of them. A spinner says "wait"; a skeleton says "a list of quests is
/// arriving", and it is the difference between the app looking half-built and
/// looking finished during the seconds a demo actually spends on it.
///
/// ## Why the pulse stops
///
/// The usual way to write this is `controller.repeat(reverse: true)`, which
/// never completes and therefore makes any future `tester.pumpAndSettle()` time
/// out. Instead the pulse runs [_SkeletonPulseState._maxCycles] times and then
/// rests. Nothing loads for seven seconds and still succeeds — past that it is a
/// broken connection, not a load, and the error state is what should be on
/// screen anyway.
///
/// Worth knowing: the [CircularProgressIndicator] these replace *is* an uncapped
/// repeating animation, so this is strictly the safer of the two.

/// Drives one shared pulse for every skeleton beneath it.
///
/// One controller per screen, not one per box — a list of twenty skeleton rows
/// would otherwise spin up sixty tickers.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  /// Six cycles at 550ms each ≈ 6.6 seconds, then the pulse settles at a
  /// mid-tone and holds. See the file comment for why this is capped at all.
  static const _maxCycles = 6;

  int _cycles = 0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..addStatusListener(_onStatus);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    // Once we have settled, ignore the status change animateTo() itself emits —
    // reacting to it would restart the loop we just stopped.
    if (_cycles >= _maxCycles) return;

    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _cycles++;
      if (_cycles < _maxCycles) {
        _controller.forward();
      } else {
        _controller.animateTo(0.45, duration: AppMotion.base);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          _PulseScope(t: _controller.value, child: child!),
      child: widget.child,
    );
  }
}

class _PulseScope extends InheritedWidget {
  const _PulseScope({required this.t, required super.child});

  final double t;

  @override
  bool updateShouldNotify(_PulseScope oldWidget) => oldWidget.t != t;

  /// Falls back to a static mid-tone when there is no [SkeletonPulse] above —
  /// a lone [SkeletonBox] renders as a plain grey block rather than throwing.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PulseScope>()?.t ?? 0.45;
}

Color _pulseColor(BuildContext context) =>
    Color.lerp(AppColors.subtleFill, AppColors.border, _PulseScope.of(context))!;

/// A single grey bar standing in for a line of text.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _pulseColor(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Stands in for an avatar.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.radius = 12});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: _pulseColor(context),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Repeats [item] [count] times inside a single [SkeletonPulse].
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    required this.item,
    this.count = 4,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget Function() item;
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: SingleChildScrollView(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        child: Column(children: [for (var i = 0; i < count; i++) item()]),
      ),
    );
  }
}

/// Mirrors [QuestTile]: radius 20, 24 of padding, avatar + name + badge row,
/// a two-line title, tags, then metadata.
class QuestTileSkeleton extends StatelessWidget {
  const QuestTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonCircle(radius: 12),
              SizedBox(width: 8),
              SkeletonBox(width: 90, height: 10),
              Spacer(),
              SkeletonBox(width: 48, height: 18, radius: 20),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBox(height: 16),
          SizedBox(height: 8),
          SkeletonBox(width: 200, height: 16),
          SizedBox(height: 16),
          Row(
            children: [
              SkeletonBox(width: 52, height: 20, radius: 6),
              SizedBox(width: 6),
              SkeletonBox(width: 40, height: 20, radius: 6),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonBox(width: 34, height: 12),
              SizedBox(width: 16),
              SkeletonBox(width: 34, height: 12),
              SizedBox(width: 16),
              SkeletonBox(width: 60, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// One leaderboard row: rank, avatar, name, score.
class LeaderboardRowSkeleton extends StatelessWidget {
  const LeaderboardRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SkeletonBox(width: 22, height: 14),
          SizedBox(width: 12),
          SkeletonCircle(radius: 18),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 13)),
          SizedBox(width: 12),
          SkeletonBox(width: 54, height: 20, radius: 20),
        ],
      ),
    );
  }
}

/// One point-ledger row: icon, reason, timestamp, amount.
class LedgerRowSkeleton extends StatelessWidget {
  const LedgerRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SkeletonCircle(radius: 16),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120, height: 13),
                SizedBox(height: 6),
                SkeletonBox(width: 70, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(width: 40, height: 14),
        ],
      ),
    );
  }
}

/// The admin stat grid. Wraps rather than using a fixed column count so it
/// still fits at 320px.
class StatGridSkeleton extends StatelessWidget {
  const StatGridSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 150,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 60, height: 22),
                    SizedBox(height: 10),
                    SkeletonBox(width: 90, height: 11),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A quest detail page: title, byline, body paragraph, then answer blocks.
class QuestDetailSkeleton extends StatelessWidget {
  const QuestDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(height: 22),
            const SizedBox(height: 10),
            const SkeletonBox(width: 220, height: 22),
            const SizedBox(height: 20),
            const Row(
              children: [
                SkeletonCircle(radius: 14),
                SizedBox(width: 10),
                SkeletonBox(width: 110, height: 12),
              ],
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 4; i++) ...[
              SkeletonBox(width: i == 3 ? 180 : null, height: 13),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            const SkeletonBox(width: 120, height: 16),
            const SizedBox(height: 16),
            const QuestTileSkeleton(),
            const QuestTileSkeleton(),
          ],
        ),
      ),
    );
  }
}

/// A notification row: type icon, message, timestamp.
class NotificationRowSkeleton extends StatelessWidget {
  const NotificationRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SkeletonCircle(radius: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The profile page: identity card, badge grid, then ledger rows.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        );

    return SkeletonPulse(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            card(const Column(
              children: [
                SkeletonCircle(radius: 40),
                SizedBox(height: 16),
                SkeletonBox(width: 150, height: 18),
                SizedBox(height: 10),
                SkeletonBox(width: 100, height: 12),
              ],
            )),
            card(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: 80, height: 15),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 6; i++)
                      const SkeletonBox(width: 88, height: 30, radius: 20),
                  ],
                ),
              ],
            )),
            card(const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 110, height: 15),
                SizedBox(height: 8),
                LedgerRowSkeleton(),
                LedgerRowSkeleton(),
                LedgerRowSkeleton(),
                LedgerRowSkeleton(),
              ],
            )),
          ],
        ),
      ),
    );
  }
}
