# Supabase Flutter Template

![Flutter](https://img.shields.io/badge/Flutter-iOS%20%2B%20Android-02569B?logo=flutter)
![Supabase](https://img.shields.io/badge/Supabase-Auth%20%2B%20Postgres-3ECF8E?logo=supabase)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

A clean, reusable starting point for Flutter apps backed by Supabase. The template includes a small Material 3 dashboard, OAuth entry points, a local-first state store, authenticated remote sync, row-level security migrations, and a secure account-deletion Edge Function.

The sample UI is intentionally generic. Replace the example dashboard with your product experience while keeping the infrastructure pieces that fit your use case.

## Included

- Flutter iOS and Android project generated from a clean platform scaffold.
- Supabase Auth provider hooks for Google and GitHub.
- `--dart-define-from-file` configuration with no project URL or key committed.
- Local-first state using `shared_preferences`.
- Persisted system/light/dark theme selection.
- Debounced authenticated sync to a protected `user_state` row.
- `profiles` table and new-user trigger with RLS policies.
- Optional, allowlisted analytics schema with no free-text payload requirement.
- Account deletion through a server-side Edge Function that keeps the service role key off-device.
- CI workflow for formatting, static analysis, tests, and secret-pattern checks.

## Quick start

```bash
flutter pub get
cp config/dart-defines.example.json config/dart-defines.json
# Edit config/dart-defines.json with your own Supabase values.
flutter run --dart-define-from-file=config/dart-defines.json
```

The default build is still useful without configuration: it shows the local-first sample state and keeps authentication controls disabled.

## Supabase setup

1. Create a Supabase project.
2. Copy `config/dart-defines.example.json` to `config/dart-defines.json` and add the project URL plus publishable key.
3. Apply the database migrations:

   ```bash
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```

4. Deploy the account-deletion function and set its server-only secret:

   ```bash
   supabase functions deploy delete-account
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
   ```

   Never put the service role key in Flutter code, a Dart define file, an issue, or a commit.

5. Enable Google and/or GitHub under Supabase Auth → Providers. Register the platform callback scheme in the provider configuration as described in [Supabase setup](docs/supabase-setup.md).

6. Keep the redirect URI aligned across `config/dart-defines.json`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, and Supabase Auth URL configuration:

   ```text
   com.example.supabasefluttertemplate://login-callback
   ```

## Development

```bash
dart format lib test
flutter analyze
flutter test
bash tool/check_secrets.sh
```

The automated test suite runs on the host Dart VM. It does not require an iPhone or Android simulator.

## Project structure

```text
lib/
  core/       Runtime configuration and theme
  screens/    Example dashboard and account settings
  services/   Auth, local state, and remote sync
supabase/
  migrations/ RLS-protected profile, state, and analytics tables
  functions/  Server-side account deletion
test/         Host-side widget and unit tests
docs/         Setup, architecture, and release guidance
```

See [architecture.md](docs/architecture.md) for the data flow and [release-checklist.md](docs/release-checklist.md) before publishing an app built from this template.

## Security model

- The client accepts only a Supabase URL and publishable/anon key through build-time defines.
- All user tables have RLS enabled and policies are scoped to `auth.uid()`.
- Service-role access is isolated inside the `delete-account` Edge Function.
- Analytics is allowlisted and should contain only low-risk product events.
- Local config, signing material, generated build files, and Dart define files are ignored by Git.
- Run `bash tool/check_secrets.sh` before every push.

Read [SECURITY.md](SECURITY.md) before adapting the template to production data.

## Customization checklist

- Change the app name and package/bundle identifiers in the Flutter and native projects.
- Replace the example dashboard and sample state payload.
- Add only the Supabase tables and policies your product needs.
- Review OAuth providers, redirect URLs, email settings, deep links, and deletion behavior.
- Replace the placeholder launcher icons and signing configuration.
- Add product-specific tests and a privacy policy before public release.

## License

Released under the [MIT License](LICENSE).
