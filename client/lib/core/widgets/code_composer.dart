import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/code_submission.dart';
import '../../services/common/attachment_service.dart';
import '../app_colors.dart';
import '../code_format.dart';
import '../code_syntax.dart';
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
  /// Colours the code as it is typed. See `core/code_syntax.dart` — it is a
  /// plain [TextEditingController] with `buildTextSpan` overridden, so
  /// selection, the caret and the soft keyboard all still behave.
  late final CodeHighlightController _code;
  late String _language;
  String? _attachmentUrl;
  String? _attachmentName;

  bool _open = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _language = widget.initial.codeLanguage ?? 'text';
    _code = CodeHighlightController(
      text: widget.initial.codeBody ?? '',
      language: _language,
    );
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

  /// Indents (or with [outdent], unindents) whole lines by one level of
  /// whatever this language uses — four spaces for C++, two for Dart, a tab
  /// for Go.
  ///
  /// This used to insert two spaces at the caret and call that indenting,
  /// which is why the button looked broken: with a block of pasted code
  /// selected it moved nothing, it just typed a space twice.
  void _shiftIndent({bool outdent = false}) {
    final unit = indentUnitFor(_language);
    final text = _code.text;
    final selection = _code.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : start;

    // Nothing selected and indenting: behave like Tab in an editor and push
    // the caret in where it stands.
    if (!outdent && start == end) {
      _code.value = TextEditingValue(
        text: text.substring(0, start) + unit + text.substring(start),
        selection: TextSelection.collapsed(offset: start + unit.length),
      );
      return;
    }

    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd < 0) lineEnd = text.length;

    final shifted = [
      for (final line in text.substring(lineStart, lineEnd).split('\n'))
        if (line.trim().isEmpty)
          line
        else if (outdent)
          _dropOneLevel(line, unit)
        else
          unit + line,
    ].join('\n');

    _code.value = TextEditingValue(
      text: text.substring(0, lineStart) + shifted + text.substring(lineEnd),
      // The whole block stays selected, so the button can be pressed twice.
      selection: TextSelection(
        baseOffset: lineStart,
        extentOffset: lineStart + shifted.length,
      ),
    );
  }

  String _dropOneLevel(String line, String unit) {
    if (line.startsWith(unit)) return line.substring(unit.length);
    if (line.startsWith('\t')) return line.substring(1);
    var removed = 0;
    while (removed < unit.length &&
        removed < line.length &&
        line[removed] == ' ') {
      removed++;
    }
    return line.substring(removed);
  }

  /// Re-indents the whole buffer the way this language's own formatter would.
  ///
  /// Honest about its limits, both in the code (see `core/code_format.dart`)
  /// and in what it says afterwards: it fixes indentation, it does not reflow
  /// the code, and it says so rather than claiming to have "formatted" it.
  void _format() {
    if (!canFormatCode(_language)) {
      showAppSnack(
        context,
        'Pick the language above first — plain text has no indent rules to '
        'apply.',
      );
      return;
    }

    final result = formatCode(_code.text, _language);
    if (!result.changed) {
      showAppSnack(context,
          'Already indented like ${languageLabel(_language)}.');
      return;
    }

    // Keep the caret on the line it was on. The line survives re-indenting
    // even though its offset does not.
    final caretLine = '\n'
        .allMatches(_code.text.substring(0, _code.selection.baseOffset.clamp(0, _code.text.length)))
        .length;
    final lines = result.code.split('\n');
    var offset = 0;
    for (var i = 0; i < caretLine && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    offset = (offset + (caretLine < lines.length ? lines[caretLine].length : 0))
        .clamp(0, result.code.length);

    _code.value = TextEditingValue(
      text: result.code,
      selection: TextSelection.collapsed(offset: offset),
    );
    showAppSnack(
      context,
      'Indented as ${languageLabel(_language)} — ${result.styleNote}.',
      tone: SnackTone.success,
    );
  }

  /// Hardware Tab indents instead of moving focus, which is what anyone who
  /// has used an editor expects. Shift-Tab goes back out. Phones have no Tab
  /// key, which is why the buttons above the field exist too.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    if (!widget.enabled) return KeyEventResult.ignored;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    _shiftIndent(outdent: shift);
    return KeyEventResult.handled;
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
              Tooltip(
                message: canFormatCode(_language)
                    ? 'Re-indent the whole block the way '
                        '${languageLabel(_language)} is normally written'
                    : 'Pick a language to indent it',
                child: TextButton.icon(
                  onPressed: widget.enabled && _code.text.trim().isNotEmpty
                      ? _format
                      : null,
                  icon: const Icon(Icons.format_indent_increase, size: 16),
                  label: const Text('Fix indent'),
                ),
              ),
              Tooltip(
                message: 'Indent the selected lines (or press Tab)',
                child: TextButton.icon(
                  onPressed: widget.enabled ? _shiftIndent : null,
                  icon: const Icon(Icons.keyboard_tab, size: 16),
                  label: const Text('Indent'),
                ),
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
          Focus(
            // Sits between the field and the app's own Tab traversal, so the
            // key reaches us before the focus system eats it.
            onKeyEvent: _onKey,
            child: TextField(
              controller: _code,
              enabled: widget.enabled,
              minLines: 6,
              maxLines: 20,
              keyboardType: TextInputType.multiline,
              // Runs on every edit, including soft-keyboard ones, which a key
              // handler never sees: pressing return carries the current line's
              // indentation down with it.
              inputFormatters: [_AutoIndent(() => _language)],
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
                // Repaints the code in the new language's colours.
                _code.language = value;
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

/// Carries the current line's indentation onto the next one when return is
/// pressed, and adds a level after a line that opened a block.
///
/// A [TextInputFormatter] rather than a key handler because a phone's soft
/// keyboard does not send key events — the newline arrives as an edit, and
/// this is the only place both a hardware return and a thumbed one show up.
class _AutoIndent extends TextInputFormatter {
  _AutoIndent(this.language);

  /// Read on each edit, not captured: the picker can change under us.
  final String Function() language;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Exactly one character appeared and it was a newline. Anything else — a
    // paste, an undo, an IME replacement — is left alone, because guessing at
    // those is how an editor starts eating people's code.
    if (newValue.text.length != oldValue.text.length + 1) return newValue;
    if (!newValue.selection.isCollapsed) return newValue;

    final at = newValue.selection.baseOffset;
    if (at < 1 || at > newValue.text.length) return newValue;
    if (newValue.text[at - 1] != '\n') return newValue;

    final indent =
        indentAfterNewline(newValue.text.substring(0, at - 1), language());
    if (indent.isEmpty) return newValue;

    return TextEditingValue(
      text: newValue.text.substring(0, at) + indent + newValue.text.substring(at),
      selection: TextSelection.collapsed(offset: at + indent.length),
    );
  }
}
