import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportsAnalytics extends StatelessWidget {
  const ReportsAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Reports & Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnalyticsGrid(),
                const SizedBox(height: 32),
                Text('User Growth', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _chartPlaceholder(),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: _buildRecentActivity()),
                    const SizedBox(width: 32),
                    Expanded(child: _buildTopCategories()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsGrid() {
    return Row(
      children: [
        _analyticsStat('1.2k', 'Daily Active', Colors.blue),
        const SizedBox(width: 20),
        _analyticsStat('850', 'New Quests', Colors.green),
        const SizedBox(width: 20),
        _analyticsStat('420', 'Flagged Content', Colors.red),
      ],
    );
  }

  Widget _analyticsStat(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
          children: [
            Text(val, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _chartPlaceholder() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: const Center(child: Icon(Icons.show_chart_rounded, size: 80, color: Color(0xFFF1F5F9))),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Activity Logs', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _logItem('User A logged in', '2m ago'),
          _logItem('User B posted quest', '10m ago'),
          _logItem('Admin C banned user D', '1h ago'),
        ],
      ),
    );
  }

  Widget _logItem(String action, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(action, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
          Text(time, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildTopCategories() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Categories', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _catItem('Programming', 1200),
          _catItem('Web Development', 850),
          _catItem('Data Science', 600),
        ],
      ),
    );
  }

  Widget _catItem(String label, int val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(val.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
