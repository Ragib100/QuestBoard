import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';

/// Placeholder for the M4 daily challenge.
///
/// The `daily_challenges` and `challenge_attempts` tables exist but are empty,
/// and there is no endpoint yet. This screen previously showed a hardcoded
/// countdown ("12:45:30"), a hardcoded problem and a button that did nothing —
/// which reads as a working feature. An honest disabled state is the rule
/// (CLAUDE.md ground rule 4), so that is what it shows until the API lands.
class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Daily Challenge',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primary, size: 56),
                const SizedBox(height: 20),
                Text(
                  'Not open yet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'One problem a day, pulled from Codeforces, with bonus points '
                  'for solving it. It is still being built — there is nothing '
                  'to show here until it is.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52)),
                  child: const Text('Solve challenge'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Back to quests'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
