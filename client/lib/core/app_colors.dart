import 'package:flutter/material.dart';

/// The QuestBoard palette. Single source of truth — see docs/design-system.md.
///
/// Prefer `Theme.of(context)` where the theme already carries the value; use
/// these constants for the cases it does not cover (borders, muted text, tags).
class AppColors {
  const AppColors._();

  /// Buttons, links, active nav, focus rings.
  static const primary = Color(0xFF0066FF);

  /// Pressed / darker primary.
  static const primaryDark = Color(0xFF0052CC);

  /// Every Scaffold background.
  static const background = Color(0xFFF8FAFC);

  /// Cards, app bars, inputs, sidebar.
  static const surface = Colors.white;

  /// Card and input outlines, dividers.
  static const border = Color(0xFFE2E8F0);

  /// Headings and body text.
  static const textPrimary = Color(0xFF1E293B);

  /// Captions and metadata.
  static const textSecondary = Color(0xFF64748B);

  /// Placeholders and disabled text.
  static const textMuted = Color(0xFF94A3B8);

  /// Search fields, chips, hover states.
  static const subtleFill = Color(0xFFF1F5F9);

  /// Tinted background for primary-coloured chips and icon circles.
  static const primaryTint = Color(0xFFE0F2FE);

  /// Success — accepted answers, solved quests.
  static const success = Color(0xFF22C55E);
  static const successTint = Color(0xFFDCFCE7);
  static const successDark = Color(0xFF166534);

  /// Destructive actions and errors.
  static const danger = Color(0xFFEF4444);
  static const dangerTint = Color(0xFFFFE4E6);

  /// Points and bounties — the one place we break from blue.
  static const points = Color(0xFFF59E0B);

  /// Daily streaks. Deliberately a hotter orange than [points] so a flame and
  /// a coin never read as the same thing.
  static const streak = Color(0xFFF97316);

  /// The tint behind the amber warning row in [ErrorState].
  static const warningDark = Color(0xFF92660A);

  /// Background for that same warning row — degraded-but-usable states, like
  /// a daily challenge served from cache because Codeforces was down.
  static const warningTint = Color(0xFFFEF3C7);
}
