import '../core/app_time.dart';

/// Live counts behind the admin dashboard. Every field is a real query on the
/// server — nothing here is estimated, so a zero means zero.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.suspendedUsers,
    required this.totalQuests,
    required this.openQuests,
    required this.totalAnswers,
    required this.pointsInCirculation,
  });

  final int totalUsers;
  final int suspendedUsers;
  final int totalQuests;
  final int openQuests;
  final int totalAnswers;
  final int pointsInCirculation;

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        totalUsers: json['total_users'] as int? ?? 0,
        suspendedUsers: json['suspended_users'] as int? ?? 0,
        totalQuests: json['total_quests'] as int? ?? 0,
        openQuests: json['open_quests'] as int? ?? 0,
        totalAnswers: json['total_answers'] as int? ?? 0,
        pointsInCirculation: json['points_in_circulation'] as int? ?? 0,
      );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.points,
    required this.isAdmin,
    required this.isSuspended,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final int points;
  final bool isAdmin;
  final bool isSuspended;
  final DateTime createdAt;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  /// Email lives in Supabase's `auth.users` and is deliberately never copied
  /// into our table, so the username is the only handle moderation gets.
  String get initial =>
      displayName.isEmpty ? '?' : displayName[0].toUpperCase();

  AdminUser copyWith({bool? isSuspended}) => AdminUser(
        id: id,
        username: username,
        firstName: firstName,
        lastName: lastName,
        points: points,
        isAdmin: isAdmin,
        isSuspended: isSuspended ?? this.isSuspended,
        createdAt: createdAt,
      );

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        points: json['points'] as int? ?? 0,
        isAdmin: json['is_admin'] as bool? ?? false,
        isSuspended: json['is_suspended'] as bool? ?? false,
        createdAt:
            parseServerTime(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}

class AdminUserPage {
  const AdminUserPage({required this.items, required this.hasMore});

  final List<AdminUser> items;
  final bool hasMore;

  factory AdminUserPage.fromJson(Map<String, dynamic> json) => AdminUserPage(
        items: ((json['items'] as List?) ?? [])
            .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['has_more'] as bool? ?? false,
      );
}
