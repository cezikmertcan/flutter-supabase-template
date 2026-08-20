class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const redirectUri = String.fromEnvironment(
    'SUPABASE_REDIRECT_URI',
    defaultValue: 'com.futurefry.flashcardai://login-callback',
  );

  static bool get isConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    final hasSupportedScheme = uri?.scheme == 'https' || uri?.scheme == 'http';
    final hasUsableKey =
        supabasePublishableKey.isNotEmpty &&
        !supabasePublishableKey.contains('<') &&
        !supabasePublishableKey.startsWith('replace_');

    return uri != null &&
        hasSupportedScheme &&
        uri.host.isNotEmpty &&
        hasUsableKey;
  }
}
