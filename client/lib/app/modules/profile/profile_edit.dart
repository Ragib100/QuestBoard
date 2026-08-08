import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileEdit extends StatefulWidget {
  const ProfileEdit({super.key});

  @override
  State<ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  final _usernameController = TextEditingController(text: 'arafathasan');
  final _bioController = TextEditingController(text: 'Passionate developer and problem solver. Love to build stuff with Flutter.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Edit Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  Stack(
                    children: [
                      const CircleAvatar(radius: 50, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 50, color: Color(0xFF94A3B8))),
                      Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 18, backgroundColor: const Color(0xFF0066FF), child: IconButton(onPressed: () {}, icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white)))),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildField('Username', _usernameController),
                  const SizedBox(height: 24),
                  _buildField('Bio', _bioController, maxLines: 4),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
                    },
                    child: const Text('SAVE CHANGES'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(controller: controller, maxLines: maxLines),
      ],
    );
  }
}
