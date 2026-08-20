import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_time.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../models/challenge.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/challenge_service.dart';
import 'daily_challenge_screen.dart';

/// The challenge archive: every past daily challenge, still solvable.
///
/// The point of the screen is the decay — a challenge is worth less the older
/// it is — so every row leads with what it pays *now* and says what it was
/// worth on its day. Showing the original bounty alone would advertise a
/// number the server will not pay (ground rule 4).
class PastChallengesScreen extends StatefulWidget {
  const PastChallengesScreen({super.key});

  @override
  State<PastChallengesScreen> createState() => _PastChallengesScreenState();
}

class _PastChallengesScreenState extends State<PastChallengesScreen> {
  final _scroll = ScrollController();
  final List<TodayChallenge> _items = [];

  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ChallengeService.instance.archive();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ChallengeService.instance.archive(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore;
      });
    } on ApiException {
      // Silent: the rows already on screen are still good, and a snackbar for
      // a failed background page would interrupt reading them.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(TodayChallenge entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DailyChallengeScreen(challengeId: entry.challenge.id),
      ),
    );
    // Claiming in there changes this row's solved state and the solver count.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Past Challenges',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListSkeleton(
        count: 5,
        padding: const EdgeInsets.all(24),
        item: () => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _PastChallengeSkeleton(),
        ),
      );
    }

    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No past challenges yet',
        message:
            'Challenges move here the day after they run. Come back tomorrow '
            'and today\'s will be the first one.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(24),
            itemCount: _items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return const _DecayExplainer();
              if (index == _items.length + 1) {
                return _loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox(height: 24);
              }
              final entry = _items[index - 1];
              return PastChallengeTile(
                entry: entry,
                onTap: () => _open(entry),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Explains the decay once, at the top, instead of on every row.
class _DecayExplainer extends StatelessWidget {
  const _DecayExplainer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.trending_down_rounded,
                size: 20, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Old challenges are still solvable, but they pay less every '
                'day — down to a fifth of what they were worth, then no '
                'further. The points on each card are what you would earn now.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One archived challenge.
///
/// Split out and public so the layout can be exercised at 320px with hostile
/// data, without a server (test/mobile_layout_test.dart).
class PastChallengeTile extends StatelessWidget {
  const PastChallengeTile({super.key, required this.entry, this.onTap});

  final TodayChallenge entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = entry.challenge;
    final solved = entry.isSolved;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                ),
                if (solved) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.verified_rounded,
                      color: AppColors.success, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // Wrap, not Row: five chips do not fit across a 320px phone and
            // must be allowed to fall onto another line.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PointsBadge(
                    points: c.awardPoints, label: '+${c.awardPoints} pts now'),
                if (c.awardPoints != c.bonusPoints)
                  Text(
                    'was ${c.bonusPoints}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                _meta(Icons.calendar_today_rounded, _ageLabel(c.ageDays)),
                // Its own chip rather than appended to the age: combined they
                // are one unbreakable 13px-too-wide row at 320px, and the Wrap
                // can only break *between* children.
                //
                // The date matters because it is what a user matches against
                // their own Codeforces submission list — a solve dated before
                // this day will not pay.
                _meta(Icons.event_rounded, formatDay(c.challengeDate)),
                _meta(Icons.people_alt_rounded,
                    '${entry.solverCount} solved'),
                if (c.cfRating != null)
                  _meta(Icons.speed_rounded, 'Rated ${c.cfRating}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _ageLabel(int days) => switch (days) {
        0 => 'Today',
        1 => 'Yesterday',
        _ => '$days days ago',
      };

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _PastChallengeSkeleton extends StatelessWidget {
  const _PastChallengeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 16, width: 220),
          SizedBox(height: 12),
          SkeletonBox(height: 12, width: 140),
        ],
      ),
    );
  }
}
