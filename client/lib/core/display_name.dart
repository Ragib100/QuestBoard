/// How a person is named on screen when their profile is incomplete.
///
/// Signing up seeds `username` with the address the account was created with,
/// so an account that never finished onboarding is called
/// `saifahmedsakib@gmail.com` everywhere. That is wrong twice over: it puts an
/// email address in a 28px page heading — visible to anyone looking at the
/// screen, and to everyone else on a quest tile — and an address has no spaces,
/// so it cannot wrap. As a heading it broke mid-token across two lines and ate
/// the top of the home screen.
///
/// The address is never *shown*; only the part before the `@` is, which is what
/// people pick as a handle anyway.
library;

/// A name safe to render: the full name if there is one, otherwise the
/// username with any email domain trimmed off.
String personName({
  required String firstName,
  required String lastName,
  required String username,
}) {
  final full = '$firstName $lastName'.trim();
  if (full.isNotEmpty) return full;
  return handleOf(username);
}

/// `saifahmedsakib@gmail.com` → `saifahmedsakib`. Anything without an `@` is
/// already a handle and comes back untouched.
String handleOf(String username) {
  final at = username.indexOf('@');
  if (at <= 0) return username;
  return username.substring(0, at);
}

/// The first name alone, for a greeting — "Welcome back, Saif!". Falls back to
/// the handle, and never to an address.
String greetingName({required String firstName, required String username}) {
  final first = firstName.trim();
  return first.isNotEmpty ? first : handleOf(username);
}
