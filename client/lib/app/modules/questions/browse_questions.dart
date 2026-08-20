import '../../../core/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/skeletons.dart';
import '../../../core/widgets/search_field.dart';
import '../../../models/quest.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/quest_service.dart';
import 'ask_question.dart';
import 'question_detail.dart';

const _tags = [
  'dsa',
  'math',
  'physics',
  'chemistry',
  'calculus',
  'algorithms',
  'data-structures',
  'probability',
];

class BrowseQuestions extends StatefulWidget {
  const BrowseQuestions({super.key, this.embedded = false, this.search = ''});

  /// True when the dashboard shell already draws an app bar for this tab.
  /// Standalone pushes keep their own so the screen still has a title and a
  /// back button.
  final bool embedded;

  /// A term handed down from the shell's search box. The phone has no such
  /// box — it gets the field below instead — so this is usually empty there.
  final String search;

  @override
  State<BrowseQuestions> createState() => _BrowseQuestionsState();
}

class _BrowseQuestionsState extends State<BrowseQuestions> {
  final _scroll = ScrollController();
  final List<Quest> _quests = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String _sort = 'latest';
  String? _tag;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _search = widget.search.trim();
    _load();
  }

  /// The shell keeps this tab alive in an IndexedStack, so a new term arrives
  /// as a rebuild rather than a fresh screen.
  @override
  void didUpdateWidget(BrowseQuestions old) {
    super.didUpdateWidget(old);
    if (widget.search.trim() != old.search.trim()) _onSearch(widget.search);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String term) {
    if (term.trim() == _search) return;
    setState(() => _search = term.trim());
    _load();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await QuestService.instance
          .list(sort: _sort, tag: _tag, search: _search);
      if (!mounted) return;
      setState(() {
        _quests
          ..clear()
          ..addAll(page.items);
        _page = 1;
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
      final page = await QuestService.instance
          .list(page: _page + 1, sort: _sort, tag: _tag, search: _search);
      if (!mounted) return;
      setState(() {
        _quests.addAll(page.items);
        _page += 1;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } on ApiException {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _openAsk() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AskQuestion()),
    );
    if (created == true) _load();
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
              title: Text('Browse Quests',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              if (isWeb) _webHeader() else _searchField(),
              _filters(),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
      floatingActionButton: !isWeb
          ? FloatingActionButton(
              onPressed: _openAsk,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _webHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('All Quests',
              style: GoogleFonts.outfit(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: _openAsk,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ask a Quest'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
          ),
        ],
      ),
    );
  }

  /// The phone's only way to search: the desktop shell puts its box in the top
  /// bar, which a phone does not have (CLAUDE.md — nothing may be desktop-only).
  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: SearchField(
        hintText: 'Search quests',
        value: widget.search,
        onChanged: _onSearch,
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final s in const ['latest', 'bounty', 'votes'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s == 'latest'
                    ? 'Latest'
                    : s == 'bounty'
                        ? 'Top bounty'
                        : 'Most voted'),
                selected: _sort == s,
                onSelected: (_) {
                  if (_sort != s) setState(() => _sort = s);
                  _load();
                },
              ),
            ),
          const VerticalDivider(width: 24),
          for (final t in _tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(t),
                selected: _tag == t,
                onSelected: (on) {
                  setState(() => _tag = on ? t : null);
                  _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return ListSkeleton(count: 4, item: QuestTileSkeleton.new);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_quests.isEmpty) {
      // Three different nothings, and they need different copy: an empty
      // board, a tag nobody has used, and a search that missed.
      final (title, message) = switch ((_search.isEmpty, _tag == null)) {
        (false, _) => (
            'No quests match "$_search"',
            'Try a different word, or ask it yourself and put a bounty on it.'
          ),
        (true, false) => (
            'Nothing tagged "$_tag"',
            'Try another tag, or ask the first quest on this topic.'
          ),
        (true, true) => (
            'No quests yet',
            'Be the first to ask something. Attach a bounty and someone will help.'
          ),
      };

      return EmptyState(
        icon: _search.isEmpty ? Icons.explore_outlined : Icons.search_off_rounded,
        title: title,
        message: message,
        actionLabel: 'Ask a Quest',
        onAction: _openAsk,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        // Without this, a list shorter than the screen is not scrollable and
        // pull-to-refresh silently does nothing.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: _quests.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _quests.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          // Wrapped here rather than inside QuestTile so the tile itself stays
          // animation-free for the tests that pump it directly.
          return FadeSlideIn(
            index: i,
            child: QuestTile(
              quest: _quests[i],
              onTap: () async {
                await Navigator.push(
                  context,
                  appRoute((_) => QuestionDetail(questId: _quests[i].id)),
                );
                if (mounted) _load();
              },
            ),
          );
        },
      ),
    );
  }
}

/// One quest in a feed: author, bounty, title, tags and counts. Shared by the
/// browse list and the dashboard's recent-quests section so the two cannot
/// drift apart.
class QuestTile extends StatelessWidget {
  const QuestTile({super.key, required this.quest, required this.onTap});

  final Quest quest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.subtleFill,
                  child: Text(quest.author.initial,
                      style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(quest.author.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
                const Spacer(),
                if (quest.bountyPoints > 0) ...[
                  PointsBadge(points: quest.bountyPoints),
                  const SizedBox(width: 8),
                ],
                if (quest.isSolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.successTint,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Solved',
                        style: TextStyle(
                            color: AppColors.successDark,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(quest.title,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            // Tags and metadata each get their own run. Sharing one Row meant
            // the counts had a fixed width that a phone at 1.5x text scale
            // could not afford, and the tags had already shrunk to nothing.
            if (quest.tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in quest.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(t,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _meta(Icons.arrow_upward_rounded, '${quest.voteCount}'),
                _meta(Icons.chat_bubble_outline, '${quest.answerCount}'),
                // The server has counted these all along — question_service
                // increments view_count on every detail read — but nothing has
                // ever rendered the number.
                _meta(Icons.visibility_outlined, '${quest.viewCount}'),
                Text(timeAgo(quest.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(value,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      );
}
