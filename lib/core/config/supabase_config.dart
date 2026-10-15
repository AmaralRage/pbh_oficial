class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xbwspizvpcnjxvlylcvx.supabase.co',
  );
  static const publishableKey =
      String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_G_lAseuQBV6Eydk74lKvEw_mMrzaRH8',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
