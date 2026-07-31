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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: const Color(0xFF161B22),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF7C3AED),
          unselectedItemColor: const Color(0xFF958DA1),
          selectedLabelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 12),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Browse'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Ranks'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(),
                const SizedBox(height: 32),
                _buildModulesGrid(context),
                const SizedBox(height: 32),
                _buildSectionHeader('Recent Activity'),
                const SizedBox(height: 16),
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF161B22),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
        title: Text(
          'QuestBoard',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: () async {
            await AuthService.instance.logout();
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const Login()),
              );
            }
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: GoogleFonts.inter(color: const Color(0xFF958DA1), fontSize: 16),
        ),
        Text(
          'Adventurer!',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModulesGrid(BuildContext context) {
    final modules = [
      {'title': 'Browse Quests', 'icon': Icons.search_rounded, 'color': Colors.blue, 'page': const BrowseQuestions()},
      {'title': 'Ask Question', 'icon': Icons.add_box_rounded, 'color': Colors.green, 'page': const AskQuestion()},
      {'title': 'User Profile', 'icon': Icons.person_rounded, 'color': Colors.orange, 'page': const ProfileScreen()},
      {'title': 'Notifications', 'icon': Icons.notifications_rounded, 'color': Colors.purple, 'page': const NotificationsScreen()},
      {'title': 'Daily Challenge', 'icon': Icons.track_changes_rounded, 'color': Colors.red, 'page': const DailyChallengeScreen()},
      {'title': 'Leaderboard', 'icon': Icons.emoji_events_rounded, 'color': Colors.amber, 'page': const LeaderboardScreen()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return _buildModuleCard(
          context,
          module['title'] as String,
          module['icon'] as IconData,
          module['color'] as Color,
          module['page'] as Widget,
        );
      },
    );
  }

  Widget _buildModuleCard(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text('View All', style: TextStyle(color: Color(0xFF7C3AED))),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      children: List.generate(3, (index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF21262D),
              child: Icon(Icons.history, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    index == 0 ? 'Solved: Flutter BloC' : index == 1 ? 'New Quest Posted' : 'Achievement Earned',
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'You earned +50 XP and a badge!',
                    style: GoogleFonts.inter(color: const Color(0xFF958DA1), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Text('2h ago', style: TextStyle(color: Color(0xFF484F58), fontSize: 11)),
          ],
        ),
      )),
    );
  }
}
