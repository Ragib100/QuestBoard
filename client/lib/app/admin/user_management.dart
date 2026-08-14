import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class UserManagement extends StatelessWidget {
  const UserManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('User Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              _buildSearchRow(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ListView.builder(
                      itemCount: 12,
                      itemBuilder: (context, index) => _userRow(index),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add User')),
        ],
      ),
    );
  }

  Widget _userRow(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.subtleFill))),
      child: Row(
        children: [
          const CircleAvatar(radius: 18, backgroundColor: AppColors.subtleFill, child: Icon(Icons.person, size: 18, color: AppColors.textMuted)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User Adventurer $index', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('user$index@example.com', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          _statusBadge(index % 3 == 0 ? 'Admin' : 'User'),
          const SizedBox(width: 24),
          Text('${1000 + (index * 100)} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          IconButton(icon: const Icon(Icons.more_vert, color: AppColors.textMuted), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _statusBadge(String label) {
    final bool isAdmin = label == 'Admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: isAdmin ? AppColors.primaryTint : AppColors.subtleFill, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: isAdmin ? AppColors.primary : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
