import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/common/auth_service.dart';
import './auth/login.dart';
import 'modules/questions/browse_questions.dart';
import 'modules/questions/ask_question.dart';
import 'modules/leaderboard/leaderboard_screen.dart';
import 'modules/daily_challenge/daily_challenge_screen.dart';
import 'modules/notifications/notifications_screen.dart';
import 'modules/profile/profile_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const UserHome(),
    const BrowseQuestions(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 960;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          if (isWeb) _buildWebSidebar(),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: isWeb ? _buildWebTopBar() : null,
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ),
              bottomNavigationBar: !isWeb ? _buildMobileNav() : null,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildWebTopBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      title: Container(
        width: 400,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'Search questions...',
            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF64748B)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        const SizedBox(width: 16),
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFF0066FF),
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
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildLogo(),
          const SizedBox(height: 40),
          _sidebarItem(0, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard'),
          _sidebarItem(1, Icons.explore_outlined, Icons.explore_rounded, 'Browse Quests'),
          _sidebarItem(2, Icons.emoji_events_outlined, Icons.emoji_events_rounded, 'Leaderboard'),
          _sidebarItem(3, Icons.person_outline, Icons.person_rounded, 'My Profile'),
          _sidebarItem(-2, Icons.notifications_none_outlined, Icons.notifications, 'Notifications'),
          _sidebarItem(-3, Icons.track_changes_outlined, Icons.track_changes, 'Daily Challenge'),
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
          const Icon(Icons.bolt_rounded, color: Color(0xFF0066FF), size: 28),
          const SizedBox(width: 10),
          Text(
            'QuestHub',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
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
            await AuthService.instance.logout();
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login()));
          } else {
            setState(() => _currentIndex = index >= 0 ? index : _currentIndex);
            if (index == -2) Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            if (index == -3) Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF64748B),
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        selectedTileColor: const Color(0xFF0066FF).withOpacity(0.08),
      ),
    );
  }

  Widget _buildMobileNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF0066FF),
      unselectedItemColor: const Color(0xFF94A3B8),
      type: BottomNavigationBarType.fixed,
      elevation: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Quests'),
        BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Ranks'),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
      ],
    );
  }
}

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 960;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back, Arafat!',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep learning and earning points!',
            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 16),
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
    );
  }

  Widget _buildStatsRow(bool isWeb) {
    return Row(
      children: [
        _statCard('12', 'Quests Solved', Icons.check_circle_rounded, Colors.green),
        const SizedBox(width: 20),
        _statCard('46', 'Active Quests', Icons.bolt_rounded, Colors.orange),
        const SizedBox(width: 20),
        _statCard('1,250', 'Total Points', Icons.stars_rounded, Colors.blue),
        const SizedBox(width: 20),
        _statCard('5', 'Badges', Icons.verified_rounded, Colors.purple),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE2E8F0).withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isWeb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Questions', () {}),
        const SizedBox(height: 16),
        _buildQuestionItem('What is the difference between Array and ArrayList in Java?', 'Java', '30m ago'),
        _buildQuestionItem('How to implement smooth scrolling in Flutter?', 'Flutter', '1h ago'),
        _buildQuestionItem('Explain the concept of Dependency Injection.', 'Design Patterns', '2h ago'),
        if (!isWeb) ...[
          const SizedBox(height: 32),
          _buildDailyChallenge(context),
          const SizedBox(height: 32),
          _buildTopLeaderboard(),
        ],
      ],
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Column(
      children: [
        _buildDailyChallenge(context),
        const SizedBox(height: 32),
        _buildTopLeaderboard(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('See all', style: TextStyle(color: Color(0xFF0066FF))),
        ),
      ],
    );
  }

  Widget _buildQuestionItem(String title, String tag, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(tag, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
              const Spacer(),
              Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChallenge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF0052CC)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
          const SizedBox(height: 16),
          Text(
            'Daily Challenge',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Solve today\'s challenge and earn 50 bonus points!',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyChallengeScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0066FF),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Solve Challenge'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Leaderboard',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 20),
          _leaderboardItem('1', 'John Doe', '2,450 pts'),
          _leaderboardItem('2', 'Sarah Khan', '2,150 pts'),
          _leaderboardItem('3', 'Arafat Hasan', '1,250 pts'),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('View full leaderboard', style: TextStyle(color: Color(0xFF0066FF))),
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
          CircleAvatar(radius: 14, backgroundColor: const Color(0xFFF1F5F9), child: Text(rank, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)))),
          const SizedBox(width: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
          const Spacer(),
          Text(pts, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
        ],
      ),
    );
  }
}
