import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';

/// The decorative mark on the landing page and the two auth screens.
///
/// Replaces three `Image.network` calls that pointed at `.svg` files on
/// illustrations.popsy.co. Flutter's image codecs cannot decode SVG without
/// `flutter_svg`, so those `errorBuilder`s fired every single time on every
/// platform we ship — the "illustration" has only ever been a fallback icon.
///
/// Drawn locally rather than adding `flutter_svg` and keeping the remote URLs,
/// because the first screen of a live demo should not depend on a network
/// fetch. Purely geometric: no numbers, no invented usernames, nothing that
/// could read as fabricated content (decisions.md D12).
class BrandArt extends StatelessWidget {
  const BrandArt({super.key, this.size = 260});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BrandArtPainter(),
        child: Center(
          child: Icon(
            Icons.bolt_rounded,
            size: size * 0.34,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _BrandArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Three concentric rings, fading outwards.
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        centre,
        radius * (i / 3),
        Paint()
          ..color = AppColors.primaryTint.withValues(alpha: 0.30 + 0.18 * (3 - i)),
      );
    }

    // Six satellites on the outer ring, in the palette's accent colours.
    const satellites = 6;
    for (var i = 0; i < satellites; i++) {
      final angle = (i / satellites) * 2 * math.pi - math.pi / 2;
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * radius * 0.82;
      final color = switch (i % 3) {
        0 => AppColors.points,
        1 => AppColors.primary,
        _ => AppColors.success,
      };
      canvas.drawCircle(
        at,
        i.isEven ? 7 : 5,
        Paint()..color = color.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_BrandArtPainter oldDelegate) => false;
}
