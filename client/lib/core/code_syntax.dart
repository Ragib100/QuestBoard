/// Syntax highlighting for every code surface in the app.
///
/// Hand-rolled rather than pulled from a package: `highlight` and friends ship
/// a hundred grammars and a set of IDE themes we would have to override
/// anyway, and the seventeen languages the picker offers (`codeLanguages` in
/// `core/widgets/code_view.dart`) all fall into three lexical families —
/// C-like, hash-comment scripting, and SQL. The whole lexer below is smaller
/// than the theme file alone would be, and it is the same tokens the
/// re-indenter in `core/code_format.dart` needs to know which braces are real
/// and which ones are inside a string.
///
/// The scanner is deliberately forgiving. Half the code pasted into the app is
/// a fragment that does not compile yet, so an unterminated string ends at the
/// newline and an unterminated block comment ends at the end of the buffer —
/// neither one is allowed to paint the rest of the file green.
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The kinds the highlighter can tell apart. Everything else renders in the
/// base style, which is most of the file.
enum CodeTokenKind { keyword, type, string, number, comment, meta }

class CodeToken {
  const CodeToken(this.start, this.end, this.kind);

  final int start;
  final int end;
  final CodeTokenKind kind;
}

/// The colour for one token kind, layered onto the caller's base style so the
/// font, size and line height still come from `codeTextStyle`.
TextStyle codeTokenStyle(CodeTokenKind? kind, TextStyle base) {
  switch (kind) {
    case CodeTokenKind.keyword:
      return base.copyWith(
          color: AppColors.codeKeyword, fontWeight: FontWeight.w600);
    case CodeTokenKind.type:
      return base.copyWith(color: AppColors.codeType);
    case CodeTokenKind.string:
      return base.copyWith(color: AppColors.codeString);
    case CodeTokenKind.number:
      return base.copyWith(color: AppColors.codeNumber);
    case CodeTokenKind.comment:
      return base.copyWith(
          color: AppColors.codeComment, fontStyle: FontStyle.italic);
    case CodeTokenKind.meta:
      return base.copyWith(color: AppColors.codeMeta);
    case null:
      return base;
  }
}

// ---------------------------------------------------------------- grammars

class _Grammar {
  _Grammar({
    required String keywords,
    String types = '',
    this.lineComments = const ['//'],
    this.blockComment = const ('/*', '*/'),
    this.multilineQuotes = const [],
    this.caseInsensitive = false,
    this.hashMeta = false,
    this.atMeta = false,
    this.phpTags = false,
  })  : keywords = _words(keywords, caseInsensitive),
        types = _words(types, caseInsensitive);

  static Set<String> _words(String source, bool lower) => source
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => lower ? w.toLowerCase() : w)
      .toSet();

  final Set<String> keywords;
  final Set<String> types;
  final List<String> lineComments;

  /// Null for languages without one (Python, Ruby, Bash).
  final (String, String)? blockComment;

  /// Quote characters whose literal ends at the newline if it is not closed.
  /// The same pair in every language the picker offers, so it is not a knob.
  static const quotes = ['"', "'"];

  /// Quote runs that are allowed to span lines: Python's triple quotes, a
  /// JavaScript template literal.
  final List<String> multilineQuotes;

  /// SQL only. `SELECT` and `select` are the same word.
  final bool caseInsensitive;

  /// `#include`, `#define` — a preprocessor line, not a comment.
  final bool hashMeta;

  /// `@Override`, `@override`, `@Entity`.
  final bool atMeta;

  /// `<?php` and `?>`.
  final bool phpTags;
}

const _cKeywords =
    'auto break case const continue default do else enum extern for goto if '
    'inline register restrict return short sizeof static struct switch typedef '
    'union volatile while';
const _cTypes =
    'bool char double float int long signed unsigned void size_t ssize_t '
    'int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t FILE '
    'NULL true false printf scanf malloc free memset memcpy strlen';

/// Built lazily, not `const`: each grammar turns its space-separated word
/// lists into sets in its constructor.
final Map<String, _Grammar> _grammars = {
  'c': _Grammar(keywords: _cKeywords, types: _cTypes, hashMeta: true),
  'cpp': _Grammar(
    keywords: '$_cKeywords class namespace template typename public private '
        'protected virtual override final new delete this try catch throw '
        'using friend operator explicit constexpr consteval decltype mutable '
        'static_cast dynamic_cast reinterpret_cast const_cast noexcept concept '
        'requires co_await co_return co_yield export import',
    types: '$_cTypes std string wstring vector map set pair queue deque stack '
        'priority_queue unordered_map unordered_set array tuple nullptr '
        'cout cin cerr endl auto ostream istream shared_ptr unique_ptr',
    hashMeta: true,
  ),
  'csharp': _Grammar(
    keywords: 'abstract as base break case catch checked class const continue '
        'default delegate do else enum event explicit extern finally fixed for '
        'foreach goto if implicit in interface internal is lock namespace new '
        'operator out override params private protected public readonly record '
        'ref return sealed sizeof stackalloc static struct switch this throw '
        'try typeof unchecked unsafe using var virtual volatile while async '
        'await yield get set',
    types: 'bool byte char decimal double float int long object sbyte short '
        'string uint ulong ushort void dynamic null true false Console List '
        'Dictionary Task IEnumerable',
    hashMeta: true,
  ),
  'java': _Grammar(
    keywords: 'abstract assert break case catch class const continue default '
        'do else enum extends final finally for goto if implements import '
        'instanceof interface native new package permits private protected '
        'public record return sealed static strictfp super switch synchronized '
        'this throw throws transient try var while yield',
    types: 'boolean byte char double float int long short void String Integer '
        'Double Boolean Long Object List Map Set ArrayList HashMap System '
        'Math Scanner true false null',
    atMeta: true,
  ),
  'python': _Grammar(
    keywords: 'and as assert async await break class continue def del elif '
        'else except finally for from global if import in is lambda match '
        'nonlocal not or pass raise return try while with yield case',
    types: 'True False None self cls int str float bool list dict set tuple '
        'len range print enumerate zip map filter sum min max abs sorted open '
        'input type isinstance super object Exception',
    lineComments: ['#'],
    blockComment: null,
    multilineQuotes: ["'''", '"""'],
    atMeta: true,
  ),
  'javascript': _Grammar(
    keywords: 'async await break case catch class const continue debugger '
        'default delete do else export extends finally for from function get '
        'if import in instanceof let new of return set static super switch '
        'this throw try typeof var void while with yield',
    types: 'true false null undefined NaN Infinity console document window '
        'Math JSON Promise Array Object String Number Boolean Map Set Symbol '
        'require module exports',
    multilineQuotes: ['`'],
  ),
  'typescript': _Grammar(
    keywords: 'abstract as asserts async await break case catch class const '
        'continue declare default delete do else enum export extends finally '
        'for from function get if implements import in infer instanceof '
        'interface is keyof let namespace new of private protected public '
        'readonly return satisfies set static super switch this throw try type '
        'typeof var void while yield',
    types: 'any bigint boolean never number object string symbol undefined '
        'unknown true false null console Promise Array Record Partial Map Set '
        'Math JSON',
    multilineQuotes: ['`'],
  ),
  'dart': _Grammar(
    keywords: 'abstract as assert async await base break case catch class '
        'const continue covariant default deferred do else enum export '
        'extends extension external factory final finally for get hide if '
        'implements import in interface is late library mixin new on operator '
        'part required rethrow return sealed set show static super switch sync '
        'this throw try typedef var while with yield',
    types: 'bool double dynamic int num void Object String List Map Set '
        'Iterable Future Stream Duration DateTime Widget BuildContext true '
        'false null print',
    atMeta: true,
  ),
  'go': _Grammar(
    keywords: 'break case chan const continue default defer else fallthrough '
        'for func go goto if import interface map package range return select '
        'struct switch type var',
    types: 'bool byte complex64 complex128 error float32 float64 int int8 '
        'int16 int32 int64 rune string uint uint8 uint16 uint32 uint64 uintptr '
        'true false nil iota make new len cap append copy delete panic recover '
        'print println fmt',
  ),
  'rust': _Grammar(
    keywords: 'as async await break const continue crate dyn else enum extern '
        'fn for if impl in let loop match mod move mut pub ref return static '
        'struct super trait type unsafe use where while',
    types: 'bool char f32 f64 i8 i16 i32 i64 i128 isize str u8 u16 u32 u64 '
        'u128 usize String Vec Option Result Some None Ok Err Box self Self '
        'true false println print vec',
    hashMeta: true,
  ),
  'kotlin': _Grammar(
    keywords: 'as break by catch class companion const constructor continue '
        'crossinline data do dynamic else enum external field finally for fun '
        'get if import in infix init inline inner interface internal is '
        'lateinit noinline object open operator out override package private '
        'protected public reified return sealed set super suspend this throw '
        'try typealias val var vararg when where while',
    types: 'Any Array Boolean Byte Char Double Float Int List Long Map Nothing '
        'Set Short String Unit true false null it println print',
    atMeta: true,
  ),
  'swift': _Grammar(
    keywords: 'associatedtype async await break case catch class continue '
        'default defer deinit do else enum extension fallthrough fileprivate '
        'final for func guard if import in init inout internal is lazy let '
        'mutating open operator private protocol public repeat rethrows return '
        'static struct subscript super switch throw throws try typealias var '
        'weak where while',
    types: 'Any AnyObject Array Bool Character Dictionary Double Float Int Set '
        'String Void Optional self Self true false nil print',
    atMeta: true,
  ),
  'php': _Grammar(
    keywords: 'abstract and as break callable case catch class clone const '
        'continue declare default do echo else elseif empty enddeclare endfor '
        'endforeach endif endswitch endwhile enum extends final finally fn for '
        'foreach function global goto if implements include include_once '
        'instanceof insteadof interface isset list match namespace new or print '
        'private protected public readonly require require_once return static '
        'switch throw trait try unset use var while xor yield',
    types: 'array bool float int iterable mixed object string void null true '
        'false self parent this echo count strlen str_replace array_map '
        'var_dump printf sprintf',
    lineComments: ['//', '#'],
    phpTags: true,
  ),
  'ruby': _Grammar(
    keywords: 'alias and begin break case class def defined? do else elsif '
        'end ensure for if in module next not or redo rescue retry return '
        'super then undef unless until when while yield',
    types: 'true false nil self attr_accessor attr_reader attr_writer require '
        'require_relative puts print p lambda proc new Array Hash String '
        'Integer Float Symbol',
    lineComments: ['#'],
    blockComment: null,
  ),
  'sql': _Grammar(
    keywords: 'add all alter and as asc begin between by case cast check '
        'column commit constraint create cross default delete desc distinct '
        'drop else end exists foreign from full group having if in index inner '
        'insert into is join key left like limit not null offset on or order '
        'outer primary references returning right rollback select set table '
        'then union unique update using values view when where with',
    types: 'bigint boolean char date decimal double float int integer '
        'interval json jsonb numeric real serial smallint text time timestamp '
        'uuid varchar avg count max min sum coalesce now',
    lineComments: ['--'],
    caseInsensitive: true,
  ),
  'bash': _Grammar(
    keywords: 'alias break case continue declare do done elif else esac eval '
        'exec exit export fi for function if in local read readonly return '
        'select set shift source then time trap unset until while',
    types: 'cat cd chmod cp curl cut date echo find grep head kill ls mkdir mv '
        'printf ps pwd rm sed sleep sort tail tar touch tr wc which xargs '
        'true false',
    lineComments: ['#'],
    blockComment: null,
  ),
};

/// True when the language has a grammar at all — `text` does not, and neither
/// does anything the picker has not heard of.
bool isHighlightable(String? language) =>
    _grammars.containsKey(language ?? 'text');

// ----------------------------------------------------------------- scanner

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

bool _isWordStart(int c) =>
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c == 0x5F || // _
    c == 0x24; // $ — a PHP variable is one word, not a stray sigil

bool _isWordChar(int c) => _isWordStart(c) || _isDigit(c);

/// Every non-plain run in [source], in order and never overlapping.
List<CodeToken> tokenizeCode(String source, String? language) {
  final grammar = _grammars[language ?? 'text'];
  if (grammar == null || source.isEmpty) return const [];

  final tokens = <CodeToken>[];
  final units = source.codeUnits;
  final n = source.length;
  var i = 0;

  while (i < n) {
    final unit = units[i];

    if (unit == 0x0A || unit == 0x20 || unit == 0x09 || unit == 0x0D) {
      i++;
      continue;
    }

    if (grammar.phpTags &&
        (source.startsWith('<?php', i) ||
            source.startsWith('<?=', i) ||
            source.startsWith('?>', i))) {
      final length = source.startsWith('<?php', i)
          ? 5
          : source.startsWith('<?=', i)
              ? 3
              : 2;
      tokens.add(CodeToken(i, i + length, CodeTokenKind.meta));
      i += length;
      continue;
    }

    final block = grammar.blockComment;
    if (block != null && source.startsWith(block.$1, i)) {
      final close = source.indexOf(block.$2, i + block.$1.length);
      final stop = close < 0 ? n : close + block.$2.length;
      tokens.add(CodeToken(i, stop, CodeTokenKind.comment));
      i = stop;
      continue;
    }

    var matchedComment = false;
    for (final marker in grammar.lineComments) {
      if (!source.startsWith(marker, i)) continue;
      var stop = source.indexOf('\n', i);
      if (stop < 0) stop = n;
      tokens.add(CodeToken(i, stop, CodeTokenKind.comment));
      i = stop;
      matchedComment = true;
      break;
    }
    if (matchedComment) continue;

    var matchedString = false;
    for (final quote in grammar.multilineQuotes) {
      if (!source.startsWith(quote, i)) continue;
      final stop = _scanQuoted(source, i, quote, stopAtNewline: false);
      tokens.add(CodeToken(i, stop, CodeTokenKind.string));
      i = stop;
      matchedString = true;
      break;
    }
    if (matchedString) continue;

    final char = source[i];
    if (_Grammar.quotes.contains(char)) {
      final stop = _scanQuoted(source, i, char, stopAtNewline: true);
      tokens.add(CodeToken(i, stop, CodeTokenKind.string));
      i = stop;
      continue;
    }

    // `#include` is only a preprocessor line when it opens the line; a `#`
    // anywhere else in C is an operator inside a macro.
    if (grammar.hashMeta && char == '#' && _atLineStart(source, i)) {
      var stop = source.indexOf('\n', i);
      if (stop < 0) stop = n;
      tokens.add(CodeToken(i, stop, CodeTokenKind.meta));
      i = stop;
      continue;
    }

    if (grammar.atMeta && char == '@' && i + 1 < n && _isWordStart(units[i + 1])) {
      var stop = i + 1;
      while (stop < n && _isWordChar(units[stop])) {
        stop++;
      }
      tokens.add(CodeToken(i, stop, CodeTokenKind.meta));
      i = stop;
      continue;
    }

    if (_isDigit(unit) ||
        (unit == 0x2E && i + 1 < n && _isDigit(units[i + 1]))) {
      var stop = i;
      // Loose on purpose: `0x1f`, `1_000_000`, `3.14f`, `1e9` are all one
      // number and none of them need pulling apart to be coloured.
      while (stop < n &&
          (_isWordChar(units[stop]) ||
              units[stop] == 0x2E ||
              ((units[stop] == 0x2B || units[stop] == 0x2D) &&
                  stop > i &&
                  (source[stop - 1] == 'e' || source[stop - 1] == 'E')))) {
        stop++;
      }
      tokens.add(CodeToken(i, stop, CodeTokenKind.number));
      i = stop;
      continue;
    }

    if (_isWordStart(unit)) {
      var stop = i;
      while (stop < n && (_isWordChar(units[stop]) ||
          // Ruby's `defined?`, `empty?`, `save!` end in punctuation.
          (language == 'ruby' &&
              stop > i &&
              (units[stop] == 0x3F || units[stop] == 0x21)))) {
        stop++;
      }
      final raw = source.substring(i, stop);
      final word = grammar.caseInsensitive ? raw.toLowerCase() : raw;
      if (grammar.keywords.contains(word)) {
        tokens.add(CodeToken(i, stop, CodeTokenKind.keyword));
      } else if (grammar.types.contains(word)) {
        tokens.add(CodeToken(i, stop, CodeTokenKind.type));
      }
      i = stop;
      continue;
    }

    i++;
  }

  return tokens;
}

/// Where the literal opened at [start] with [quote] ends — one past its
/// closing quote, or at the newline / end of buffer when it never closes.
int _scanQuoted(String source, int start, String quote,
    {required bool stopAtNewline}) {
  final n = source.length;
  var i = start + quote.length;
  while (i < n) {
    final char = source[i];
    if (char == r'\') {
      i += 2;
      continue;
    }
    if (stopAtNewline && char == '\n') return i;
    if (source.startsWith(quote, i)) return i + quote.length;
    i++;
  }
  return n;
}

bool _atLineStart(String source, int index) {
  for (var i = index - 1; i >= 0; i--) {
    final char = source[i];
    if (char == '\n') return true;
    if (char != ' ' && char != '\t') return false;
  }
  return true;
}

// ------------------------------------------------------------------ spans

/// One style per character, so runs can be grouped without re-scanning.
List<CodeTokenKind?> _kindsFor(String source, String? language) {
  final kinds = List<CodeTokenKind?>.filled(source.length, null);
  for (final token in tokenizeCode(source, language)) {
    final end = token.end > source.length ? source.length : token.end;
    for (var i = token.start; i < end; i++) {
      kinds[i] = token.kind;
    }
  }
  return kinds;
}

List<TextSpan> _spansForRange(
    String source, List<CodeTokenKind?> kinds, int from, int to, TextStyle base) {
  final spans = <TextSpan>[];
  var runStart = from;
  for (var i = from; i <= to; i++) {
    final atEnd = i == to;
    if (atEnd || kinds[i] != kinds[runStart]) {
      spans.add(TextSpan(
        text: source.substring(runStart, i),
        style: codeTokenStyle(kinds[runStart], base),
      ));
      runStart = i;
    }
  }
  return spans;
}

/// The whole buffer as one span tree — what the editor's controller returns.
TextSpan highlightCode(String source, String? language, TextStyle base) {
  if (!isHighlightable(language) || source.isEmpty) {
    return TextSpan(text: source, style: base);
  }
  final kinds = _kindsFor(source, language);
  return TextSpan(
    style: base,
    children: _spansForRange(source, kinds, 0, source.length, base),
  );
}

/// One span per line, for the read-only block, which draws lines separately so
/// the line-number gutter can stay put while the code scrolls sideways.
List<TextSpan> highlightCodeLines(
    String source, String? language, TextStyle base) {
  final lines = source.split('\n');
  if (!isHighlightable(language)) {
    return [for (final line in lines) TextSpan(text: line, style: base)];
  }

  final kinds = _kindsFor(source, language);
  final spans = <TextSpan>[];
  var offset = 0;
  for (final line in lines) {
    spans.add(TextSpan(
      style: base,
      children: _spansForRange(source, kinds, offset, offset + line.length, base),
    ));
    offset += line.length + 1; // the '\n' we split on
  }
  return spans;
}

/// A [TextEditingController] that paints the code as you type it.
///
/// Overriding `buildTextSpan` is the whole trick — no second widget layered
/// behind the field, no scroll offsets to keep in sync, and selection and the
/// caret keep working because it is still a plain `TextField`.
class CodeHighlightController extends TextEditingController {
  CodeHighlightController({super.text, String language = 'text'})
      : _language = language;

  String _language;

  String get language => _language;

  set language(String value) {
    if (_language == value) return;
    _language = value;
    _cachedFor = null;
    notifyListeners();
  }

  String? _cachedFor;
  TextSpan? _cachedSpan;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    // Mid-composition (an IME candidate, autocorrect on a phone keyboard) the
    // framework needs its own underlined composing span, and ours would drop
    // it. Rare and brief, so plain text for that one frame is the right trade.
    if (withComposing && value.isComposingRangeValid && !value.composing.isCollapsed) {
      return super
          .buildTextSpan(context: context, style: style, withComposing: true);
    }
    if (_cachedFor != text || _cachedSpan == null) {
      _cachedFor = text;
      _cachedSpan = highlightCode(text, _language, base);
    }
    return _cachedSpan!;
  }
}

// ------------------------------------------------------------------ masking

/// [source] with every comment and string literal blanked out, plus the lines
/// that begin inside one.
///
/// The re-indenter reads this instead of the raw text: a `{` inside a string
/// must not open a block, `//` inside a URL must not comment out the rest of
/// the line, and the body of a multi-line string must be left exactly as it
/// is, because its leading whitespace is part of its value.
class MaskedCode {
  const MaskedCode(this.masked, this.continuedLines);

  /// Same length as the source, so offsets still line up. Blanked characters
  /// become spaces; newlines survive.
  final String masked;

  /// Indices of lines that start inside a string or comment that opened on an
  /// earlier line.
  final Set<int> continuedLines;
}

MaskedCode maskCode(String source, String? language) {
  final tokens = tokenizeCode(source, language);
  if (tokens.isEmpty) return MaskedCode(source, const {});

  final units = List<int>.from(source.codeUnits);
  final continued = <int>{};

  // Line index of every offset, built once.
  final lineOf = List<int>.filled(source.length + 1, 0);
  var line = 0;
  for (var i = 0; i < source.length; i++) {
    lineOf[i] = line;
    if (units[i] == 0x0A) line++;
  }
  lineOf[source.length] = line;

  for (final token in tokens) {
    if (token.kind != CodeTokenKind.string &&
        token.kind != CodeTokenKind.comment) {
      continue;
    }
    final end = token.end > source.length ? source.length : token.end;
    for (var i = token.start; i < end; i++) {
      if (units[i] == 0x0A) {
        // The next line opens inside this token.
        continued.add(lineOf[i] + 1);
      } else {
        units[i] = 0x20;
      }
    }
  }

  return MaskedCode(String.fromCharCodes(units), continued);
}
