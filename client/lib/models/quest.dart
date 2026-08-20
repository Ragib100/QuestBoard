/// Client-side models for the quest loop.
///
/// The API calls the entity a "question" (the table predates the QuestBoard
/// name); the product and every user-facing string call it a **quest**. The
/// wire keys stay `question*`, the Dart types read `Quest`.
library;

import 'code_submission.dart';

class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.imageUrl,
    required this.points,
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String imageUrl;
  final int points;

  /// Full name when we have one, otherwise the username.
  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  String get initial =>
      displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        points: json['points'] as int? ?? 0,
      );
}

class Answer {
  const Answer({
    required this.id,
    required this.questId,
    required this.body,
    required this.isAccepted,
    required this.createdAt,
    required this.author,
    required this.voteCount,
    required this.myVote,
    this.submission = CodeSubmission.empty,
  });

  final String id;
  final String questId;
  final String body;
  final bool isAccepted;
  final DateTime createdAt;
  final UserSummary author;
  final int voteCount;
  final int myVote;

  /// The code and file this answer carries, if any. Empty for prose answers,
  /// which are still the common case.
  final CodeSubmission submission;

  Answer copyWith({int? voteCount, int? myVote, bool? isAccepted}) => Answer(
        id: id,
        questId: questId,
        body: body,
        isAccepted: isAccepted ?? this.isAccepted,
        createdAt: createdAt,
        author: author,
        voteCount: voteCount ?? this.voteCount,
        myVote: myVote ?? this.myVote,
        submission: submission,
      );

  factory Answer.fromJson(Map<String, dynamic> json) => Answer(
        id: json['id'] as String,
        questId: json['question_id'] as String,
        body: json['body'] as String? ?? '',
        isAccepted: json['is_accepted'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        author:
            UserSummary.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
        voteCount: json['vote_count'] as int? ?? 0,
        myVote: json['my_vote'] as int? ?? 0,
        submission: CodeSubmission.fromJson(json),
      );
}

class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.bountyPoints,
    required this.isSolved,
    required this.viewCount,
    required this.createdAt,
    required this.author,
    required this.tags,
    required this.answerCount,
    required this.voteCount,
    this.body = '',
    this.myVote = 0,
    this.acceptedAnswerId,
    this.answers = const [],
  });

  final String id;
  final String title;
  final String body;
  final int bountyPoints;
  final bool isSolved;
  final int viewCount;
  final DateTime createdAt;
  final UserSummary author;
  final List<String> tags;
  final int answerCount;
  final int voteCount;
  final int myVote;
  final String? acceptedAnswerId;
  final List<Answer> answers;

  Quest copyWith({
    int? voteCount,
    int? myVote,
    bool? isSolved,
    String? acceptedAnswerId,
    List<Answer>? answers,
  }) =>
      Quest(
        id: id,
        title: title,
        body: body,
        bountyPoints: bountyPoints,
        isSolved: isSolved ?? this.isSolved,
        viewCount: viewCount,
        createdAt: createdAt,
        author: author,
        tags: tags,
        answerCount: answers?.length ?? answerCount,
        voteCount: voteCount ?? this.voteCount,
        myVote: myVote ?? this.myVote,
        acceptedAnswerId: acceptedAnswerId ?? this.acceptedAnswerId,
        answers: answers ?? this.answers,
      );

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        bountyPoints: json['bounty_points'] as int? ?? 0,
        isSolved: json['is_solved'] as bool? ?? false,
        viewCount: json['view_count'] as int? ?? 0,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        author:
            UserSummary.fromJson(json['author'] as Map<String, dynamic>? ?? {}),
        tags: (json['tags'] as List<dynamic>? ?? []).cast<String>(),
        answerCount: json['answer_count'] as int? ?? 0,
        voteCount: json['vote_count'] as int? ?? 0,
        myVote: json['my_vote'] as int? ?? 0,
        acceptedAnswerId: json['accepted_answer_id'] as String?,
        answers: (json['answers'] as List<dynamic>? ?? [])
            .map((a) => Answer.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class QuestPage {
  const QuestPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  final List<Quest> items;
  final int page;
  final int total;
  final bool hasMore;

  factory QuestPage.fromJson(Map<String, dynamic> json) => QuestPage(
        items: (json['items'] as List<dynamic>? ?? [])
            .map((q) => Quest.fromJson(q as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int? ?? 1,
        total: json['total'] as int? ?? 0,
        hasMore: json['has_more'] as bool? ?? false,
      );
}

/// Relative time for feed rows: "3h ago".
String timeAgo(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}
