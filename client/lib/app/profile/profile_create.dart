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

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeforcesController = TextEditingController();

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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Color(0xFF1E293B))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text('Complete Your Profile', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Tell us a bit more about yourself.', style: TextStyle(color: Color(0xFF64748B))),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                    child: _selectedImage == null ? const Icon(Icons.camera_alt, color: Color(0xFF94A3B8), size: 30) : null,
                  ),
                ),
                const SizedBox(height: 32),
                _buildField('Username', _usernameController, 'e.g. adventurer_one'),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildField('First Name', _firstNameController, 'First Name')),
                    const SizedBox(width: 16),
                    Expanded(child: _buildField('Last Name', _lastNameController, 'Last Name')),
                  ],
                ),
                const SizedBox(height: 20),
                _buildField('Phone Number', _phoneController, 'Enter phone number'),
                const SizedBox(height: 20),
                _buildField('Codeforces Handle', _codeforcesController, 'e.g. tourist'),
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

  Widget _buildField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        TextField(controller: controller, decoration: InputDecoration(hintText: hint)),
      ],
    );
  }
}
