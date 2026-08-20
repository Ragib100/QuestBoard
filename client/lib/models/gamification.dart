/// Client models for badges, leaderboard entries and notifications.
library;

import '../core/app_time.dart';
import 'quest.dart' show UserSummary;

/// Named to avoid colliding with Flutter's Material `Badge` widget.
class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    this.awardedAt,
  });

  final String id;
  final String name;
  final String description;

  /// Null when this is a catalogue entry the user has not earned.
  final DateTime? awardedAt;

  bool get isEarned => awardedAt != null;

  /// `first_answer` → "First answer".
  String get label {
    final words = name.replaceAll('_', ' ');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }

  factory AchievementBadge.fromJson(Map<String, dynamic> json) =>
      AchievementBadge(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        awardedAt: json['awarded_at'] == null
            ? null
            : parseServerTime(json['awarded_at'] as String),
      );
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.score,
    required this.user,
  });

  final int rank;
  final int score;
  final UserSummary user;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int? ?? 0,
        score: json['score'] as int? ?? 0,
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      );
}

class Leaderboard {
  const Leaderboard({
    required this.period,
    required this.entries,
    this.me,
  });

  final String period;
  final List<LeaderboardEntry> entries;

  /// The signed-in user's standing, pinned even when outside the top 20.
  final LeaderboardEntry? me;

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        period: json['period'] as String? ?? 'all_time',
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        me: json['me'] == null
            ? null
            : LeaderboardEntry.fromJson(json['me'] as Map<String, dynamic>),
      );
}

/// Mirrors the `type` CHECK constraint on the notifications table.
class NotificationType {
  const NotificationType._();

  static const answerReceived = 'answer_received';
  static const answerAccepted = 'answer_accepted';
  static const bountyAwarded = 'bounty_awarded';
  static const voteReceived = 'vote_received';
  static const badgeEarned = 'badge_earned';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  /// The quest or badge this points at. Which table depends on [type].
  final String? referenceId;

  /// Notifications that reference a quest can be tapped through to it.
  bool get opensQuest =>
      referenceId != null && type != NotificationType.badgeEarned;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        referenceId: referenceId,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? '',
        message: json['message'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt:
            parseServerTime(json['created_at'] as String? ?? '') ??
                DateTime.now(),
        referenceId: json['reference_id'] as String?,
      );
}
