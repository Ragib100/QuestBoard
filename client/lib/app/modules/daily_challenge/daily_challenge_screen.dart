import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Daily Challenge', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 64),
                  const SizedBox(height: 24),
                  Text('Today\'s Challenge', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Solve the challenge and earn bonus points.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
          decoration: BoxDecoration(color: AppColors.subtleFill, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(val, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildChallengeDetail() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reverse a String', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Given a string s, reverse the string and return it.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          const Text('Example:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(8)),
            child: const Text('Input: s = "hello"\nOutput: "olleh"', style: TextStyle(color: Colors.white, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
