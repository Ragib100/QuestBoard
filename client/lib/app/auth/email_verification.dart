import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';

class EmailVerification extends StatelessWidget {
  const EmailVerification({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 100, color: Color(0xFF7C3AED)),
              const SizedBox(height: 40),
              Text(
                'Verify Your Email',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent a verification link to your email address. Please check your inbox and click the link to continue.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF958DA1),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const Login()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('GO TO LOGIN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {},
                child: const Text('Resend Email', style: TextStyle(color: Color(0xFFD2BBFF))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
