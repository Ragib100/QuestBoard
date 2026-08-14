import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/labeled_field.dart';

/// Profile editing form.
///
/// The fields mirror the `users` table exactly (see docs/data-model.md) — there
/// is no `bio` column, so there is no bio field. Saving is disabled until
/// `PATCH /api/users/{id}` exists; see TASKS.md (M1).
class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeforcesController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _codeforcesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.subtleFill,
                    child: Icon(Icons.person,
                        size: 50, color: AppColors.textMuted),
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
                      hint: 'e.g. tourist'),
                  const SizedBox(height: 32),
                  const _NotConnectedNotice(),
                  const SizedBox(height: 16),
                  const ElevatedButton(
                    onPressed: null,
                    child: Text('SAVE CHANGES'),
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

class _NotConnectedNotice extends StatelessWidget {
  const _NotConnectedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Editing is not live yet — the profile update endpoint has not '
              'been built.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
