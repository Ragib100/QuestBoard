/// What the hint button should say before anyone spends anything.
class HintStatus {
  const HintStatus({
    required this.available,
    required this.pointsCost,
    required this.hintsRemaining,
  });

  /// False when the server has no model key configured. The button says so
  /// instead of failing after the user taps it.
  final bool available;
  final int pointsCost;

  /// Hints left in the current hour.
  final int hintsRemaining;

  factory HintStatus.fromJson(Map<String, dynamic> json) => HintStatus(
        available: json['available'] as bool? ?? false,
        pointsCost: json['points_cost'] as int? ?? 0,
        hintsRemaining: json['hints_remaining'] as int? ?? 0,
      );
}

class AiHint {
  const AiHint({
    required this.hintText,
    required this.pointsCost,
    required this.pointsRemaining,
    required this.hintsRemaining,
  });

  final String hintText;
  final int pointsCost;
  final int pointsRemaining;
  final int hintsRemaining;

  factory AiHint.fromJson(Map<String, dynamic> json) => AiHint(
        hintText: json['hint_text'] as String? ?? '',
        pointsCost: json['points_cost'] as int? ?? 0,
        pointsRemaining: json['points_remaining'] as int? ?? 0,
        hintsRemaining: json['hints_remaining'] as int? ?? 0,
      );
}
