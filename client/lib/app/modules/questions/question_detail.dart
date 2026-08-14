import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

class QuestionDetail extends StatefulWidget {
  final String title;
  final String author;
  final String time;

  const QuestionDetail({
    super.key,
    required this.title,
    required this.author,
    required this.time,
  });

  @override
  State<QuestionDetail> createState() => _QuestionDetailState();
}

class _QuestionDetailState extends State<QuestionDetail> {
  final TextEditingController _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Quest Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuestionHeader(),
                const SizedBox(height: 24),
                _buildQuestionContent(),
                const SizedBox(height: 40),
                const Divider(color: AppColors.border),
                const SizedBox(height: 32),
                _buildAnswersSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: _buildAnswerInput(),
    );
  }

  Widget _buildQuestionHeader() {
    return Row(
      children: [
        CircleAvatar(radius: 20, backgroundColor: AppColors.subtleFill, child: Text(widget.author[0], style: const TextStyle(color: AppColors.primary))),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.author, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text(widget.time, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: AppColors.successTint, borderRadius: BorderRadius.circular(20)),
          child: const Text('Open', style: TextStyle(color: AppColors.successDark, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildQuestionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 20),
        const Text(
          'I am trying to implement a high-performance liquid animation effect in my Flutter app using CustomPainter. I need to handle complex bezier paths and ensure smooth 60fps performance on mid-range devices.\n\nSpecifically, I am struggling with the math for the wave motion and how to efficiently repaint only the necessary parts of the canvas.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          children: [_buildTag('Flutter'), _buildTag('Animation'), _buildTag('CustomPainter')],
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.subtleFill, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    );
  }

  Widget _buildAnswersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Answers (3)', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildAnswerTile('CodeGuru', '30m ago', 'For 60fps animations, you should use the AnimationController to drive your CustomPainter.', true),
        _buildAnswerTile('FlutterFan', '1h ago', 'I recommend checking out the "Drawing on Canvas" section in the official documentation.', false),
      ],
    );
  }

  Widget _buildAnswerTile(String user, String time, String text, bool isAccepted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAccepted ? AppColors.success : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 12, backgroundColor: AppColors.subtleFill, child: Icon(Icons.person, size: 12, color: AppColors.textMuted)),
              const SizedBox(width: 8),
              Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isAccepted) const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAnswerInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _answerController, decoration: const InputDecoration(hintText: 'Write your answer...'))),
          const SizedBox(width: 16),
          IconButton(onPressed: () {}, icon: const Icon(Icons.send_rounded, color: AppColors.primary)),
        ],
      ),
    );
  }
}
