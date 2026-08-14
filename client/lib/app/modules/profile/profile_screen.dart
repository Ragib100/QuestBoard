import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../models/profile.dart';
import '../../../models/quest.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/user_service.dart';
import 'profile_edit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});

  /// Whose profile to show. Null means the signed-in user.
  final String? userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<PointEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  bool get _isMe =>
      widget.userId == null ||
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = widget.userId == null
          ? await UserService.instance.me()
          : await UserService.instance.getProfile(widget.userId!);
      final points = await UserService.instance.points(profile.id);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _entries = points.entries;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEdit(profile: _profile!)),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: !isWeb
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: Text(_isMe ? 'My Profile' : 'Profile',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _content(isWeb),
    );
  }

  Widget _content(bool isWeb) {
    final profile = _profile!;
    final left = _identityCard(profile);
    final right = _ledgerCard();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: isWeb
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: right),
                    ],
                  )
                : Column(children: [left, const SizedBox(height: 24), right]),
          ),
        ),
      ),
    );
  }

  Widget _identityCard(Profile profile) {
    final avatar = UserService.instance.avatarUrl(profile.imageUrl);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.subtleFill,
            backgroundImage: avatar == null ? null : NetworkImage(avatar),
            child: avatar != null
                ? null
                : Text(
                    profile.displayName.isEmpty
                        ? '?'
                        : profile.displayName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted),
                  ),
          ),
          const SizedBox(height: 20),
          Text(profile.displayName,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          Text('@${profile.username}',
              style: const TextStyle(color: AppColors.textSecondary)),
          if (profile.codeforcesHandle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.code_rounded,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(profile.codeforcesHandle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                if (profile.codeforcesVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified,
                      size: 14, color: AppColors.success),
                ],
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          _stat('Points', '${profile.points}'),
          _stat('Streak', '${profile.streakDays} days'),
          _stat('Joined', timeAgo(profile.createdAt)),
          if (_isMe) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _edit,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              child: const Text('Edit Profile'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _ledgerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Point history',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Every change to your balance, newest first.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          if (_entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nothing yet. Post a quest or answer one to get moving.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            for (final entry in _entries) _ledgerRow(entry),
        ],
      ),
    );
  }

  Widget _ledgerRow(PointEntry entry) {
    final positive = entry.amount >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: positive ? AppColors.successTint : AppColors.dangerTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: positive ? AppColors.successDark : AppColors.danger,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(timeAgo(entry.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${entry.amount}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: positive ? AppColors.successDark : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
