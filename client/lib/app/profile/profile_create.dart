import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/widgets/labeled_field.dart';
import '../../services/api/api_client.dart';
import '../../services/common/user_service.dart';
import '../dashboard.dart';
import '../../core/app_colors.dart';
import '../../core/widgets/app_snack.dart';

class ProfileCreate extends StatefulWidget {
  const ProfileCreate({super.key});

  @override
  State<ProfileCreate> createState() => _ProfileCreateState();
}

class _ProfileCreateState extends State<ProfileCreate> {
  bool _isLoading = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeforcesController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _codeforcesController.dispose();
    super.dispose();
  }

  void _showError(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    showAppSnack(context, message, tone: tone);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _selectedImage = File(image.path));
  }

  Future<void> handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      await UserService.instance.createUser(
        username: _usernameController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        codeforcesHandle: _codeforcesController.text.trim(),
        imageFile: _selectedImage,
      );
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      // Avatar upload goes straight to Supabase Storage, so a failure here can
      // be a StorageException whose toString() is a stack of internals. Never
      // put that in front of a student finishing signup.
      _showError('Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: AppColors.textPrimary)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text('Complete Your Profile', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Tell us a bit more about yourself.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.subtleFill,
                    backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                    child: _selectedImage == null ? const Icon(Icons.camera_alt, color: AppColors.textMuted, size: 30) : null,
                  ),
                ),
                const SizedBox(height: 32),
                LabeledField(label: 'Username', controller: _usernameController, hint: 'e.g. adventurer_one'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: LabeledField(label: 'First Name', controller: _firstNameController, hint: 'First Name')),
                    const SizedBox(width: 16),
                    Expanded(child: LabeledField(label: 'Last Name', controller: _lastNameController, hint: 'Last Name')),
                  ],
                ),
                const SizedBox(height: 20),
                LabeledField(label: 'Phone Number', controller: _phoneController, hint: 'Enter phone number'),
                const SizedBox(height: 20),
                LabeledField(label: 'Codeforces Handle', controller: _codeforcesController, hint: 'e.g. tourist'),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : handleSubmit,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('GET STARTED'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
