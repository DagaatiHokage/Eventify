/// Build-time configuration, passed with `--dart-define` or
/// `--dart-define-from-file=env.json` (see README).
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// The city the app opens in until the user picks one. Accra for launch.
  static const defaultCitySlug = String.fromEnvironment(
    'DEFAULT_CITY',
    defaultValue: 'accra',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
