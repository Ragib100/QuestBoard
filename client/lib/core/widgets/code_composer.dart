import 'package:flutter/material.dart';

import '../../models/code_submission.dart';
import '../../services/common/attachment_service.dart';
import '../app_colors.dart';
import 'app_snack.dart';
import 'code_view.dart';

/// The in-app editor: write or paste code, label its language, optionally
/// attach a file.
///
/// Collapsed to a single button until it is needed — most answers are prose,
/// and an always-open code pane would push the actual composer off a phone
/// screen. Reports every change through [onChanged]; the parent decides what
/// to do with it, which is what lets the same widget serve both the answer
/// composer and the challenge claim sheet.
class CodeComposer extends StatefulWidget {
  const CodeComposer({
    super.key,
    required this.onChanged,
    this.initial = CodeSubmission.empty,
    this.enabled = true,
    this.label = 'Add code',
    this.onSubmit,
    this.submitLabel = 'Save code',
    this.submitIcon = Icons.save_outlined,
    this.submitting = false,
    this.startOpen = false,
  });

  final ValueChanged<CodeSubmission> onChanged;
  final CodeSubmission initial;
  final bool enabled;

  /// What the collapsed button says. The challenge sheet calls it
  /// "Attach your solution", the answer composer just "Add code".
  final String label;

  /// Draws a primary submit button under the editor when set.
  ///
  /// The answer composer leaves this null — it has its own send button, and a
  /// second one would be ambiguous. The challenge screen sets it, because
  /// otherwise the editor has no button of its own at all and the only thing
  /// that saves the code is "Claim", which refuses unless Codeforces already
  /// shows an accepted verdict.
  final Future<void> Function(CodeSubmission)? onSubmit;

  /// What that button says. It must describe what it *does*: this one writes
  /// the code to the attempt and nothing else, so on the challenge screen it
  /// says "Save", not "Submit". It said "Submit code" for a while, next to a
  /// second button that submitted to Codeforces for real, and the two were
  /// indistinguishable.
  final String submitLabel;
  final IconData submitIcon;
  final bool submitting;

  /// Draws the editor already expanded.
  ///
  /// The answer composer stays collapsed — most answers are prose, and an open
  /// code pane would push the text field off a phone screen. The challenge
  /// screen sets this, because there the code *is* the point and a collapsed
  /// text link reads as "there is no submit button".
  final bool startOpen;

  @override
  State<CodeComposer> createState() => _CodeComposerState();
}

class _CodeComposerState extends State<CodeComposer> {
  late final TextEditingController _code;
  late String _language;
  String? _attachmentUrl;
  String? _attachmentName;

  bool _open = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: widget.initial.codeBody ?? '');
    _language = widget.initial.codeLanguage ?? 'text';
    _attachmentUrl = widget.initial.attachmentUrl;
    _attachmentName = widget.initial.attachmentName;
    // Reopened already-populated, so editing an answer that had code does not
    // look like the code was lost.
    _open = widget.startOpen || !widget.initial.isEmpty;
    _code.addListener(_emit);
  }

  @override
  void dispose() {
    _code.removeListener(_emit);
    _code.dispose();
    super.dispose();
  }

  void _emit() {
    // Always sent, even empty: clearing the editor has to clear the column.
    widget.onChanged(_current);
    // The character counter and the submit button's enabled state both read
    // the controller, so typing has to rebuild this widget — without it the
    // counter froze at 0 and the submit button never came out of disabled.
    if (mounted) setState(() {});
  }

  /// Tab moves focus in a Flutter form rather than indenting, so indenting is
  /// a button. Two spaces at the caret, and the caret follows them.
  void _indent() {
    final selection = _code.selection;
    final at = selection.isValid ? selection.start : _code.text.length;
    final text = _code.text;
    _code.value = TextEditingValue(
      text: '${text.substring(0, at)}  ${text.substring(selection.isValid ? selection.end : at)}',
      selection: TextSelection.collapsed(offset: at + 2),
    );
  }

  Future<void> _attach() async {
    setState(() => _uploading = true);
    try {
      final file = await AttachmentService.instance.pickAndUpload();
      if (file == null) return;
      if (!mounted) return;
      setState(() {
        _attachmentUrl = file.url;
        _attachmentName = file.name;
      });
      _emit();
      if (mounted) {
        showAppSnack(context, 'Attached ${file.name}', tone: SnackTone.success);
      }
    } on AttachmentException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachmentUrl = null;
      _attachmentName = null;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: widget.enabled ? () => setState(() => _open = true) : null,
          icon: const Icon(Icons.code, size: 18),
          label: Text(widget.label),
        ),
      );
    }

    final length = _code.text.length;
    final overLimit = length > maxCodeChars;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: overLimit ? AppColors.danger : AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrap, not Row: on a 320px screen the picker and the two actions do
          // not fit on one line and must fall onto a second.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _languagePicker(),
              TextButton.icon(
                onPressed: widget.enabled ? _indent : null,
                icon: const Icon(Icons.keyboard_tab, size: 16),
                label: const Text('Indent'),
              ),
              TextButton.icon(
                onPressed: widget.enabled && !_uploading ? _attach : null,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file, size: 16),
                label: Text(_uploading ? 'Uploading…' : 'Attach file'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            enabled: widget.enabled,
            minLines: 6,
            maxLines: 20,
            keyboardType: TextInputType.multiline,
            // A phone keyboard that autocapitalises and autocorrects turns
            // valid code into invalid code as you type it.
            textCapitalization: TextCapitalization.none,
            autocorrect: false,
            enableSuggestions: false,
            style: codeTextStyle,
            decoration: InputDecoration(
              hintText: 'Paste or write your solution…',
              hintStyle: codeTextStyle.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.subtleFill,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                overLimit
                    ? '$length / $maxCodeChars characters — too long'
                    : '$length ${length == 1 ? 'character' : 'characters'}',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      overLimit ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              if (_attachmentUrl != null && _attachmentUrl!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AttachmentChip(
                          url: _attachmentUrl!, name: _attachmentName),
                    ),
                    IconButton(
                      tooltip: 'Remove attachment',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.enabled ? _removeAttachment : null,
                      icon: const Icon(Icons.close,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
          if (widget.onSubmit != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.enabled &&
                        !widget.submitting &&
                        !overLimit &&
                        !_current.isEmpty
                    ? () => widget.onSubmit!(_current)
                    : null,
                icon: widget.submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(widget.submitIcon, size: 18),
                label: Text(widget.submitting ? 'Saving…' : widget.submitLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// What the editor currently holds, in the shape the API takes.
  CodeSubmission get _current => CodeSubmission(
        codeBody: _code.text,
        codeLanguage: _code.text.trim().isEmpty ? '' : _language,
        attachmentUrl: _attachmentUrl ?? '',
        attachmentName: _attachmentName ?? '',
      );

  Widget _languagePicker() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _language,
        isDense: true,
        borderRadius: BorderRadius.circular(8),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        onChanged: widget.enabled
            ? (value) {
                if (value == null) return;
                setState(() => _language = value);
                _emit();
              }
            : null,
        items: [
          for (final entry in codeLanguages.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
      ),
    );
  }
}
