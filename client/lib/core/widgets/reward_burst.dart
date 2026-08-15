import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// A one-shot celebration for the two moments the app actually rewards you:
/// accepting an answer (the bounty transfers) and claiming the daily challenge.
///
/// Drawn with a [CustomPainter] rather than a confetti package — decisions.md
/// D25 keeps this app on SDK primitives only.
///
/// Lives in the [Overlay], which has two useful consequences: it cannot affect
/// any screen's layout, so it is structurally incapable of overflowing at 320px;
/// and it survives the `setState` that follows the API call that triggered it.
void showRewardBurst(
  BuildContext context, {
  required String message,
  String? detail,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _RewardBurst(
      message: message,
      detail: detail,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _RewardBurst extends StatefulWidget {
  const _RewardBurst({
    required this.message,
    required this.detail,
    required this.onDone,
  });

  final String message;
  final String? detail;
  final VoidCallback onDone;

  @override
  State<_RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<_RewardBurst>
    with SingleTickerProviderStateMixin {
  static const _particles = 14;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final List<_Particle> _seeds = List.generate(_particles, (i) {
    // Seeded from the index, not Random(), so the burst looks the same every
    // time and there is nothing non-deterministic in a widget tree.
    final angle = (i / _particles) * 2 * math.pi;
    final rng = math.sin(i * 12.9898) * 43758.5453;
    return _Particle(
      angle: angle + (rng % 1) * 0.3,
      distance: 90 + (rng.abs() % 60),
      color: switch (i % 3) {
        0 => AppColors.points,
        1 => AppColors.primary,
        _ => AppColors.success,
      },
      spin: (rng % 2) - 1,
    );
  });

  @override
  void initState() {
    super.initState();
    // Remove from a status listener, never a Timer — a pending Timer at the end
    // of a testWidgets body fails the test outright.
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Positioned.fill(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            // Card pops in, holds, then fades. The particles are done well
            // before the copy is, so the text stays readable.
            final appear = Curves.easeOutBack.transform(
                (t / 0.18).clamp(0.0, 1.0));
            final fade = t < 0.8 ? 1.0 : 1 - ((t - 0.8) / 0.2);
            final burst = AppMotion.standard.transform(
                (t / 0.55).clamp(0.0, 1.0));

            return Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _BurstPainter(seeds: _seeds, t: burst),
                  ),
                  Transform.scale(
                    scale: 0.6 + 0.4 * appear,
                    child: _card(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.points, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            if (widget.detail != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.detail!,
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.color,
    required this.spin,
  });

  final double angle;
  final double distance;
  final Color color;
  final double spin;
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter({required this.seeds, required this.t});

  final List<_Particle> seeds;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0) return;
    final centre = Offset(size.width / 2, size.height / 2);

    for (final p in seeds) {
      // Fade as the square of progress, so they thin out towards the end
      // rather than all vanishing at once.
      final opacity = (1 - t * t).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      final offset = centre +
          Offset(math.cos(p.angle), math.sin(p.angle)) * p.distance * t;

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(p.spin * t * math.pi * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -3, 10, 6),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.t != t;
}
