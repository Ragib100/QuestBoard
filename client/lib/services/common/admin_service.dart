import '../../models/admin.dart';
import '../api/api_client.dart';

/// Every call here 403s for a non-admin, so the screens gate on
/// `Profile.isAdmin` first — the check on the server is what enforces it, the
/// one on the client is only there to avoid offering a button that cannot work.
class AdminService {
  AdminService._();

  static final AdminService instance = AdminService._();

  final _api = ApiClient.instance;

  Future<AdminStats> stats() async {
    final json = await _api.get('/admin/stats');
    return AdminStats.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminUserPage> users({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final json = await _api.get('/admin/users', query: {
      'page': page,
      'limit': limit,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AdminUserPage.fromJson(json as Map<String, dynamic>);
  }

  Future<AdminUser> setSuspended(String userId, bool suspended) async {
    final json = await _api.patch(
      '/admin/users/$userId/suspend',
      body: {'suspended': suspended},
    );
    return AdminUser.fromJson(json as Map<String, dynamic>);
  }

  /// Force-delete: unlike the author's own DELETE this works even once a quest
  /// has answers. The bounty is refunded server-side unless it was already won.
  Future<void> deleteQuest(String questId) => _api.delete('/admin/quests/$questId');
}
