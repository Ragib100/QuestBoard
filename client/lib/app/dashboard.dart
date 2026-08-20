import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/common/auth_service.dart';
import './auth/login.dart';
import 'admin/admin_dashboard.dart';
import 'modules/questions/browse_questions.dart';
import 'modules/questions/question_detail.dart';
import 'modules/leaderboard/leaderboard_screen.dart';
import 'modules/daily_challenge/daily_challenge_screen.dart';
import 'modules/notifications/notifications_screen.dart';
import 'modules/profile/profile_screen.dart';
import '../core/app_colors.dart';
import '../core/motion.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/async_states.dart';
import '../core/widgets/search_field.dart';
import '../models/profile.dart';
import '../services/api/api_client.dart';
import '../models/gamification.dart';
import '../models/quest.dart';
import '../services/common/gamification_service.dart';
import '../services/common/quest_service.dart';
import '../services/common/user_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;
  Profile? _me;
  int _unread = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Hands the term to the Browse tab and switches to it. Searching from the
  /// dashboard has to land somewhere that can show a list, and Browse already
  /// owns paging, empty states and the tag filters.
  void _search(String query) {
    setState(() {
      _query = query.trim();
      _currentIndex = 1;
    });
  }

  /// Balance and unread count, pulled together whenever the user navigates.
  /// Polling on a timer would cost more than it is worth for a class project —
  /// every screen that can change either of these already triggers a refresh.
  Future<void> _refresh() async {
    // Independent calls — running them together halves the wait.
    await Future.wait([_loadMe(), _loadUnread()]);
  }

  Future<void> _loadUnread() async {
    try {
      final count = await GamificationService.instance.unreadCount();
      if (mounted) setState(() => _unread = count);
    } on ApiException {
      // Offline or not onboarded — leave the badge as it was.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (mounted) _loadUnread();
  }

  /// The signed-in user's balance, shown in the app bar and refreshed whenever
  /// the user comes back from a screen that can spend or earn points.
  Future<void> _loadMe() async {
    try {
      final me = await UserService.instance.me();
      if (mounted) setState(() => _me = me);
    } on ApiException {
      // Not onboarded yet, or offline — the app bar simply omits the balance.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 960;

    // `embedded` suppresses each tab's own app bar: the phone shell already
    // draws one, and two stacked bars would eat 112px of a 640px screen.
    final pages = [
      UserHome(onBrowseAll: () => setState(() => _currentIndex = 1)),
      BrowseQuestions(embedded: !isWeb, search: _query),
      LeaderboardScreen(embedded: !isWeb),
      DailyChallengeScreen(embedded: !isWeb),
      ProfileScreen(embedded: !isWeb),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          if (isWeb) _buildWebSidebar(),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: isWeb ? _buildWebTopBar() : _buildMobileTopBar(),
              body: Column(
                children: [
                  if (_me?.isSuspended ?? false) const _SuspendedBanner(),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        // Wraps the stack rather than replacing it: an
                        // AnimatedSwitcher keyed on the index would cross-fade
                        // identically but rebuild every tab from scratch on
                        // each tap, re-firing their loads and losing scroll.
                        child: TabTransition(
                          index: _currentIndex,
                          child: IndexedStack(
                            index: _currentIndex,
                            children: pages,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: !isWeb ? _buildMobileNav() : null,
            ),
          ),
        ],
      ),
    );
  }

  /// The phone shell's only chrome. Everything the sidebar offers on desktop
  /// has to live here or be unreachable — the bottom bar holds four tabs and
  /// there is nowhere else to put a balance, a bell, or a way to sign out.
  PreferredSizeWidget _buildMobileTopBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 16,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_currentIndex == 0) ...[
            const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              const [
                'QuestBoard',
                'Browse Quests',
                'Leaderboard',
                'Daily Challenge',
                'My Profile'
              ]
                  .elementAtOrNull(_currentIndex) ??
                  'QuestBoard',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (_me != null) PointsBadge(points: _me!.points),
        _NotificationBell(count: _unread, onPressed: _openNotifications),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          tooltip: 'More',
          onSelected: (value) {
            if (value == 'admin') _openAdmin();
            if (value == 'logout') _logout();
          },
          itemBuilder: (_) => [
            // Admins only — the endpoints behind it 403 for everyone else, so
            // showing the entry to a normal user would only ever disappoint.
            if (_me?.isAdmin ?? false)
              const PopupMenuItem(
                value: 'admin',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Admin'),
                ),
              ),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded, color: AppColors.danger),
                title: Text('Log out', style: TextStyle(color: AppColors.danger)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openAdmin() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
    if (mounted) _refresh();
  }

  /// Signing out is destructive enough to confirm — an accidental tap on a
  /// phone would otherwise drop the session and the unsaved draft with it.
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to post or answer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
      (route) => false,
    );
  }

  PreferredSizeWidget _buildWebTopBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      title: Container(
        width: 400,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.subtleFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SearchField(
          hintText: 'Search quests',
          bare: true,
          onChanged: _search,
        ),
      ),
      actions: [
        if (_me != null) ...[
          PointsBadge(points: _me!.points, label: '${_me!.points} pts'),
          const SizedBox(width: 16),
        ],
        _NotificationBell(count: _unread, onPressed: _openNotifications),
        const SizedBox(width: 16),
        const CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildLogo(),
          const SizedBox(height: 40),
          _sidebarItem(0, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard'),
          _sidebarItem(1, Icons.explore_outlined, Icons.explore_rounded, 'Browse Quests'),
          _sidebarItem(2, Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Leaderboard'),
          _sidebarItem(3, Icons.track_changes_outlined, Icons.track_changes, 'Daily Challenge'),
          _sidebarItem(4, Icons.person_outline, Icons.person_rounded, 'My Profile'),
          _sidebarItem(-2, Icons.notifications_none_outlined, Icons.notifications, 'Notifications'),
          if (_me?.isAdmin ?? false)
            _sidebarItem(-4, Icons.shield_outlined, Icons.shield, 'Admin'),
          const Spacer(),
          _sidebarItem(-1, Icons.logout_rounded, Icons.logout_rounded, 'Logout', isLogout: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 10),
          Text(
            'QuestBoard',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, IconData activeIcon, String label, {bool isLogout = false}) {
    bool isSelected = _currentIndex == index;
    // Map secondary pages to their active states if necessary
    if (label == 'Notifications' && _currentIndex == -2) isSelected = true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () async {
          if (isLogout) {
            await _logout();
          } else {
            setState(() => _currentIndex = index >= 0 ? index : _currentIndex);
            if (index == -2) _openNotifications();
            if (index == -4) _openAdmin();
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
      ),
    );
  }

  /// Five tabs, and the fifth is the Daily Challenge.
  ///
  /// It used to be an item in the phone's overflow menu, which made the one
  /// screen with a deadline on it the hardest one to reach. Nothing was
  /// dropped to make room: Material's fixed bar takes five, and at 320px that
  /// is 64px per tab — enough for an icon and a short label, which is why
  /// these read "Ranks" and "Daily" rather than their full titles.
  ///
  /// The bar carried `elevation: 10`, the only drop shadow left in the app and
  /// against docs/design-system.md. Separation now comes from a top border, the
  /// same treatment the top app bar already uses; the rest of the styling lives
  /// in `bottomNavigationBarTheme`.
  Widget _buildMobileNav() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        // Five items would otherwise switch the bar to `shifting`, which hides
        // every inactive label and animates the icons around.
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _refresh();
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.explore_rounded), label: 'Quests'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_rounded), label: 'Ranks'),
          BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_rounded), label: 'Daily'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Shown to a suspended account instead of letting them find out by tapping
/// Post and getting a 403 they did not expect.
class _SuspendedBanner extends StatelessWidget {
  const _SuspendedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.dangerTint,
      child: const Row(
        children: [
          Icon(Icons.block_rounded, size: 18, color: AppColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account is suspended. You can still read QuestBoard, '
              'but not post, answer or vote.',
              style: TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bell with an unread count. The number is capped so a long absence cannot
/// stretch the app bar.
class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined,
              color: AppColors.textSecondary),
          tooltip: count == 0 ? 'Notifications' : '$count unread',
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class UserHome extends StatefulWidget {
  const UserHome({super.key, required this.onBrowseAll});

  /// Switches the shell to the Browse tab — the home feed only shows the
  /// newest few quests, so "See all" has to hand off rather than navigate.
  final VoidCallback onBrowseAll;

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  Profile? _me;
  List<LeaderboardEntry> _top = const [];
  List<Quest> _recent = const [];
  int _badgeCount = 0;
  int _openQuests = 0;

  /// Distinguishes "the server said there are no quests" from "we never got an
  /// answer" — the two need different copy, and neither may show fake rows.
  bool _loadFailed = false;

  /// What actually went wrong, when we know. The screen used to say "could not
  /// load" and leave the user with nowhere to go.
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads each tile independently.
  ///
  /// This was one `Future.wait` over four calls, which meant any single
  /// failure — a profile that had not finished onboarding, a leaderboard
  /// hiccup — threw the whole page away and left every tile at zero with no
  /// explanation. `Future.wait` is all-or-nothing by design and that is the
  /// wrong shape for a dashboard: the parts are independent, so a failure in
  /// one has no business blanking the others.
  ///
  /// They still go out together; only the failure handling is per-call.
  Future<void> _load() async {
    final failures = <String>[];

    Future<void> attempt(String what, Future<void> Function() run) async {
      try {
        await run();
      } on ApiException catch (e) {
        // Never fall back to a plausible-looking number: an empty tile is
        // honest, a made-up one is not.
        failures.add('$what (${e.message})');
      }
    }

    await Future.wait([
      attempt('your profile', () async {
        final me = await UserService.instance.me();
        if (!mounted) return;
        setState(() => _me = me);

        // Chained deliberately: the badge list is keyed by user id, so it
        // cannot start until the profile lands.
        final badges = await GamificationService.instance.badgesFor(me.id);
        if (!mounted) return;
        setState(() => _badgeCount = badges.where((b) => b.isEarned).length);
      }),
      attempt('the leaderboard', () async {
        final board =
            await GamificationService.instance.leaderboard(period: 'all_time');
        if (!mounted) return;
        setState(() => _top = board.entries.take(3).toList());
      }),
      attempt('recent quests', () async {
        final feed = await QuestService.instance.list(limit: 3);
        if (!mounted) return;
        setState(() {
          _recent = feed.items;
          _openQuests = feed.total;
        });
      }),
    ]);

    if (!mounted) return;
    setState(() {
      _loadFailed = failures.isNotEmpty;
      _error = failures.isEmpty ? null : 'Could not load ${failures.first}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 960;

    // The empty state has told people to "pull to refresh" since it was
    // written, and there was nothing here to pull. There is now.
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        // Always scrollable, or a short page on a big screen has no overscroll
        // for the gesture to start from and the refresh never fires.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 20, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) _errorBanner(),
            Text(
              _me == null ? 'Welcome back!' : 'Welcome back, ${_me!.firstName.isEmpty ? _me!.username : _me!.firstName}!',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep learning and earning points!',
              style:
                  GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildStatsRow(isWeb),
            const SizedBox(height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildMainContent(context, isWeb)),
                if (isWeb) ...[
                  const SizedBox(width: 32),
                  Expanded(child: _buildSidebarContent(context)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Says what failed and offers the retry, instead of leaving four zeroes on
  /// screen for the user to interpret.
  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.warningDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                  color: AppColors.warningDark, fontSize: 13, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: _load,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Four tiles across on desktop, two per row on a phone.
  ///
  /// A plain Row overflowed on a 720px screen: each tile has fixed padding and
  /// an icon, so four of them simply do not fit. LayoutBuilder gives the tiles
  /// a real width to size against instead of letting them overflow.
  Widget _buildStatsRow(bool isWeb) {
    final tiles = [
      _statCard(_me?.points ?? 0, 'Points', Icons.stars_rounded,
          AppColors.points),
      _statCard(_openQuests, 'Open Quests', Icons.bolt_rounded,
          AppColors.primary),
      _statCard(_me?.streakDays ?? 0, 'Day Streak',
          Icons.local_fire_department_rounded, AppColors.streak),
      _statCard(_badgeCount, 'Badges', Icons.verified_rounded,
          AppColors.success),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = 16.0;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

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

  /// The shadow that used to be here was the only one in the app and
  /// docs/design-system.md forbids shadows outright, so the tile now takes the
  /// standard border treatment via [AppCard] like every other card.
  Widget _statCard(int value, String label, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          // Expanded + ellipsis: a four-digit score must never push the
          // label off the edge of a narrow tile.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // animateFromZero is safe here: no test pumps UserHome, and
                // the tiles build with 0 before _load() returns, so the roll-up
                // lands exactly when the real numbers arrive.
                CountUpText(
                  value: value,
                  animateFromZero: true,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Quests', widget.onBrowseAll),
        const SizedBox(height: 16),
        if (_recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              _loadFailed
                  ? 'Could not load quests. Pull to refresh once you are back online.'
                  : 'No quests yet. Be the first to ask one.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final (i, quest) in _recent.indexed)
            FadeSlideIn(
              index: i,
              child: QuestTile(
                quest: quest,
                onTap: () async {
                  await Navigator.push(
                    context,
                    appRoute((_) => QuestionDetail(questId: quest.id)),
                  );
                  if (mounted) _load();
                },
              ),
            ),
        if (!isWeb) ...[
          const SizedBox(height: 32),
          _buildDailyChallenge(context),
          const SizedBox(height: 32),
          _buildTopLeaderboard(context),
        ],
      ],
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Column(
      children: [
        _buildDailyChallenge(context),
        const SizedBox(height: 32),
        _buildTopLeaderboard(context),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('See all', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildDailyChallenge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_fire_department,
              color: AppColors.streak, size: 32),
          const SizedBox(height: 16),
          Text(
            'Daily Challenge',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          // No number here on purpose: this card never fetches the challenge,
          // so the bonus was hardcoded to 50 and would have quietly lied the
          // day it changed. The real figure is on the challenge screen.
          const Text(
            'Solve today\'s challenge and earn bonus points.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Solve Challenge'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLeaderboard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Leaderboard',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          if (_top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No rankings yet.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            )
          else
            for (final entry in _top)
              _leaderboardItem('${entry.rank}', entry.user.displayName,
                  '${entry.score} pts'),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              child: const Text('View full leaderboard', style: TextStyle(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardItem(String rank, String name, String pts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: AppColors.subtleFill, child: Text(rank, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
          const SizedBox(width: 12),
          // A long display name must ellipsize, not push the score off-screen.
          Expanded(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          Text(pts, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}
