import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../models/gamification.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/gamification_service.dart';
import '../profile/profile_screen.dart';
import 'leaderboard_podium.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.embedded = false});

  /// True when the dashboard shell already draws an app bar for this tab.
  /// Standalone pushes keep their own so the screen still has a title and a
  /// back button.
  final bool embedded;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Leaderboard? _board;
  bool _loading = true;
  String? _error;
  String _period = 'all_time';

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
      final board = await GamificationService.instance.leaderboard(period: _period);
      if (mounted) setState(() => (_board = board, _loading = false));
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: (!isWeb && !widget.embedded)
          ? AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: Text('Leaderboard',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (isWeb)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Leaderboard',
                        style: GoogleFonts.outfit(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all_time', label: Text('All time')),
                    ButtonSegment(value: 'weekly', label: Text('This week')),
                  ],
                  selected: {_period},
                  onSelectionChanged: (s) {
                    setState(() => _period = s.first);
                    _load();
                  },
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
    if (_loading) {
      return ListSkeleton(count: 7, item: LeaderboardRowSkeleton.new);
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final board = _board!;
    if (board.entries.isEmpty) {
      return EmptyState(
        icon: Icons.emoji_events_outlined,
        title: _period == 'weekly' ? 'Nothing this week yet' : 'No rankings yet',
        message: _period == 'weekly'
            ? 'Points earned in the last seven days show up here. Answer a '
                'quest to get on the board.'
            : 'Be the first to earn points by answering a quest.',
      );
    }

    final outsideTop = board.me != null &&
        !board.entries.any((e) => e.user.id == board.me!.user.id);

    // The podium needs a full set of three; below that it renders nothing and
    // everyone stays in the flat list, so the two must agree on where to start.
    final hasPodium = board.entries.length >= 3;
    final listed = hasPodium ? board.entries.skip(3) : board.entries;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        // Without this, a board shorter than the screen is not scrollable and
        // pull-to-refresh silently does nothing.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (hasPodium) ...[
            LeaderboardPodium(
              top3: board.entries.take(3).toList(),
              meId: board.me?.user.id,
              onTap: _openProfile,
            ),
            const SizedBox(height: 20),
          ],
          // "Score" means two different things depending on the toggle above,
          // and nothing on screen used to say which.
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _period == 'weekly'
                  ? 'Points earned in the last 7 days.'
                  : 'Total points earned, all time.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          for (final (i, entry) in listed.indexed)
            FadeSlideIn(
              index: i,
              child: _row(entry,
                  highlight: entry.user.id == board.me?.user.id),
            ),
          if (outsideTop) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Your position',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ]),
            ),
            _row(board.me!, highlight: true),
          ],
        ],
      ),
    );
  }

  void _openProfile(String userId) => Navigator.push(
        context,
        appRoute((_) => ProfileScreen(userId: userId)),
      );

  Widget _row(LeaderboardEntry entry, {bool highlight = false}) {
    return InkWell(
      onTap: () => _openProfile(entry.user.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: highlight ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            // Ranks 1–3 are on the podium above, so this column only ever
            // renders a plain number now.
            SizedBox(
              width: 36,
              child: Text(
                entry.rank == 0 ? '—' : '${entry.rank}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textMuted),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.subtleFill,
              child: Text(entry.user.initial,
                  style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.user.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            PointsBadge(points: entry.score, label: '${entry.score}'),
          ],
        ),
      ),
    );
  }
}
