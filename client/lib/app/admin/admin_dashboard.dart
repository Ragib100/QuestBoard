import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/async_states.dart';
import '../../models/admin.dart';
import '../../services/api/api_client.dart';
import '../../services/common/admin_service.dart';
import 'content_moderation.dart';
import 'user_management.dart';

/// Reachable only from the overflow menu / sidebar, and only when the signed-in
/// profile has `is_admin`. Every endpoint behind it 403s for anyone else, so the
/// gate is defence in depth rather than the actual protection.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminStats? _stats;
  bool _loading = true;
  String? _error;

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
      final stats = await AdminService.instance.stats();
      if (mounted) setState(() => (_stats = stats, _loading = false));
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Admin',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: AdminDashboardView(
                    stats: _stats!,
                    onOpen: (page) =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => page))
                            .then((_) => _load()),
                  ),
                ),
    );
  }
}

/// Split out from the loader so the layout can be pumped at 320px without a
/// server behind it — see test/mobile_layout_test.dart.
class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({
    super.key,
    required this.stats,
    required this.onOpen,
  });

  final AdminStats stats;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 900;

    return ListView(
      padding: EdgeInsets.all(isWeb ? 32 : 20),
      children: [
        Text('Platform at a glance',
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text(
          'Live counts, queried when this screen opened.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _statGrid(),
        const SizedBox(height: 32),
        Text('Moderation',
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        _moduleTile(
          icon: Icons.manage_accounts_rounded,
          title: 'Users',
          subtitle: stats.suspendedUsers == 0
              ? '${stats.totalUsers} accounts, none suspended'
              : '${stats.totalUsers} accounts, ${stats.suspendedUsers} suspended',
          onTap: () => onOpen(const UserManagement()),
        ),
        _moduleTile(
          icon: Icons.gavel_rounded,
          title: 'Quests',
          subtitle: 'Search and force-delete any quest',
          onTap: () => onOpen(const ContentModeration()),
        ),
      ],
    );
  }

  /// Two up on a phone, three on desktop. LayoutBuilder rather than a Row so
  /// the tiles get a real width instead of overflowing a narrow screen.
  Widget _statGrid() {
    final tiles = [
      _stat('${stats.totalUsers}', 'Users', Icons.people_rounded, AppColors.primary),
      _stat('${stats.totalQuests}', 'Quests', Icons.bolt_rounded, Colors.orange),
      _stat('${stats.openQuests}', 'Unsolved', Icons.help_outline_rounded,
          AppColors.warningDark),
      _stat('${stats.totalAnswers}', 'Answers', Icons.question_answer_rounded,
          AppColors.success),
      _stat('${stats.pointsInCirculation}', 'Points in circulation',
          Icons.stars_rounded, AppColors.points),
      _stat('${stats.suspendedUsers}', 'Suspended', Icons.block_rounded,
          AppColors.danger),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          // Six figures of circulating points must not widen the tile.
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _moduleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    // Material, not a decorated Container: a ListTile paints its ink splash on
    // the nearest Material, so a coloured box in between swallows the ripple.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.surface,
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ),
      ),
    );
  }
}
