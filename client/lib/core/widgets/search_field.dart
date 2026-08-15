import 'dart:async';

import 'package:flutter/material.dart';

/// A search box that fires once the user stops typing.
///
/// Owns the controller, the debounce timer and the clear button, because three
/// screens had grown their own copy of all three and they had already drifted —
/// one trimmed the term before comparing it and the others did not, so a
/// trailing space re-ran the same query.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.value = '',
    this.debounce = const Duration(milliseconds: 350),
    this.bare = false,
  });

  final String hintText;

  /// Called with the trimmed term, at most once per pause in typing, and
  /// immediately when the field is cleared.
  final ValueChanged<String> onChanged;

  /// A term pushed in from outside — the dashboard's own search box hands one
  /// to the Browse tab. Changing it updates the field without re-notifying.
  final String value;

  final Duration debounce;

  /// Drops the border for a field that already sits inside its own container —
  /// the desktop shell draws one as a rounded pill in the top bar.
  final bool bare;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  Timer? _timer;
  String _last = '';

  @override
  void initState() {
    super.initState();
    _last = widget.value.trim();
  }

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && widget.value.trim() != _last) {
      _last = widget.value.trim();
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule(String raw) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => _emit(raw));
  }

  void _emit(String raw) {
    final term = raw.trim();
    // Guarding on the trimmed term is what stops a trailing space, or a
    // keystroke that is undone before the timer fires, re-running the query.
    if (!mounted || term == _last) return;
    setState(() => _last = term);
    widget.onChanged(term);
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    if (_last.isEmpty) return;
    setState(() => _last = '');
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _schedule,
      onSubmitted: _emit,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        border: widget.bare ? InputBorder.none : null,
        enabledBorder: widget.bare ? InputBorder.none : null,
        focusedBorder: widget.bare ? InputBorder.none : null,
        contentPadding:
            widget.bare ? const EdgeInsets.symmetric(vertical: 8) : null,
        suffixIcon: _last.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear',
                onPressed: _clear,
              ),
      ),
    );
  }
}
