class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.imageUrl,
    required this.codeforcesHandle,
    required this.codeforcesVerified,
    required this.points,
    required this.streakDays,
    required this.isAdmin,
    required this.isSuspended,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String imageUrl;
  final String codeforcesHandle;
  final bool codeforcesVerified;
  final int points;
  final int streakDays;
  final bool isAdmin;

  /// Suspended accounts may read, but every write endpoint 403s.
  final bool isSuspended;
  final DateTime createdAt;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        phoneNumber: json['phone_number'] as String?,
        imageUrl: json['image_url'] as String? ?? '',
        codeforcesHandle: json['codeforces_handle'] as String? ?? '',
        codeforcesVerified: json['codeforces_verified'] as bool? ?? false,
        points: json['points'] as int? ?? 0,
        streakDays: json['streak_days'] as int? ?? 0,
        isAdmin: json['is_admin'] as bool? ?? false,
        isSuspended: json['is_suspended'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}

class PointEntry {
  const PointEntry({
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  final int amount;
  final String reason;
  final DateTime createdAt;

  /// `bounty_awarded` → "Bounty awarded".
  String get label {
    final words = reason.replaceAll('_', ' ');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }

  factory PointEntry.fromJson(Map<String, dynamic> json) => PointEntry(
        amount: json['amount'] as int? ?? 0,
        reason: json['reason'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );
}
