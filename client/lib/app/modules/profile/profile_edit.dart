import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../models/profile.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/user_service.dart';
import 'codeforces_verify.dart';

/// Editing form. The fields mirror the `users` table exactly — there is no
/// `bio` column, so there is no bio field.
class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  late final _usernameController =
      TextEditingController(text: widget.profile.username);
  late final _firstNameController =
      TextEditingController(text: widget.profile.firstName);
  late final _lastNameController =
      TextEditingController(text: widget.profile.lastName);
  late final _phoneController =
      TextEditingController(text: widget.profile.phoneNumber ?? '');
  late final _codeforcesController =
      TextEditingController(text: widget.profile.codeforcesHandle);

  final _picker = ImagePicker();
  File? _newAvatar;
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _codeforcesController.dispose();
    super.dispose();
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _newAvatar = File(image.path));
    }
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      _notify('Your username needs at least 3 characters.');
      return;
    }

    setState(() => _saving = true);
    try {
      String? imagePath;
      if (_newAvatar != null) {
        imagePath = await UserService.instance.uploadAvatar(_newAvatar!);
      }

      await UserService.instance.updateProfile(
        userId: widget.profile.id,
        username: username,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        codeforcesHandle: _codeforcesController.text.trim(),
        imageUrl: imagePath,
      );

      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _notify(e.message);
    } catch (_) {
      _notify('Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = UserService.instance.avatarUrl(widget.profile.imageUrl);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Edit Profile',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.subtleFill,
                        backgroundImage: _newAvatar != null
                            ? FileImage(_newAvatar!)
                            : (existing != null
                                ? NetworkImage(existing) as ImageProvider
                                : null),
                        child: (_newAvatar == null && existing == null)
                            ? const Icon(Icons.person,
                                size: 50, color: AppColors.textMuted)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: IconButton(
                            onPressed: _pickImage,
                            tooltip: 'Change photo',
                            icon: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  LabeledField(
                      label: 'Username', controller: _usernameController),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: LabeledField(
                              label: 'First Name',
                              controller: _firstNameController)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: LabeledField(
                              label: 'Last Name',
                              controller: _lastNameController)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LabeledField(
                      label: 'Phone Number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  LabeledField(
                    label: 'Codeforces Handle',
                    controller: _codeforcesController,
                    helper: widget.profile.codeforcesVerified
                        ? 'Verified. Changing it clears verification.'
                        : 'Used to verify daily challenge solves.',
                    hint: 'e.g. tourist',
                  ),
                  if (!widget.profile.codeforcesVerified &&
                      widget.profile.codeforcesHandle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // Only offered once a handle is saved: verification checks
                    // the handle already on the profile, not what is typed here.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CodeforcesVerify()),
                        ),
                        icon: const Icon(Icons.verified_outlined, size: 18),
                        label: const Text('Verify this handle'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('SAVE CHANGES'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
