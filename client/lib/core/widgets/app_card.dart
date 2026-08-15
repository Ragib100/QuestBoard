import 'package:flutter/material.dart';

import '../app_colors.dart';

/// The standard QuestBoard card: white, 1px border, radius 16, no shadow.
///
/// This shape was hand-written about fifteen times across the app and the radius
/// had drifted to 16, 20 and 24 depending on the screen; two call sites had also
/// picked up a `boxShadow`, which docs/design-system.md forbids outright. Use
/// this instead of a bare `Container(decoration: BoxDecoration(...))`.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 16,
    this.onTap,
    this.background,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Defaults to [AppColors.surface]. Pass a tint for callout cards.
  final Color? background;

  /// Defaults to [AppColors.border]. Pass [AppColors.danger] for destructive
  /// states, matching the suspended-user tile in admin.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    return Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: shape,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              borderRadius: shape,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
