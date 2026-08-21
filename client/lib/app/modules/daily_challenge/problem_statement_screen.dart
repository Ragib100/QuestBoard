import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/codeforces_web.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/code_view.dart';
import '../../../models/challenge.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/challenge_service.dart';

/// The real Codeforces problem statement, rendered in QuestBoard.
///
/// The statement arrives as sanitised HTML — Codeforces publishes maths as
/// `$$$...$$$` for MathJax, plus images, tables and pre-formatted samples, and
/// flattening all of that into a `Text` widget would lose the half of a problem
/// statement that carries the meaning. So it is drawn in a WebView with our own
/// stylesheet over it, which is what makes it look like part of the app rather
/// than a page from somebody else's site (decisions.md D45).
///
/// Where there is no WebView — the Linux and Windows desktop builds — the same
/// content degrades to stripped text plus native sample blocks. That is worse,
/// and it is honest about being worse.
class ProblemStatementScreen extends StatefulWidget {
  const ProblemStatementScreen({
    super.key,
    required this.challengeId,
    required this.title,
    this.fallbackBody = '',
  });

  final String challengeId;
  final String title;

  /// The challenge's own generated summary. Shown when Codeforces refuses us
  /// the page, which happens and must not leave an empty screen.
  final String fallbackBody;

  @override
  State<ProblemStatementScreen> createState() => _ProblemStatementScreenState();
}

class _ProblemStatementScreenState extends State<ProblemStatementScreen> {
  ProblemStatement? _statement;
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  /// True when [_error] came from never reaching the server, rather
  /// than from the server saying no. Only the first kind is worth
  /// waiting through, and [ErrorState] draws it as a spinner.
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statement =
          await ChallengeService.instance.statement(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _statement = statement;
        _loading = false;
      });
      if (statement.available && canEmbedCodeforces) _render(statement);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => (
              _error = e.message,
              _offline = e.isOffline,
              _loading = false
            ));
      }
    }
  }

  void _render(ProblemStatement statement) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      // The page's only way back into the app, and it does exactly one thing.
      // The HTML is third-party even after sanitising, so the channel is
      // deliberately not a general-purpose bridge.
      ..addJavaScriptChannel('QBCopy', onMessageReceived: (message) async {
        await Clipboard.setData(ClipboardData(text: message.message));
        if (mounted) {
          showAppSnack(context, 'Copied.', tone: SnackTone.success);
        }
      })
      ..loadHtmlString(
        statementDocument(statement),
        // Anything the statement still points at relatively resolves against
        // Codeforces, not against about:blank.
        baseUrl: 'https://codeforces.com/',
      );
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final statement = _statement;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        actions: [
          if (statement?.sourceUrl != null)
            IconButton(
              tooltip: 'Open on Codeforces',
              onPressed: () => openCodeforces(context, statement!.sourceUrl!,
                  title: widget.title),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
        ],
      ),
      body: _body(statement),
    );
  }

  Widget _body(ProblemStatement? statement) {
    if (_loading) return const LoadingState();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load, offline: _offline);
    if (statement == null) return const SizedBox.shrink();

    if (!statement.available) return _unavailable(statement);
    if (!canEmbedCodeforces) return _plainText(statement);

    final controller = _controller;
    return controller == null
        ? const LoadingState()
        : WebViewWidget(controller: controller);
  }

  /// Codeforces would not serve the page. Says so, shows what we do have, and
  /// offers the real thing — rather than an empty screen or an invented one.
  Widget _unavailable(ProblemStatement statement) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 20, color: AppColors.warningDark),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Codeforces would not hand us the statement this time — they '
                  'rate-limit automated readers. Open it there, or pull this '
                  'screen again in a moment.',
                  style: TextStyle(
                      color: AppColors.warningDark, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (widget.fallbackBody.isNotEmpty) ...[
          const SizedBox(height: 20),
          SelectableText(widget.fallbackBody,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15, height: 1.6)),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _load,
                child: const Text('Try again'),
              ),
            ),
            if (statement.sourceUrl != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => openCodeforces(context, statement.sourceUrl!,
                      title: widget.title),
                  child: const Text('Open on Codeforces'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// The desktop fallback: no WebView, so no HTML rendering and no MathJax.
  /// The prose is stripped to text and the samples stay exact, because a
  /// sample you cannot trust character-for-character is worse than none.
  Widget _plainText(ProblemStatement statement) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        _limits(statement),
        const SizedBox(height: 16),
        SelectableText(
          htmlToText(withoutSamples(statement.html)),
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 15, height: 1.6),
        ),
        for (final (i, sample) in statement.samples.indexed) ...[
          const SizedBox(height: 24),
          Text('Example ${i + 1}',
              style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          CodeBlock(code: sample.input, language: 'text'),
          const SizedBox(height: 8),
          CodeBlock(code: sample.output, language: 'text'),
        ],
      ],
    );
  }

  Widget _limits(ProblemStatement statement) {
    final parts = [
      if (statement.timeLimit.isNotEmpty) statement.timeLimit,
      if (statement.memoryLimit.isNotEmpty) statement.memoryLimit,
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(parts.join('  ·  '),
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted));
  }

}

/// The page handed to the WebView: Codeforces' markup, our typography.
///
/// Top-level and public so it can be rendered and looked at without a device:
/// `webview_flutter` has no Linux build, so generating this and opening it in a
/// browser is the only way to see it on the machine it is written on.
String statementDocument(ProblemStatement statement) {
    // Worded, not pictographic. The first version used ⏱ and ▨, and a device
    // without those glyphs draws a tofu box next to the only two numbers on the
    // page that constrain the solution.
    final limits = [
      if (statement.timeLimit.isNotEmpty)
        '<span><b>Time</b> ${statement.timeLimit}</span>',
      if (statement.memoryLimit.isNotEmpty)
        '<span><b>Memory</b> ${statement.memoryLimit}</span>',
    ].join('');

    return '''
<!doctype html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root {
    --text: #1E293B; --muted: #64748B; --border: #E2E8F0;
    --fill: #F1F5F9; --primary: #0066FF;
  }
  html { -webkit-text-size-adjust: 100%; }
  body {
    margin: 0; padding: 20px 18px 48px;
    font-family: Inter, -apple-system, "Segoe UI", Roboto, sans-serif;
    font-size: 15px; line-height: 1.65; color: var(--text);
    background: #FFFFFF;
  }
  .qb-limits {
    display: flex; gap: 16px; flex-wrap: wrap;
    font-size: 12.5px; color: var(--muted);
    padding-bottom: 14px; margin-bottom: 18px;
    border-bottom: 1px solid var(--border);
  }
  .qb-limits b {
    color: var(--text); font-weight: 600;
    text-transform: uppercase; letter-spacing: .04em; font-size: 11px;
  }
  p { margin: 0 0 12px; }
  /* Codeforces' own section headings. */
  .section-title {
    font-weight: 700; font-size: 17px; color: var(--text);
    margin: 26px 0 10px;
  }
  .input-specification, .output-specification, .note { margin-top: 4px; }
  img { max-width: 100%; height: auto; }
  /* Wide content scrolls in its own box; the page itself never does. */
  table { border-collapse: collapse; display: block; overflow-x: auto; }
  table td, table th { border: 1px solid var(--border); padding: 6px 10px; }
  .sample-test { margin-top: 8px; }
  .sample-test .input, .sample-test .output {
    position: relative; border: 1px solid var(--border);
    border-radius: 10px; background: var(--fill);
    margin-bottom: 10px; overflow: hidden;
  }
  .sample-test .title {
    font-size: 12px; font-weight: 700; color: var(--muted);
    padding: 8px 12px 0; text-transform: uppercase; letter-spacing: .04em;
  }
  .sample-test pre {
    margin: 6px 0 0; padding: 4px 12px 12px;
    font-family: ui-monospace, "Courier New", monospace;
    font-size: 13px; line-height: 1.5;
    white-space: pre; overflow-x: auto;
  }
  .test-example-line { white-space: pre; }
  .qb-copy {
    position: absolute; top: 6px; right: 8px;
    font: 600 11px/1 Inter, sans-serif; color: var(--primary);
    background: #FFFFFF; border: 1px solid var(--border);
    border-radius: 999px; padding: 6px 12px; cursor: pointer;
  }
  /* MathJax leaves the source visible until it runs; without this the reader
     sees a flash of raw \$\$\$ delimiters on every load. */
  .qb-pending { visibility: hidden; }
</style>
<script>
  window.MathJax = {
    // Codeforces' delimiters, not the defaults.
    tex: { inlineMath: [['\$\$\$', '\$\$\$']],
           displayMath: [['\$\$\$\$\$\$', '\$\$\$\$\$\$']] },
    options: { skipHtmlTags: ['script','noscript','style','textarea','pre'] },
    startup: { pageReady: function () {
      return MathJax.startup.defaultPageReady().then(reveal);
    } }
  };
  function reveal() { document.body.classList.remove('qb-pending'); }
  // MathJax comes off a CDN. With no network it never loads, so this is the
  // backstop that stops the statement staying invisible forever — the maths
  // then reads as its raw source, which is still readable.
  setTimeout(reveal, 2500);

  function addCopyButtons() {
    var boxes = document.querySelectorAll('.sample-test .input, .sample-test .output');
    for (var i = 0; i < boxes.length; i++) {
      (function (box) {
        var pre = box.querySelector('pre');
        if (!pre) return;
        var button = document.createElement('button');
        button.className = 'qb-copy';
        button.textContent = 'Copy';
        button.addEventListener('click', function () {
          QBCopy.postMessage(pre.innerText);
          button.textContent = 'Copied';
          setTimeout(function () { button.textContent = 'Copy'; }, 1200);
        });
        box.appendChild(button);
      })(boxes[i]);
    }
  }
  document.addEventListener('DOMContentLoaded', addCopyButtons);
</script>
<script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
</head>
<body class="qb-pending">
${limits.isEmpty ? '' : '<div class="qb-limits">$limits</div>'}
${statement.html}
</body></html>
''';
}

/// A very small HTML-to-text reduction, for the platforms with no WebView.
///
/// Not a parser and not trying to be: the server already stripped everything
/// executable, so this only has to turn block tags into line breaks, unwrap
/// entities, and make Codeforces' `$$$...$$$` maths readable without MathJax.
/// Anywhere a WebView exists, the real renderer is used instead.
String htmlToText(String html) {
  var text = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  const entities = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&mdash;': '—',
    '&ndash;': '–',
    '&le;': '≤',
    '&ge;': '≥',
    '&amp;': '&', // last: otherwise it re-creates the others
  };
  entities.forEach((from, to) => text = text.replaceAll(from, to));

  return _readableMath(text).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Turns `$$$1 \le n \le 2 \cdot 10^5$$$` into `1 ≤ n ≤ 2 · 10⁵`.
///
/// Nowhere near a TeX engine, and it does not need to be: this is the fallback
/// for a platform with no WebView, where the alternative is a wall of literal
/// `$$$` and backslashes. Half the sentences in a Codeforces statement have
/// maths in them, so leaving the source visible makes the whole thing unreadable
/// rather than merely plain.
String _readableMath(String text) {
  const macros = {
    r'\le': '≤', r'\leq': '≤', r'\ge': '≥', r'\geq': '≥',
    r'\ne': '≠', r'\neq': '≠', r'\cdot': '·', r'\times': '×',
    r'\dots': '…', r'\ldots': '…', r'\infty': '∞', r'\pm': '±',
    r'\rightarrow': '→', r'\to': '→', r'\in': '∈', r'\sum': '∑',
    r'\bmod': 'mod', r'\%': '%', r'\{': '{', r'\}': '}', r'\,': ' ',
  };
  const superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', 'n': 'ⁿ',
  };
  const subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ', 'n': 'ₙ', 'm': 'ₘ',
  };

  String script(String digits, Map<String, String> table) {
    final out = StringBuffer();
    for (final ch in digits.split('')) {
      final mapped = table[ch];
      // Anything with no glyph keeps its ASCII form rather than vanishing.
      if (mapped == null) return table == superscripts ? '^$digits' : '_$digits';
      out.write(mapped);
    }
    return out.toString();
  }

  return text.replaceAllMapped(RegExp(r'\$\$\$(.+?)\$\$\$', dotAll: true), (m) {
    var inner = m[1]!;
    macros.forEach((from, to) => inner = inner.replaceAll(from, to));
    inner = inner
        .replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (e) => script(e[1]!, superscripts))
        .replaceAllMapped(RegExp(r'\^(\w)'), (e) => script(e[1]!, superscripts))
        .replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (e) => script(e[1]!, subscripts))
        .replaceAllMapped(RegExp(r'_(\w)'), (e) => script(e[1]!, subscripts));
    // Any macro we do not know loses its backslash rather than shouting it.
    // replaceAllMapped, not replaceAll: `$1` is a literal to replaceAll, so
    // that version turned every unknown macro into the text "$1".
    return inner
        .replaceAllMapped(RegExp(r'\\([a-zA-Z]+)'), (e) => e[1]!)
        .trim();
  });
}

/// Drops the worked examples from [html].
///
/// The plain-text fallback renders them itself, from the structured `samples`,
/// where they stay exact and copyable — leaving them in the prose as well would
/// print every example twice.
String withoutSamples(String html) {
  final start = html.indexOf('<div class="sample-tests">');
  if (start < 0) return html;
  final note = html.indexOf('<div class="note">', start);
  return note < 0 ? html.substring(0, start) : html.substring(0, start) + html.substring(note);
}
