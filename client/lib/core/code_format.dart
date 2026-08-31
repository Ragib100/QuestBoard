/// Re-indents pasted code the way each language's own tooling would.
///
/// The editor's old "Indent" button inserted two spaces at the caret, which is
/// not indenting — it is typing a space twice. This is the real thing: it
/// throws away every line's leading whitespace and rebuilds it from the
/// structure of the code, using the indent unit that language's community
/// actually uses (`gofmt` tabs, PSR-12's four spaces for PHP, two for Dart and
/// JavaScript, PEP 8's four for Python).
///
/// What it deliberately does **not** do is reflow anything. A real formatter —
/// clang-format, Black, gofmt — parses the language and rewrites line breaks,
/// spacing and wrapping. We have no parser and no compiler on a phone, and a
/// half-parser that moves someone's code around would eventually mangle a
/// solution they are about to submit. Leading whitespace is the part that can
/// be rebuilt from brackets alone, it is the part that is actually broken in
/// pasted code, and getting it wrong is visible and harmless.
///
/// Strings and comments come from the lexer in `code_syntax.dart`, so a brace
/// inside a string never opens a block and the inside of a multi-line string
/// is left byte-for-byte alone.
library;

import 'code_syntax.dart';

class CodeFormatResult {
  const CodeFormatResult({
    required this.code,
    required this.changed,
    required this.styleNote,
  });

  final String code;

  /// False when the code was already indented this way — the caller says
  /// "already formatted" instead of claiming it did something.
  final bool changed;

  /// How this language indents, for the confirmation message: "4-space
  /// indent", "tabs, like gofmt".
  final String styleNote;
}

/// One indent level per language, following the convention that language's own
/// formatter enforces.
const _indentUnits = <String, String>{
  'c': '    ',
  'cpp': '    ',
  'csharp': '    ',
  'java': '    ',
  'python': '    ',
  'javascript': '  ',
  'typescript': '  ',
  'dart': '  ',
  'go': '\t',
  'rust': '    ',
  'kotlin': '    ',
  'swift': '    ',
  'php': '    ',
  'ruby': '  ',
  'sql': '  ',
  'bash': '  ',
};

const _styleNotes = <String, String>{
  'go': 'tabs, the way gofmt writes them',
  'python': '4-space indent, PEP 8 style',
  'php': '4-space indent, PSR-12 style',
};

/// False for `text`, which has no structure to read.
bool canFormatCode(String? language) => _indentUnits.containsKey(language);

String indentUnitFor(String? language) => _indentUnits[language] ?? '  ';

String _styleNote(String language) =>
    _styleNotes[language] ??
    (indentUnitFor(language) == '\t'
        ? 'tab indent'
        : '${indentUnitFor(language).length}-space indent');

/// Languages whose `if (…)` / `else` can carry a single unbraced statement on
/// the next line, which is then indented one level even though no brace opened.
const _hangingLanguages = {
  'c',
  'cpp',
  'csharp',
  'java',
  'javascript',
  'typescript',
  'dart',
  'php',
  'swift',
  'go',
  'rust',
  'kotlin',
};

/// Languages with C-style `switch` blocks, where `case` sits one level in and
/// its statements one level deeper again.
const _switchLanguages = {
  'c',
  'cpp',
  'csharp',
  'java',
  'javascript',
  'typescript',
  'dart',
  'php',
  'swift',
  'go',
};

CodeFormatResult formatCode(String source, String? language) {
  final unit = _indentUnits[language];
  if (unit == null || source.trim().isEmpty) {
    return CodeFormatResult(
      code: source,
      changed: false,
      styleNote: _styleNote(language ?? 'text'),
    );
  }

  final normalised = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final mask = maskCode(normalised, language);
  final lines = normalised.split('\n');
  final maskedLines = mask.masked.split('\n');

  final formatted = switch (language) {
    'python' => _reindentOffside(lines, maskedLines, mask, unit),
    'ruby' || 'bash' =>
      _reindentKeyword(lines, maskedLines, mask, unit, language!),
    _ => _reindentBrackets(lines, maskedLines, mask, unit, language!),
  };

  // Trailing blank lines are noise in a submission box; a trailing newline is
  // not, so the join keeps the shape of the code itself.
  while (formatted.isNotEmpty && formatted.last.isEmpty) {
    formatted.removeLast();
  }

  final code = formatted.join('\n');
  return CodeFormatResult(
    code: code,
    changed: code != source,
    styleNote: _styleNote(language!),
  );
}

// ------------------------------------------------------------- bracket family

/// One open bracket, and the indents everything related to it gets.
class _Block {
  const _Block({
    required this.body,
    required this.label,
    required this.closer,
    required this.isSwitch,
  });

  /// Indent level for ordinary statements inside the block.
  final int body;

  /// Indent level for a `case:` / `default:` label. Only differs from [body]
  /// inside a switch.
  final int label;

  /// Indent level for the line that closes the bracket.
  final int closer;

  final bool isSwitch;
}

List<String> _reindentBrackets(
  List<String> lines,
  List<String> maskedLines,
  MaskedCode mask,
  String unit,
  String language,
) {
  final stack = <_Block>[];
  final out = <String>[];
  var hanging = 0;

  for (var index = 0; index < lines.length; index++) {
    // Inside a multi-line string or comment the leading whitespace is content,
    // not indentation. Copied through untouched.
    if (mask.continuedLines.contains(index)) {
      out.add(lines[index]);
      continue;
    }

    final raw = lines[index].trimRight();
    final body = raw.trim();
    if (body.isEmpty) {
      out.add('');
      continue;
    }

    final masked = maskedLines[index];
    final maskedTrim = masked.trim();

    // A preprocessor directive belongs in column 0 whatever the nesting is,
    // and `<?php` is not code inside a block either.
    if (_isFlushLeft(maskedTrim, language)) {
      out.add(body);
      hanging = 0;
      continue;
    }

    var leadingClosers = 0;
    while (leadingClosers < maskedTrim.length &&
        '}])'.contains(maskedTrim[leadingClosers])) {
      leadingClosers++;
    }

    int indent;
    var alreadyPopped = 0;
    if (leadingClosers > 0) {
      // The innermost bracket this line closes decides where the line sits.
      _Block? first;
      for (var k = 0; k < leadingClosers && stack.isNotEmpty; k++) {
        final block = stack.removeLast();
        first ??= block;
        alreadyPopped++;
      }
      indent = first?.closer ?? 0;
      hanging = 0;
    } else {
      final top = stack.isEmpty ? null : stack.last;
      if (top == null) {
        indent = 0;
      } else if (top.isSwitch && _isCaseLabel(maskedTrim, language)) {
        indent = top.label;
      } else {
        indent = top.body;
      }
      // A brace on its own line belongs to the statement above it (Allman
      // style), not one level in from it.
      if (!body.startsWith('{')) indent += hanging;
      hanging = 0;
    }

    out.add(_indent(unit, indent) + body);

    // Now walk the line's own brackets so the next line knows where it is.
    var skip = alreadyPopped;
    for (var k = 0; k < masked.length; k++) {
      final char = masked[k];
      if (char == '{' || char == '(' || char == '[') {
        final isSwitch =
            char == '{' && _opensSwitch(masked.substring(0, k), language);
        stack.add(_Block(
          body: indent + (isSwitch ? 2 : 1),
          label: indent + 1,
          closer: indent,
          isSwitch: isSwitch,
        ));
      } else if (char == '}' || char == ')' || char == ']') {
        if (skip > 0) {
          skip--;
        } else if (stack.isNotEmpty) {
          stack.removeLast();
        }
      }
    }

    if (_opensHangingStatement(maskedTrim, language)) hanging = 1;
  }

  return out;
}

bool _isFlushLeft(String maskedTrim, String language) {
  if (language == 'php') {
    return maskedTrim.startsWith('<?') || maskedTrim.startsWith('?>');
  }
  if (language == 'c' || language == 'cpp' || language == 'csharp') {
    return maskedTrim.startsWith('#');
  }
  return false;
}

final _caseLabel = RegExp(r'^(case\b|default\s*:)');

bool _isCaseLabel(String maskedTrim, String language) =>
    _switchLanguages.contains(language) && _caseLabel.hasMatch(maskedTrim);

final _switchWord = RegExp(r'\bswitch\b');

bool _opensSwitch(String beforeBrace, String language) =>
    _switchLanguages.contains(language) && _switchWord.hasMatch(beforeBrace);

final _hangingHead =
    RegExp(r'^(if|for|foreach|while|elseif|else\s+if)\b');

/// True when the *next* line is the single statement belonging to this one:
/// `if (x)` with no brace, a bare `else`, a bare `do`.
bool _opensHangingStatement(String maskedTrim, String language) {
  if (!_hangingLanguages.contains(language)) return false;
  if (maskedTrim.isEmpty) return false;
  final last = maskedTrim[maskedTrim.length - 1];
  if (last == '{' || last == ';' || last == ',' || last == ':') return false;
  if (maskedTrim == 'do' || maskedTrim == 'else' || maskedTrim == 'try') {
    return true;
  }
  if (last != ')') return false;
  if (!_hangingHead.hasMatch(maskedTrim)) return false;
  // A condition split over several lines ends with `)` too — only a balanced
  // one is a complete header.
  var depth = 0;
  for (var i = 0; i < maskedTrim.length; i++) {
    if (maskedTrim[i] == '(') depth++;
    if (maskedTrim[i] == ')') depth--;
  }
  return depth == 0;
}

// -------------------------------------------------------------- offside rule

/// Python. Indentation *is* the syntax here, so this cannot rebuild the
/// structure from brackets — it reads the structure the author already wrote
/// and re-spells it in even four-space steps. Mixed tabs and spaces, three-space
/// indents and a stray extra space all come out as PEP 8; a genuinely wrong
/// indent stays wrong, because guessing at it would change what the code does.
List<String> _reindentOffside(
  List<String> lines,
  List<String> maskedLines,
  MaskedCode mask,
  String unit,
) {
  final levels = <int>[0];
  final out = <String>[];
  var brackets = 0;

  for (var index = 0; index < lines.length; index++) {
    if (mask.continuedLines.contains(index)) {
      out.add(lines[index]);
      brackets = _bracketDelta(maskedLines[index], brackets);
      continue;
    }

    final body = lines[index].trim();
    if (body.isEmpty) {
      out.add('');
      continue;
    }

    if (brackets > 0) {
      // Inside an open bracket Python does not care, and PEP 8 asks for one
      // extra level — except for the line that closes it.
      final closing = ')]}'.contains(body[0]);
      out.add(_indent(unit, levels.length - 1 + (closing ? 0 : 1)) + body);
    } else {
      final width = _leadingWidth(lines[index]);
      if (width > levels.last) {
        levels.add(width);
      } else {
        while (levels.length > 1 && width < levels.last) {
          levels.removeLast();
        }
        // A dedent that lands between two known levels is not valid Python,
        // but it is code someone is still writing: give it its own level
        // rather than dropping it into the wrong block.
        if (width > levels.last) levels.add(width);
      }
      out.add(_indent(unit, levels.length - 1) + body);
    }

    brackets = _bracketDelta(maskedLines[index], brackets);
  }

  return out;
}

int _bracketDelta(String masked, int depth) {
  var result = depth;
  for (var i = 0; i < masked.length; i++) {
    final char = masked[i];
    if (char == '(' || char == '[' || char == '{') result++;
    if (char == ')' || char == ']' || char == '}') result--;
  }
  return result < 0 ? 0 : result;
}

/// Tabs count as four columns, which is what every editor Python users reach
/// for does.
int _leadingWidth(String line) {
  var width = 0;
  for (var i = 0; i < line.length; i++) {
    if (line[i] == ' ') {
      width++;
    } else if (line[i] == '\t') {
      width += 4;
    } else {
      break;
    }
  }
  return width;
}

// ------------------------------------------------------------ keyword family

/// Ruby and Bash, where blocks open and close with words rather than braces.
List<String> _reindentKeyword(
  List<String> lines,
  List<String> maskedLines,
  MaskedCode mask,
  String unit,
  String language,
) {
  final out = <String>[];
  var depth = 0;

  for (var index = 0; index < lines.length; index++) {
    if (mask.continuedLines.contains(index)) {
      out.add(lines[index]);
      continue;
    }

    final body = lines[index].trim();
    if (body.isEmpty) {
      out.add('');
      continue;
    }

    final masked = maskedLines[index].trim();
    final words = masked
        .split(RegExp(r'[^A-Za-z_?!]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final first = words.isEmpty ? '' : words.first;

    final closers =
        language == 'ruby' ? _rubyClosers : _bashClosers;
    final reopens = language == 'ruby' ? _rubyReopens : _bashReopens;

    var indent = depth;
    if (closers.contains(first) || masked.startsWith('}')) indent -= 1;
    if (indent < 0) indent = 0;

    out.add(_indent(unit, indent) + body);

    depth = indent;
    if (reopens.contains(first)) depth += 1;
    depth += language == 'ruby'
        ? _rubyDelta(masked, words)
        : _bashDelta(masked, words);
    if (depth < 0) depth = 0;
  }

  return out;
}

const _rubyClosers = {'end', 'else', 'elsif', 'when', 'rescue', 'ensure'};
const _rubyReopens = {'else', 'elsif', 'when', 'rescue', 'ensure'};
const _rubyOpeners = {
  'def',
  'class',
  'module',
  'begin',
  'case',
  'if',
  'unless',
  'while',
  'until',
  'for',
};

final _rubyBlockDo = RegExp(r'\bdo(\s*\|[^|]*\|)?$');

int _rubyDelta(String masked, List<String> words) {
  if (words.isEmpty) return 0;
  var delta = 0;
  if (_rubyOpeners.contains(words.first)) delta++;
  if (_rubyBlockDo.hasMatch(masked)) delta++;
  // Every `end` on the line closes something; a leading one was already
  // handled by the dedent above.
  var ends = words.where((w) => w == 'end').length;
  if (words.first == 'end') ends--;
  return delta - ends;
}

const _bashClosers = {'fi', 'done', 'esac', 'else', 'elif'};
const _bashReopens = {'else', 'elif'};

final _bashOpensLine = RegExp(r'(\bthen|\bdo|\bin|\{)$');

int _bashDelta(String masked, List<String> words) {
  var delta = 0;
  if (_bashOpensLine.hasMatch(masked)) delta++;
  var closes = words.where(_bashClosers.contains).length;
  if (words.isNotEmpty && _bashClosers.contains(words.first)) closes--;
  closes += RegExp(r'\}').allMatches(masked).length -
      (masked.startsWith('}') ? 1 : 0);
  return delta - closes;
}

String _indent(String unit, int level) => level <= 0 ? '' : unit * level;

/// The whitespace a fresh line should open with, given everything typed before
/// the newline.
///
/// This is what makes the editor usable on a phone: there is no Tab key on a
/// soft keyboard, so without it every line of a nested loop has to be spaced
/// in by hand. It carries the current line's indentation down and adds one
/// level when that line opened something — a brace, a bracket, a Python
/// colon, a bash `then`, an unbraced `if`.
String indentAfterNewline(String before, String? language) {
  final unit = _indentUnits[language] ?? '';
  final mask = maskCode(before, language);
  final maskedLines = mask.masked.split('\n');
  final rawLines = before.split('\n');
  final index = rawLines.length - 1;

  final raw = rawLines[index];
  var leading = '';
  for (var i = 0; i < raw.length; i++) {
    if (raw[i] == ' ' || raw[i] == '\t') {
      leading += raw[i];
    } else {
      break;
    }
  }

  // Inside a multi-line string the "indentation" is content: match it and add
  // nothing.
  if (mask.continuedLines.contains(index) || unit.isEmpty) return leading;

  final masked = maskedLines[index].trimRight();
  final trimmed = masked.trim();
  if (trimmed.isEmpty) return leading;

  final last = masked[masked.length - 1];
  var opens = last == '{' || last == '(' || last == '[';
  switch (language) {
    case 'python':
      opens = opens || last == ':';
    case 'ruby':
      final first = trimmed.split(RegExp(r'\s+')).first;
      opens = opens || _rubyOpeners.contains(first) || _rubyBlockDo.hasMatch(trimmed);
    case 'bash':
      opens = opens || _bashOpensLine.hasMatch(trimmed);
  }
  opens = opens || _opensHangingStatement(trimmed, language ?? '');

  return opens ? leading + unit : leading;
}
