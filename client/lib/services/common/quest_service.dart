import '../../models/quest.dart';
import '../api/api_client.dart';

class QuestService {
  QuestService._();

  static final QuestService instance = QuestService._();

  final _api = ApiClient.instance;

  /// Browsing is public, so the feed is fetched without a token when the user
  /// is signed out. Signed in, the token also brings back their own votes.
  Future<QuestPage> list({
    int page = 1,
    int limit = 20,
    String? tag,
    String sort = 'latest',
    String? search,
    bool authenticated = true,
  }) async {
    final json = await _api.get(
      '/questions',
      query: {
        'page': page,
        'limit': limit,
        'sort': sort,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (search != null && search.isNotEmpty) 'search': search,
      },
      auth: authenticated,
    );
    return QuestPage.fromJson(json as Map<String, dynamic>);
  }

  Future<Quest> get(String id, {bool authenticated = true}) async {
    final json = await _api.get('/questions/$id', auth: authenticated);
    return Quest.fromJson(json as Map<String, dynamic>);
  }

  Future<Quest> create({
    required String title,
    required String body,
    required List<String> tags,
    int bountyPoints = 0,
  }) async {
    final json = await _api.post('/questions', body: {
      'title': title,
      'body': body,
      'tags': tags,
      'bounty_points': bountyPoints,
    });
    return Quest.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _api.delete('/questions/$id');

  Future<Answer> answer(String questId, String body) async {
    final json = await _api.post('/questions/$questId/answers', body: {
      'body': body,
    });
    return Answer.fromJson(json as Map<String, dynamic>);
  }

  Future<Answer> accept(String answerId) async {
    final json = await _api.post('/answers/$answerId/accept');
    return Answer.fromJson(json as Map<String, dynamic>);
  }

  /// Returns the target's new `(voteCount, myVote)` after the toggle.
  Future<({int count, int mine})> voteQuest(String questId, int value) =>
      _vote('/questions/$questId/vote', value);

  Future<({int count, int mine})> voteAnswer(String answerId, int value) =>
      _vote('/answers/$answerId/vote', value);

  Future<({int count, int mine})> _vote(String path, int value) async {
    final json = await _api.post(path, body: {'value': value});
    final map = json as Map<String, dynamic>;
    return (count: map['vote_count'] as int, mine: map['my_vote'] as int);
  }
}
