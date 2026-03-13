import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

class AuthService {
  final SupabaseClient _client;
  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  String get currentUsername =>
      _client.auth.currentUser?.userMetadata?['username'] as String? ??
      'unknown';

  /// Convert phone number to a synthetic email for Supabase Email Auth
  String _phoneToEmail(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$cleaned@royallight.store';
  }

  /// Sign in with phone + username
  Future<AuthResponse> signIn(String phone, String username) async {
    return await _client.auth
        .signInWithPassword(email: _phoneToEmail(phone), password: username)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Connection timeout. Check your internet.'),
        );
  }

  /// Sign up with phone + username
  Future<AuthResponse> signUp(String phone, String username) async {
    return await _client.auth
        .signUp(
          email: _phoneToEmail(phone),
          password: username,
          data: {'username': username, 'full_name': username, 'phone': phone},
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw Exception('Connection timeout. Check your internet.'),
        );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  bool get isAuthenticated => _client.auth.currentSession != null;
}
