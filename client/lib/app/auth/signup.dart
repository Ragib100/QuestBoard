import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:email_validator/email_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import '../../services/common/auth_service.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final GlobalKey<_CredentialsFormState> _credentialsFormKey =
      GlobalKey<_CredentialsFormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_isLoading) return;

    final isValid = _credentialsFormKey.currentState?.validate() ?? false;

    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception("Signup failed.");
      }

      if (!mounted) return;

      await _showCheckEmailDialog();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Step Indicator ---
              Row(
                children: [
                  _buildStepIndicator("1 Credentials", isActive: true),
                  const SizedBox(width: 12),
                  _buildStepIndicator("2 Profile", isActive: false),
                ],
              ),
              const SizedBox(height: 30),

              // --- Header Text ---
              Text(
                'Create Your Account',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Start your journey to the leaderboard',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF958DA1),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('⭐', style: TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 30),

              // --- Step Content ---
              CredentialsForm(
                key: _credentialsFormKey,
                emailController: _emailController,
                passwordController: _passwordController,
                confirmPasswordController: _confirmPasswordController,
                isLoading: _isLoading,
                onSubmit: _handleSignup,
              ),

              const SizedBox(height: 30),

              // --- Continue Button ---
              Center(child: _buildContinueButton()),
              const SizedBox(height: 20),

              // --- Footer ---
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const Login()),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: const Color(0xFF958DA1),
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: "Already have an account? "),
                        TextSpan(
                          text: 'Sign In',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD2BBFF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for the Step Tabs at the top
  Widget _buildStepIndicator(String label, {required bool isActive}) {
    return Expanded(
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5DE6FF)],
                )
              : null,
          color: isActive ? null : const Color(0x7F141C24),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: isActive ? Colors.white : const Color(0xFF958DA1),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // The glowing Continue button
  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0x3322D3EE),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0x667C3AED),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5DE6FF)],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sign Up',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _showCheckEmailDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
          title: Text(
            'Check your email',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'We have sent a verification email to:\n\n'
            '${_emailController.text.trim()}\n\n'
            'Please verify your email before logging in.',
            style: GoogleFonts.inter(
              color: const Color(0xFF958DA1),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go to Login',
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFFD2BBFF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Separate widget for the Step 1 Form to keep code clean
class CredentialsForm extends StatefulWidget {
  const CredentialsForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  State<CredentialsForm> createState() => _CredentialsFormState();
}

class _CredentialsFormState extends State<CredentialsForm> {
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  bool _showValidationErrors = false;
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;

  bool get _isEmailValid =>
      EmailValidator.validate(widget.emailController.text.trim());
  bool get _hasMinLength => widget.passwordController.text.length >= 8;
  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(widget.passwordController.text);
  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(widget.passwordController.text);
  bool get _hasNumber =>
      RegExp(r'[0-9]').hasMatch(widget.passwordController.text);
  bool get _hasSpecialCharacter => RegExp(
    r'[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]`;~]',
  ).hasMatch(widget.passwordController.text);
  bool get _passwordsMatch =>
      widget.confirmPasswordController.text.isNotEmpty &&
      widget.passwordController.text == widget.confirmPasswordController.text;
  bool get _passwordIsStrong =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialCharacter;

  int get _completedRequirements => [
    _hasMinLength,
    _hasUppercase,
    _hasLowercase,
    _hasNumber,
    _hasSpecialCharacter,
  ].where((isComplete) => isComplete).length;

  double get _strengthValue => _completedRequirements / 5;

  Color get _strengthColor {
    if (_completedRequirements <= 1) return const Color(0xFFFF5C5C);
    if (_completedRequirements <= 3) return const Color(0xFFFFB800);
    return const Color(0xFF22C55E);
  }

  String get _strengthLabel {
    if (widget.passwordController.text.isEmpty) return 'PASSWORD STRENGTH';
    if (_completedRequirements <= 1) return 'WEAK';
    if (_completedRequirements <= 4) return 'MEDIUM';
    return 'STRONG';
  }

  @override
  void initState() {
    super.initState();
    widget.emailController.addListener(_refreshValidation);
    widget.passwordController.addListener(_refreshValidation);
    widget.confirmPasswordController.addListener(_refreshValidation);
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    widget.emailController.removeListener(_refreshValidation);
    widget.passwordController.removeListener(_refreshValidation);
    widget.confirmPasswordController.removeListener(_refreshValidation);
    super.dispose();
  }

  void _refreshValidation() {
    setState(() {});
  }

  bool validate() {
    setState(() => _showValidationErrors = true);
    return _isEmailValid && _passwordIsStrong && _passwordsMatch;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          // Email Field
          _buildTextField(
            controller: widget.emailController,
            hint: "Email",
            icon: Icons.mail_outline,
            autofocus: true,
            focusNode: _emailFocusNode,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(_passwordFocusNode);
            },
          ),
          const SizedBox(height: 20),

          // Password Field
          _buildTextField(
            controller: widget.passwordController,
            hint: "Password",
            icon: Icons.lock_outline,
            focusNode: _passwordFocusNode,
            obscureText: _isPasswordHidden,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
            },
            suffix: _buildVisibilityButton(
              isHidden: _isPasswordHidden,
              onPressed: () {
                setState(() => _isPasswordHidden = !_isPasswordHidden);
              },
            ),
          ),

          // Password Strength Bar
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _strengthValue,
                    backgroundColor: const Color(0xFF30363D),
                    valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Text(
                _strengthLabel,
                style: GoogleFonts.inter(
                  color: _strengthColor,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Password Requirements Checklist
          _buildRequirementRow("At least 8 characters", _hasMinLength),
          _buildRequirementRow("One uppercase letter", _hasUppercase),
          _buildRequirementRow("One lowercase letter", _hasLowercase),
          _buildRequirementRow("One number (0-9)", _hasNumber),
          _buildRequirementRow("One special character", _hasSpecialCharacter),
          if (_showValidationErrors && !_passwordIsStrong) ...[
            const SizedBox(height: 4),
            _buildErrorText("Password must meet every requirement."),
          ],

          const SizedBox(height: 20),

          // Confirm Password Field
          _buildTextField(
            controller: widget.confirmPasswordController,
            hint: "Confirm Password",
            icon: Icons.refresh,
            focusNode: _confirmPasswordFocusNode,
            obscureText: _isConfirmPasswordHidden,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();

              if (!widget.isLoading) {
                widget.onSubmit();
              }
            },
            suffix: _buildVisibilityButton(
              isHidden: _isConfirmPasswordHidden,
              onPressed: () {
                setState(
                  () => _isConfirmPasswordHidden = !_isConfirmPasswordHidden,
                );
              },
            ),
          ),
          if (widget.confirmPasswordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildMatchText(),
          ] else if (_showValidationErrors) ...[
            const SizedBox(height: 8),
            _buildErrorText("Please confirm your password."),
          ],
          if (_showValidationErrors && !_isEmailValid) ...[
            const SizedBox(height: 8),
            _buildErrorText("Please enter a valid email address."),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool obscureText = false,
    bool autofocus = false,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      autofocus: autofocus,
      enabled: !widget.isLoading,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5B636D), fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF0D1117),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
      ),
    );
  }

  Widget _buildVisibilityButton({
    required bool isHidden,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        isHidden ? Icons.visibility_off : Icons.visibility,
        color: const Color(0xFF958DA1),
        size: 20,
      ),
    );
  }

  Widget _buildErrorText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(color: const Color(0xFFFF5C5C), fontSize: 12),
      ),
    );
  }

  Widget _buildMatchText() {
    final isMatch = _passwordsMatch;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle_outline : Icons.error_outline,
            color: isMatch ? const Color(0xFF22C55E) : const Color(0xFFFF5C5C),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isMatch ? "Passwords match" : "Passwords do not match",
            style: GoogleFonts.inter(
              color: isMatch
                  ? const Color(0xFF22C55E)
                  : const Color(0xFFFF5C5C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: isDone,
            onChanged: (val) {},
            side: const BorderSide(color: Color(0xFF30363D)),
            activeColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Text(
            text,
            style: GoogleFonts.inter(
              color: const Color(0xFF958DA1),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder for the Profile Step
class ProfileForm extends StatelessWidget {
  const ProfileForm({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Profile Details Step",
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
