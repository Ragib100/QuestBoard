import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Registers a new account and sends the verification email.
  ///
  /// Throws an [AuthException] if the email is already registered. Supabase
  /// does not do this for us: to stop attackers probing which emails exist, it
  /// returns a normal-looking success with an obfuscated user whose
  /// `identities` list is empty. That empty list is the only signal, so we
  /// translate it into a real error here rather than showing "check your
  /// inbox" for a mail that will never arrive.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'io.questboard://signup-callback',
    );

    final identities = res.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw const AuthException(
        'That email is already registered. Try logging in, or reset your '
        'password if you have forgotten it.',
      );
    }

    return res;
  }

  /// Re-sends the signup confirmation mail. Supabase rate-limits this and
  /// surfaces the wait as an [AuthException], which is worth showing verbatim —
  /// "try again in 47 seconds" is more useful than a generic failure.
  Future<void> resendVerification({required String email}) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: 'io.questboard://signup-callback',
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    // print(Supabase.instance.client.auth.currentSession?.accessToken);
    return res;
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  Future<void> forgotPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.questboard://reset-callback',
    );
  }

  Future<void> updatePassword({required String password}) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
