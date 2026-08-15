import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/labeled_field.dart';

import '../../services/common/auth_service.dart';
import '../auth/login.dart';
import '../../core/app_colors.dart';
import '../../core/widgets/app_snack.dart';

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _tell(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    showAppSnack(context, message, tone: tone);
  }

  Future<void> _submit() async {
    if (_passwordController.text.length < 8) {
      _tell('Use at least 8 characters.');
      return;
    }
    // Recovery links are single-use and expire. Without a session the update
    // fails with a raw "Auth session missing" — say what actually went wrong.
    if (Supabase.instance.client.auth.currentSession == null) {
      _tell('This reset link has expired or was already used. Request a new '
          'one from the login screen.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance
          .updatePassword(password: _passwordController.text);
      if (!mounted) return;
      // Reached via a deep link with pushAndRemoveUntil, so there is nothing to
      // pop back to — send the user to login with their new password.
      showAppSnack(context, 'Password updated. Please sign in.',
          tone: SnackTone.success);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
    } on AuthException catch (e) {
      _tell(e.message);
    } catch (_) {
      _tell('Could not update your password. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reset Password', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Choose a new, strong password for your account.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 40),
                LabeledField(
                  label: 'New Password',
                  controller: _passwordController,
                  hint: 'Enter at least 8 characters',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _isLoading ? null : _submit(),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: Text(_isLoading ? 'UPDATING...' : 'UPDATE PASSWORD'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
