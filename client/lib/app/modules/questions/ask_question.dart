import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AskQuestion extends StatefulWidget {
  const AskQuestion({super.key});

  @override
  State<AskQuestion> createState() => _AskQuestionState();
}

class _AskQuestionState extends State<AskQuestion> {
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Ask a Question', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Title'),
                  const Text('Be specific and imagine you’re asking a question to another person.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 12),
                  TextField(controller: _titleController, decoration: const InputDecoration(hintText: 'e.g. How to use Riverpod?')),
                  const SizedBox(height: 24),
                  _buildLabel('Category'),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(),
                    items: ['Flutter', 'Java', 'Python', 'Web'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {},
                    hint: const Text('Select a category'),
                  ),
                  const SizedBox(height: 24),
                  _buildLabel('Tags'),
                  const Text('Add up to 5 tags to describe what your question is about.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 12),
                  TextField(controller: _tagsController, decoration: const InputDecoration(hintText: 'e.g. dart, mobile, ui')),
                  const SizedBox(height: 24),
                  _buildLabel('Description'),
                  const Text('Include all the information someone would need to answer your question.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 12),
                  TextField(controller: _descController, maxLines: 8, decoration: const InputDecoration(hintText: 'Provide more details about your quest...')),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(minimumSize: const Size(180, 52)),
                        child: const Text('Publish Question'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(text, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
    );
  }
}
