import '../../models/gamification.dart';
import '../api/api_client.dart';

class GamificationService {
  GamificationService._();

  static final GamificationService instance = GamificationService._();

  final _api = ApiClient.instance;

  /// Public — a signed-out visitor still sees the rankings, just without
  /// their own row pinned.
  Future<Leaderboard> leaderboard({
    String period = 'all_time',
    bool authenticated = true,
  }) async {
    final json = await _api.get(
      '/leaderboard',
      query: {'period': period},
      auth: authenticated,
    );
    return Leaderboard.fromJson(json as Map<String, dynamic>);
  }

  /// Every badge that exists, merged with the ones this user has earned, so
  /// the profile can show locked and unlocked side by side.
  Future<List<AchievementBadge>> badgesFor(String userId) async {
    final catalogue = await _api.get('/badges', auth: false) as List<dynamic>;
    final earned = await _api.get('/users/$userId/badges') as List<dynamic>;

    final earnedByName = {
      for (final b in earned)
        (b as Map<String, dynamic>)['name'] as String: AchievementBadge.fromJson(b)
    };

    return catalogue
        .map((b) {
          final badge = AchievementBadge.fromJson(b as Map<String, dynamic>);
          return earnedByName[badge.name] ?? badge;
        })
        .toList()
      // Earned first, newest award at the top.
      ..sort((a, b) {
        if (a.isEarned != b.isEarned) return a.isEarned ? -1 : 1;
        if (a.isEarned && b.isEarned) {
          return b.awardedAt!.compareTo(a.awardedAt!);
        }
        return a.name.compareTo(b.name);
      });
  }

  Future<({List<AppNotification> items, int unread})> notifications() async {
    final json = await _api.get('/notifications') as Map<String, dynamic>;
    return (
      items: (json['items'] as List<dynamic>? ?? [])
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList(),
      unread: json['unread_count'] as int? ?? 0,
    );
  }

  Future<int> unreadCount() async {
    final json =
        await _api.get('/notifications/unread-count') as Map<String, dynamic>;
    return json['unread_count'] as int? ?? 0;
  }

  Future<void> markRead(String id) => _api.patch('/notifications/$id/read');

  Future<void> markAllRead() => _api.patch('/notifications/read-all');
}
