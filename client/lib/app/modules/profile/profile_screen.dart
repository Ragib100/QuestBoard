import '../../../core/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../models/gamification.dart';
import '../../../models/profile.dart';
import '../../../models/quest.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/gamification_service.dart';
import '../../../services/common/user_service.dart';
import 'profile_edit.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId, this.embedded = false});

  /// Whose profile to show. Null means the signed-in user.
  final String? userId;

  /// True when the dashboard shell already draws an app bar for this tab.
  /// Standalone pushes keep their own so the screen still has a title and a
  /// back button.
  final bool embedded;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? _profile;
  List<PointEntry> _entries = const [];
  List<AchievementBadge> _badges = const [];
  bool _loading = true;
  String? _error;

  /// True when [_error] came from never reaching the server, rather
  /// than from the server saying no. Only the first kind is worth
  /// waiting through, and [ErrorState] draws it as a spinner.
  bool _offline = false;

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

      // Both depend on the profile id, but not on each other.
      final results = await Future.wait([
        UserService.instance.points(profile.id),
        GamificationService.instance.badgesFor(profile.id),
      ]);
      final points =
          results[0] as ({int balance, List<PointEntry> entries});
      final badges = results[1] as List<AchievementBadge>;

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _entries = points.entries;
        _badges = badges;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => (
              _error = e.message,
              _offline = e.isOffline,
              _loading = false
            ));
      }
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
    final isWeb = isWideLayout(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (!isWeb && !widget.embedded)
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: Text(_isMe ? 'My Profile' : 'Profile',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _loading
          ? const ProfileSkeleton()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load, offline: _offline)
              : _content(isWeb),
    );
  }

  Widget _content(bool isWeb) {
    final profile = _profile!;
    final left = _identityCard(profile);
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _badgeCard(),
        const SizedBox(height: 24),
        _ledgerCard(),
      ],
    );

    // Top-aligned: a short profile should start under the app bar, not float
    // down the middle of the viewport (see question_detail.dart).
    return Align(
      alignment: Alignment.topCenter,
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
          _streakStat(profile.streakDays),
          _stat('Badges',
              '${_badges.where((b) => b.isEarned).length} of ${_badges.length}'),
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
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  /// Streaks get a flame once they are actually running — a "0 days" flame
  /// would celebrate nothing.
  Widget _streakStat(int days) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Streak', style: TextStyle(color: AppColors.textSecondary)),
          Row(
            children: [
              if (days > 0) ...[
                const Icon(Icons.local_fire_department_rounded,
                    size: 16, color: AppColors.streak),
                const SizedBox(width: 4),
              ],
              Text(days == 1 ? '1 day' : '$days days',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeCard() {
    final earned = _badges.where((b) => b.isEarned).length;

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
          Row(
            children: [
              Text('Badges',
                  style: GoogleFonts.outfit(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$earned / ${_badges.length}',
                  style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          if (_badges.isEmpty)
            const Text('No badges defined yet.',
                style: TextStyle(color: AppColors.textMuted))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, badge) in _badges.indexed)
                  FadeSlideIn(index: i, child: _badgeChip(badge)),
              ],
            ),
        ],
      ),
    );
  }

  /// Locked badges stay visible but greyed out — seeing what is still
  /// achievable is the point of a badge list.
  ///
  /// There is deliberately no "just unlocked!" moment: the server exposes
  /// `awarded_at` and nothing else, so a first-time-unlock animation would be
  /// asserting something we cannot actually know. A badge earned in the last
  /// day gets a dot instead, which is derived from real data.
  Widget _badgeChip(AchievementBadge badge) {
    final earned = badge.isEarned;
    final fresh = earned &&
        badge.awardedAt!
            .isAfter(DateTime.now().subtract(const Duration(days: 1)));
    return Tooltip(
      message: earned
          ? '${badge.description}\nEarned ${timeAgo(badge.awardedAt!)}'
          : '${badge.description} (locked)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: earned ? AppColors.primaryTint : AppColors.subtleFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: earned ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              earned ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
              size: 16,
              color: earned ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              badge.label,
              style: TextStyle(
                fontWeight: earned ? FontWeight.bold : FontWeight.normal,
                color: earned ? AppColors.primary : AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            if (fresh) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.points,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
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
          else ...[
            _earnedVsSpent(),
            const SizedBox(height: 24),
            for (final entry in _entries) _ledgerRow(entry),
          ],
        ],
      ),
    );
  }

  /// Earned against spent, folded from the ledger rows already on screen.
  ///
  /// Deliberately *not* labelled "all time". `GET /users/{id}/points` caps the
  /// transaction list at 50 server-side and the client sends no limit, so these
  /// totals cover the entries we actually fetched and the caption says exactly
  /// that — inventing an all-time figure from a partial page is the kind of
  /// number decisions.md D12 exists to prevent.
  Widget _earnedVsSpent() {
    var earned = 0;
    var spent = 0;
    for (final entry in _entries) {
      if (entry.amount >= 0) {
        earned += entry.amount;
      } else {
        spent -= entry.amount;
      }
    }

    // Flex factors must be positive integers, so a side with nothing in it
    // still keeps a sliver rather than collapsing the bar.
    final total = earned + spent;
    final earnedFlex = total == 0 ? 1 : (earned * 100 ~/ total).clamp(1, 99);

    Widget figure(String label, int value, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 2),
            Text('$value',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            figure('Earned', earned, AppColors.successDark),
            figure('Spent', spent, AppColors.danger),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  flex: earnedFlex,
                  child: Container(color: AppColors.success),
                ),
                Expanded(
                  flex: 100 - earnedFlex,
                  child: Container(color: AppColors.danger),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Across your last ${_entries.length} '
          '${_entries.length == 1 ? 'entry' : 'entries'}.',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
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
