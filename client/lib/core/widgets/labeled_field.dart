import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Live feedback on a minimum-length rule, shown under the field it governs.
///
/// The quest composer and the answer composer both enforce a minimum, and both
/// used to keep it secret until the submit button bounced the user with a
/// snackbar. Counts down while short, then confirms and stops counting — a
/// running "1,204 characters" is noise once the rule is satisfied.
class MinLengthHint extends StatelessWidget {
  const MinLengthHint({
    super.key,
    required this.length,
    required this.minimum,
  });

  /// Length of the *trimmed* text, matching what the validator checks.
  final int length;
  final int minimum;

  @override
  Widget build(BuildContext context) {
    if (length >= minimum) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: AppColors.successDark),
            SizedBox(width: 4),
            Text('Looks good',
                style: TextStyle(color: AppColors.successDark, fontSize: 12)),
          ],
        ),
      );
    }

    final remaining = minimum - length;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '$remaining more character${remaining == 1 ? '' : 's'} needed',
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}

/// A bold label above a text field — the form row used across auth, profile
/// and quest screens. Replaces the per-screen `_buildLabel` / `_buildField`
/// helpers that used to be copy-pasted into every form.
///
/// When [obscureText] is set the field starts hidden and gains a reveal toggle,
/// so users can check what they typed before submitting.
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// Optional grey explainer between the label and the field.
  final String? helper;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Lets the platform's password manager and autofill service recognise the
  /// field. Wrap the surrounding form in an [AutofillGroup] or Android will
  /// never offer to save the credentials.
  final Iterable<String>? autofillHints;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late bool _hidden = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helper!,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          // Autocorrect on an email or a username produces gibberish the user
          // does not notice until the sign-in fails.
          autocorrect: widget.autofillHints == null,
          enableSuggestions: widget.autofillHints == null,
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
