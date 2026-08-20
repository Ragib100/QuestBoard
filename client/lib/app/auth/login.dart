import '../../core/breakpoints.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/brand_art.dart';
import '../../core/widgets/labeled_field.dart';
import '../../services/common/auth_service.dart';
import 'forgot_password.dart';
import 'post_login_router.dart';
import 'signup.dart';
import '../../core/widgets/app_snack.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!EmailValidator.validate(email)) {
      _showError('Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Enter your password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(email: email, password: password);
      if (mounted) await goToLanding(context);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not sign you in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    showAppSnack(context, message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = isWideLayout(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text('QuestBoard',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text('Welcome Back!',
                          style: GoogleFonts.outfit(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Login to continue to QuestBoard.',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 32),
                      // AutofillGroup is what lets Android and the browser
                      // offer to fill — and then to save — the pair.
                      AutofillGroup(
                        child: Column(
                          children: [
                            LabeledField(
                              label: 'Email Address',
                              controller: _emailController,
                              hint: 'Enter your email',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                            ),
                            const SizedBox(height: 20),
                            LabeledField(
                              label: 'Password',
                              controller: _passwordController,
                              hint: 'Enter your password',
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) =>
                                  _isLoading ? null : _handleLogin(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ForgotPassword()),
                          ),
                          child: const Text('Forgot Password?',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('LOGIN'),
                      ),
                      const SizedBox(height: 24),
                      // Wrap, not Row: at a large system font scale the prompt
                      // and the link together are wider than a phone.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Don't have an account? "),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Signup()),
                            ),
                            child: const Text('Register',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isWeb)
            Expanded(
              child: Container(
                color: AppColors.background,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BrandArt(size: 280),
                      const SizedBox(height: 40),
                      Text('Unlock your potential',
                          style: GoogleFonts.outfit(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text(
                          'Ask, answer and earn points with fellow students.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
