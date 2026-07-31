import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/admin_dashboard.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
            },
            icon: const Icon(Icons.admin_panel_settings, color: Colors.redAccent, size: 18),
            label: const Text('Admin', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 32),
            _buildMenuSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 32, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 45,
                backgroundColor: Color(0xFF7C3AED),
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adventurer_One',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Senior Quest Master',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Text(
                    'Level 42',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatItem('Quests', '124'),
          _buildStatItem('Solved', '86'),
          _buildStatItem('XP', '12.5k'),
          _buildStatItem('Rank', '#12'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF958DA1),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _buildMenuItem(Icons.settings, 'Account Settings'),
          _buildMenuItem(Icons.history, 'Quest History'),
          _buildMenuItem(Icons.badge, 'Badges & Achievements'),
          _buildMenuItem(Icons.help_outline, 'Help & Support'),
          const SizedBox(height: 16),
          _buildMenuItem(Icons.logout, 'Logout', isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? Colors.redAccent : const Color(0xFF7C3AED),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: isDestructive ? Colors.redAccent : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF484F58)),
        onTap: () {},
      ),
    );
  }
}
