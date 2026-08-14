import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';

class PlatformManagement extends StatelessWidget {
  const PlatformManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Platform Management', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              _buildCard('General Settings', [
                _buildSwitchTile('Maintenance Mode', false),
                _buildSwitchTile('Enable Registrations', true),
                _buildSwitchTile('Enable Search', true),
              ]),
              const SizedBox(height: 32),
              _buildCard('Points & Rewards', [
                _buildInputTile('XP per Answer', '50'),
                _buildInputTile('XP per Upvote', '10'),
                _buildInputTile('XP per Quest', '20'),
              ]),
              const SizedBox(height: 40),
              ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)), child: const Text('Save Changes')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String label, bool value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Switch(value: value, onChanged: (v) {}, activeThumbColor: AppColors.primary),
    );
  }

  Widget _buildInputTile(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(width: 80, child: TextField(textAlign: TextAlign.center, decoration: InputDecoration(hintText: val, contentPadding: const EdgeInsets.symmetric(horizontal: 10)))),
        ],
      ),
    );
  }
}
