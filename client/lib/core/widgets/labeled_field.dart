import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';

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
    this.maxCharacters,
    this.errorText,
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

  /// A hard ceiling on what can be typed, enforced silently.
  ///
  /// Deliberately not `TextField.maxLength`, which draws a "0/50000" counter.
  /// The limit exists to bound the row, not to set a target — telling someone
  /// they have 49,987 characters left is noise at best and a dare at worst.
  final int? maxCharacters;

  /// Shown in red under the field. Null when there is nothing wrong.
  final String? errorText;

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
          inputFormatters: widget.maxCharacters == null
              ? null
              : [LengthLimitingTextInputFormatter(widget.maxCharacters)],
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.errorText,
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
