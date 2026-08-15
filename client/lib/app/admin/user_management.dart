import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/async_states.dart';
import '../../models/admin.dart';
import '../../services/api/api_client.dart';
import '../../services/common/admin_service.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final _searchController = TextEditingController();
  final List<AdminUser> _users = [];

  Timer? _debounce;
  bool _loading = true;
  String? _error;
  String _search = '';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// One request per pause in typing, not one per keystroke.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || value == _search) return;
      setState(() => _search = value);
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AdminService.instance.users(search: _search, limit: 50);
      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(page.items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  Future<void> _toggleSuspended(AdminUser user) async {
    final suspend = !user.isSuspended;

    if (suspend) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Suspend ${user.displayName}?'),
          content: const Text(
            'They will still be able to read QuestBoard, but cannot post, '
            'answer or vote until you lift it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Suspend',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busyId = user.id);
    try {
      final updated =
          await AdminService.instance.setSuspended(user.id, suspend);
      if (!mounted) return;
      setState(() {
        final i = _users.indexWhere((u) => u.id == user.id);
        if (i >= 0) _users[i] = _users[i].copyWith(isSuspended: updated.isSuspended);
        _busyId = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      // The server refuses self-suspension and suspending another admin; both
      // arrive here as a plain sentence worth showing verbatim.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Users',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    // No email: it lives in Supabase's auth.users and is
                    // deliberately never copied into our table.
                    hintText: 'Search by username or name',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_users.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_outlined,
        title: _search.isEmpty ? 'No users yet' : 'No match for "$_search"',
        message: _search.isEmpty
            ? 'Accounts appear here once people finish onboarding.'
            : 'Try part of a username instead.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _users.length,
        itemBuilder: (context, i) => AdminUserTile(
          user: _users[i],
          busy: _busyId == _users[i].id,
          onToggleSuspended: () => _toggleSuspended(_users[i]),
        ),
      ),
    );
  }
}

/// One row of the user list. Public and presentational so the layout test can
/// pump it with hostile data — long names, six-figure balances — at 320px.
class AdminUserTile extends StatelessWidget {
  const AdminUserTile({
    super.key,
    required this.user,
    required this.busy,
    required this.onToggleSuspended,
  });

  final AdminUser user;
  final bool busy;
  final VoidCallback onToggleSuspended;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: user.isSuspended ? AppColors.danger : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.subtleFill,
                child: Text(user.initial,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 12),
              // A long display name ellipsizes rather than pushing the badges
              // off the edge of a phone.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text('@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PointsBadge(points: user.points),
            ],
          ),
          const SizedBox(height: 12),
          // Wrap, not Row: badges plus a button do not fit one line at 320px.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (user.isAdmin) _chip('Admin', AppColors.primary, AppColors.primaryTint),
              if (user.isSuspended)
                _chip('Suspended', AppColors.danger, AppColors.dangerTint),
              TextButton.icon(
                onPressed: busy ? null : onToggleSuspended,
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        user.isSuspended
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                        size: 16),
                label: Text(user.isSuspended ? 'Lift suspension' : 'Suspend'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      user.isSuspended ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
