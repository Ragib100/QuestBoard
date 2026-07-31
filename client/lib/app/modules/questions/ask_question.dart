import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AskQuestion extends StatefulWidget {
  const AskQuestion({super.key});

  @override
  State<AskQuestion> createState() => _AskQuestionState();
}

class _AskQuestionState extends State<AskQuestion> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitQuest() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your quest.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiUrl = dotenv.env['API_URL'];
      if (apiUrl == null) {
        throw Exception('API_URL not found in .env file');
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }
      final token = session.accessToken;

      final response = await http.post(
        Uri.parse('$apiUrl/api/quests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'tags': _tagsController.text.split(',').map((e) => e.trim()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quest posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to post quest: ${error['detail']}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          'Start a New Quest',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Quest Title'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _titleController,
              hint: 'e.g. How to use Riverpod for state management?',
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            _buildLabel('Description'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descriptionController,
              hint: 'Describe your challenge in detail...',
              maxLines: 8,
            ),
            const SizedBox(height: 24),
            _buildLabel('Tags (comma separated)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _tagsController,
              hint: 'e.g. flutter, dart, riverpod',
              maxLines: 1,
            ),
            const SizedBox(height: 40),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.spaceGrotesk(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5B636D), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF161B22),
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

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5DE6FF)],
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitQuest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Text(
                'POST QUEST',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
      ),
    );
  }
}
