import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens an external link, falling back to the clipboard.
///
/// The daily challenge is a link out by design — the points come from a verdict
/// on Codeforces, so the problem statement lives there. Until this existed the
/// app displayed the problem URL as text you had to select and paste into a
/// browser yourself, which is most of the reason claiming "never worked": the
/// flow asks you to solve it on Codeforces and then made getting there a chore.
///
/// Returns null on success, or a message to show the user. Never throws: a
/// device with no browser is unusual but not an error worth crashing on, and
/// having the link on the clipboard is still a way forward.
Future<String?> openLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'That link is malformed.';

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return null;
  } catch (_) {
    // Falls through to the clipboard.
  }

  await Clipboard.setData(ClipboardData(text: url));
  return 'Could not open a browser. The link is on your clipboard.';
}
