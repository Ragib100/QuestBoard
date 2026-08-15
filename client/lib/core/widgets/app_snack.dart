import 'package:flutter/material.dart';

import '../app_colors.dart';

/// What a message means, which decides its colour.
enum SnackTone { neutral, success, error }

/// Transient feedback, colour-coded.
///
/// Every one of these used to be a bare
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)))`,
/// so "Quest posted" and "Your session has expired" arrived looking identical.
/// Base styling (floating, radius 12, Inter 14) comes from `snackBarTheme` in
/// main.dart; this only adds the tone.
void showAppSnack(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.neutral,
}) {
  final (background, icon) = switch (tone) {
    SnackTone.success => (AppColors.successDark, Icons.check_circle_outline),
    SnackTone.error => (AppColors.danger, Icons.error_outline_rounded),
    SnackTone.neutral => (AppColors.textPrimary, null),
  };

  ScaffoldMessenger.of(context)
    // Without this a burst of failures queues up and the last one lands
    // seconds after the user has moved on.
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
