import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Daily Challenge', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF0066FF), size: 64),
                  const SizedBox(height: 24),
                  Text('Today\'s Challenge', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Solve the challenge and earn bonus points.', style: TextStyle(color: Color(0xFF64748B), fontSize: 16)),
                  const SizedBox(height: 40),
                  _buildTimer(),
                  const SizedBox(height: 48),
                  _buildChallengeDetail(),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                    child: const Text('SOLVE CHALLENGE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timeBox('12', 'Hours'),
        const SizedBox(width: 16),
        _timeBox('45', 'Minutes'),
        const SizedBox(width: 16),
        _timeBox('30', 'Seconds'),
      ],
    );
  }

  Widget _timeBox(String val, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(val, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)))),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildChallengeDetail() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reverse a String', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Given a string s, reverse the string and return it.', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          const Text('Example:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
            child: const Text('Input: s = "hello"\nOutput: "olleh"', style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
