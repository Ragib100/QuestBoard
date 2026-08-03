import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          'Admin Fortress',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsOverview(),
            const SizedBox(height: 32),
            Text(
              'Management Modules',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminModulesGrid(),
            const SizedBox(height: 32),
            _buildRecentReports(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Row(
      children: [
        _buildStatCard('Users', '1.2k', Icons.people, Colors.blue),
        const SizedBox(width: 16),
        _buildStatCard('Quests', '850', Icons.assignment, Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF958DA1),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminModulesGrid() {
    final modules = [
      {'title': 'User Management', 'icon': Icons.manage_accounts, 'color': Colors.orange},
      {'title': 'Content Management', 'icon': Icons.article, 'color': Colors.purple},
      {'title': 'Platform Management', 'icon': Icons.settings_applications, 'color': Colors.teal},
      {'title': 'Reports & Analytics', 'icon': Icons.analytics, 'color': Colors.pink},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF30363D)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(module['icon'] as IconData, color: module['color'] as Color, size: 32),
              const SizedBox(height: 8),
              Text(
                module['title'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentReports() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Reports',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spam detected in Quest #452',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Reported by 3 users',
                      style: GoogleFonts.inter(color: const Color(0xFF958DA1), fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Review'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
