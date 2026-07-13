import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../dashboard.dart';
import '../../services/common/user_service.dart';

class ProfileCreate extends StatefulWidget {
  const ProfileCreate({super.key});

  @override
  State<ProfileCreate> createState() => _ProfileCreateState();
}

class _ProfileCreateState extends State<ProfileCreate> {
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _codeforcesFocus = FocusNode();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeforcesController = TextEditingController();

  @override
  void dispose() {
    _usernameFocus.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    _codeforcesFocus.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _codeforcesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  void _removeImage() {
    if (_isLoading) return;
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> handleSubmit() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      await UserService.instance.createUser(
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        codeforcesHandle: _codeforcesController.text.trim(),
        imageFile: _selectedImage!,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0F1116);
    const cardColor = Color(0xFF16181F);
    const borderColor = Color(0xFF2C2E3E);
    const primaryGradient = LinearGradient(
      colors: [Color(0xFF8A56FF), Color(0xFF5CD2FF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    const textColorSecondary = Color(0xFF8B8D98);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {},
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- Step Indicator ---
              Row(
                children: [
                  _buildStepIndicator("1 Credentials", isActive: false),
                  const SizedBox(width: 12),
                  _buildStepIndicator("2 Profile", isActive: true),
                ],
              ),
              const SizedBox(height: 30),

              // --- Header Text ---
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Set Up Your Profile',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Text(
                      'Tell us who you are, adventurer',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF958DA1),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('⚔️', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Add Photo
              Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _selectedImage == null ? _pickImage : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF8A56FF),
                              width: 2,
                            ),
                            color: cardColor,
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _selectedImage == null
                              ? const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF8A56FF),
                                  size: 40,
                                )
                              : null,
                        ),
                      ),
                      if (_selectedImage == null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8A56FF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: backgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedImage == null)
                    const Text(
                      'Add Photo',
                      style: TextStyle(
                        color: Color(0xFFD6B4FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _isLoading ? null : _removeImage,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          tooltip: 'Remove',
                        ),
                        IconButton(
                          onPressed: _isLoading ? null : _pickImage,
                          icon: const Icon(
                            Icons.sync,
                            color: Color(0xFF5CD2FF),
                            size: 20,
                          ),
                          tooltip: 'Change',
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 32),

              // Form Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    _buildTextField(
                      hint: 'Choose a unique username',
                      prefixIcon: Icons.person_outline,
                      controller: _usernameController,
                      focusNode: _usernameFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_firstNameFocus);
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This is your public display name on the leaderboard',
                      style: TextStyle(color: textColorSecondary, fontSize: 10),
                    ),
                    const SizedBox(height: 20),

                    // First / Last Name
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            hint: 'First Name',
                            prefixIcon: Icons.person_outline,
                            controller: _firstNameController,
                            focusNode: _firstNameFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_lastNameFocus);
                            },
                            enabled: !_isLoading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            hint: 'Last Name',
                            prefixIcon: Icons.person_outline,
                            controller: _lastNameController,
                            focusNode: _lastNameFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) {
                              FocusScope.of(context).requestFocus(_phoneFocus);
                            },
                            enabled: !_isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Phone Number
                    _buildTextField(
                      hint: 'Phone Number',
                      prefixIcon: Icons.phone_outlined,
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_codeforcesFocus);
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 20),

                    // Codeforces Handle
                    _buildTextField(
                      hint: 'Codeforces Handle',
                      prefixIcon: Icons.code,
                      controller: _codeforcesController,
                      focusNode: _codeforcesFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) async {
                        FocusScope.of(context).unfocus();

                        if (!_isLoading) {
                          await handleSubmit();
                        }
                      },
                      enabled: !_isLoading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isLoading ? null : handleSubmit,
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'START MY QUEST',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_right_alt,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData prefixIcon,
    TextEditingController? controller,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onSubmitted,
    bool enabled = true,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1116),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2E3E)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8B8D98), fontSize: 14),
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFFC7A7FF),
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
}
