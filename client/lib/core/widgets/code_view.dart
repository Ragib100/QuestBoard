import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../open_link.dart';
import 'app_snack.dart';

/// The languages the picker offers. Must match `LANGUAGES` in
/// `server/app/schemas/code.py` — the server rejects anything else, and the
/// column is a `varchar(20)`.
const codeLanguages = <String, String>{
  'text': 'Plain text',
  'c': 'C',
  'cpp': 'C++',
  'csharp': 'C#',
  'java': 'Java',
  'python': 'Python',
  'javascript': 'JavaScript',
  'typescript': 'TypeScript',
  'dart': 'Dart',
  'go': 'Go',
  'rust': 'Rust',
  'kotlin': 'Kotlin',
  'swift': 'Swift',
  'php': 'PHP',
  'ruby': 'Ruby',
  'sql': 'SQL',
  'bash': 'Bash',
};

/// Same ceiling as `MAX_CODE_CHARS` on the server. Enforced here too so the
/// limit is a counter that ticks down rather than a 422 after a long paste.
const maxCodeChars = 20000;

String languageLabel(String? code) =>
    codeLanguages[code ?? 'text'] ?? codeLanguages['text']!;

/// The one monospace style in the app.
///
/// Deliberately a platform font rather than a `google_fonts` face: code is the
/// one thing that must still render as code with no network, and every device
/// already ships a monospace family. `height` is fixed so the read-only block's
/// line-number gutter lines up with the lines it numbers.
const TextStyle codeTextStyle = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['Courier New', 'Roboto Mono'],
  fontSize: 13,
  height: 1.5,
  color: AppColors.textPrimary,
);

/// A submitted code block, read only.
///
/// Long lines scroll sideways instead of wrapping, because wrapped code is
/// unreadable and would also break the gutter's alignment. The block itself
/// never widens its parent, so it is safe inside a 320px column.
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.language,
    this.maxHeight = 360,
  });

  final String code;
  final String? language;

  /// Past this the block scrolls rather than pushing the rest of the screen
  /// off the bottom — a full solution can run to hundreds of lines.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final lines = code.split('\n');
    final gutterWidth = 20.0 + 8.0 * '${lines.length}'.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, lines.length),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The gutter stays put while the code scrolls sideways, so a
                  // long line never carries its own line number off-screen.
                  SizedBox(
                    width: gutterWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 1; i <= lines.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '$i',
                              style: codeTextStyle.copyWith(
                                  color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in lines)
                            Text(
                              line.isEmpty ? ' ' : line,
                              softWrap: false,
                              style: codeTextStyle,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, int lineCount) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              languageLabel(language),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$lineCount ${lineCount == 1 ? 'line' : 'lines'}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Copy code',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_all_outlined,
                size: 18, color: AppColors.textSecondary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (context.mounted) {
                showAppSnack(context, 'Code copied', tone: SnackTone.success);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// A link to a file someone attached to an answer or a challenge attempt.
///
/// The URL is a public Supabase Storage URL. Tapping copies it rather than
/// launching a browser: the app has no `url_launcher` dependency, and copying
/// works identically on a phone, the desktop build and the web build.
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({super.key, required this.url, this.name});

  final String url;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final label = (name == null || name!.isEmpty) ? 'Attached file' : name!;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      // Opens the file. It used to copy the URL and tell you to paste it in a
      // browser yourself, which predates url_launcher landing (D37) and is the
      // exact pattern CLAUDE.md's link rule forbids. [openLink] still falls
      // back to the clipboard when there is no browser to open.
      onTap: () async {
        final failure = await openLink(url);
        if (failure != null && context.mounted) {
          showAppSnack(context, failure);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_file, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
