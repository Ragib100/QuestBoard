import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => dotenv.maybeGet('SUPABASE_URL')?.trim() ?? '';
  static String get publishableKey =>
      dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY')?.trim() ?? '';

  static bool get isConfigured {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        !url.contains('your_') &&
        publishableKey.isNotEmpty &&
        !publishableKey.contains('your_');
  }
}
