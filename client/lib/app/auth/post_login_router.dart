import 'package:flutter/material.dart';

import '../../services/api/api_client.dart';
import '../../services/common/user_service.dart';
import '../dashboard.dart';
import '../profile/profile_create.dart';

/// Where a signed-in user belongs.
///
/// Verifying an email creates the Supabase account but not the `users` row —
/// that happens in ProfileCreate. Anyone who quits the app mid-onboarding (or
/// signs in on a new device before finishing) has a valid session and no
/// profile, so every entry point has to ask the API which state they are in
/// rather than assuming the dashboard.
Future<Widget> landingScreenForCurrentUser() async {
  try {
    await UserService.instance.me();
    return const Dashboard();
  } on ApiException catch (e) {
    if (e.isNotFound) return const ProfileCreate();
    // Offline or server down: the dashboard degrades gracefully, whereas
    // sending a fully onboarded user back through signup would not.
    return const Dashboard();
  }
}

/// Replaces the whole stack with wherever the user belongs.
Future<void> goToLanding(BuildContext context) async {
  final screen = await landingScreenForCurrentUser();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => screen),
    (route) => false,
  );
}
