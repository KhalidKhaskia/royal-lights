import 'secrets.dart';

class SupabaseConfig {
  // ⚡ Flip this to switch between environments
  static const bool isProduction = false; // true = PROD, false = TEST

  static String get supabaseUrl => isProduction ? Secrets.prodSupabaseUrl : Secrets.testSupabaseUrl;
  static String get supabaseAnonKey => isProduction ? Secrets.prodSupabaseKey : Secrets.testSupabaseKey;
}
