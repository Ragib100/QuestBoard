import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../services/common/auth_service.dart';
import 'login.dart';

/// Where signup lands. The account exists but is unverified until the emailed
/// link is opened, which deep-links back into ProfileCreate.
class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key, this.email});

  /// The address the link was sent to. Needed to offer a resend — without it
  /// the button has nothing to send to, so it is hidden rather than dead.
  final String? email;

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> {
  bool _sending = false;

  Future<void> _resend() async {
    final email = widget.email;
    if (email == null) return;

    setState(() => _sending = true);
    try {
      await AuthService.instance.resendVerification(email: email);
      _tell('Sent again. Check your inbox, and your spam folder.');
    } on AuthException catch (e) {
      _tell(e.message);
    } catch (_) {
      _tell('Could not resend right now. Check your connection.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            // Scrollable: at a large font scale, or on a short phone, this
            // column is taller than the viewport and used to clip the buttons.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: AppColors.primaryTint, shape: BoxShape.circle),
                    child: const Icon(Icons.mark_email_read_rounded,
                        size: 56, color: AppColors.primary),
                  ),
                  const SizedBox(height: 28),
                  Text('Verify your email',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    widget.email == null
                        ? 'We sent you a verification link. Open it on this '
                            'device to finish setting up your profile.'
                        : 'We sent a verification link to ${widget.email}. '
                            'Open it on this device to finish setting up your '
                            'profile.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => const Login())),
                    child: const Text('GO TO LOGIN'),
                  ),
                  if (widget.email != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _sending ? null : _resend,
                      child: Text(
                        _sending ? 'Sending…' : "Didn't get it? Resend",
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
