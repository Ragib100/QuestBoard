import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/labeled_field.dart';
import '../../services/common/auth_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!EmailValidator.validate(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.forgotPassword(email: email);
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      _showMessage('Could not send the reset link. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: _sent ? _buildConfirmation() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forgot Password?',
            style:
                GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Enter the email you signed up with and we will send you a reset link.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 40),
        LabeledField(
          label: 'Email Address',
          controller: _emailController,
          hint: 'Enter your email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _submit(),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('SEND RESET LINK'),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
              color: AppColors.primaryTint, shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_read_rounded,
              size: 64, color: AppColors.primary),
        ),
        const SizedBox(height: 32),
        Text('Check your inbox',
            style:
                GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
          'We sent a reset link to ${_emailController.text.trim()}. Open it on '
          'this device to choose a new password.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BACK TO LOGIN'),
        ),
        TextButton(
          onPressed: _isLoading ? null : () => setState(() => _sent = false),
          child: const Text('Use a different email'),
        ),
      ],
    );
  }
}
