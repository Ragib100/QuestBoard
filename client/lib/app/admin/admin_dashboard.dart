import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_management.dart';
import 'content_moderation.dart';
import 'platform_management.dart';
import 'reports_analytics.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Admin Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsOverview(),
                const SizedBox(height: 40),
                Text('Management Modules', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildAdminModulesGrid(context, isWeb),
                const SizedBox(height: 40),
                Text('Platform Health', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildHealthChart(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        _adminStatCard('1,250', 'Total Users', Icons.people_rounded, Colors.blue),
        const SizedBox(width: 20),
        _adminStatCard('3,450', 'Total Quests', Icons.quiz_rounded, Colors.green),
        const SizedBox(width: 20),
        _adminStatCard('8,760', 'Answers', Icons.question_answer_rounded, Colors.orange),
        const SizedBox(width: 20),
        _adminStatCard('125,000', 'Total XP', Icons.stars_rounded, Colors.purple),
      ],
    );
  }

  Widget _adminStatCard(String val, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(height: 16),
            Text(val, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminModulesGrid(BuildContext context, bool isWeb) {
    final modules = [
      {'title': 'User Management', 'icon': Icons.manage_accounts, 'color': Colors.blue, 'page': const UserManagement()},
      {'title': 'Content Moderation', 'icon': Icons.gavel_rounded, 'color': Colors.purple, 'page': const ContentModeration()},
      {'title': 'Platform Settings', 'icon': Icons.settings_rounded, 'color': Colors.teal, 'page': const PlatformManagement()},
      {'title': 'Reports & Analytics', 'icon': Icons.analytics_rounded, 'color': Colors.pink, 'page': const ReportsAnalytics()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWeb ? 4 : 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final m = modules[index];
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => m['page'] as Widget)),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(m['icon'] as IconData, color: m['color'] as Color, size: 40),
                const SizedBox(height: 12),
                Text(m['title'] as String, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthChart() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Center(child: Text('Chart Placeholder', style: TextStyle(color: Color(0xFF94A3B8)))),
    );
  }
}
