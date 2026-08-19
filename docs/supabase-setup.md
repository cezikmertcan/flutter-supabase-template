# Supabase setup

This guide covers the parts that must agree between Supabase, Flutter, iOS, Android, and the OAuth provider.

## Database

Install the Supabase CLI, authenticate, link the project, and apply the migrations:

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

The migrations create:

- `public.profiles`: one row per authenticated user, protected by RLS.
- `public.user_state`: one JSON payload per user for the local-first example.
- `public.analytics_events`: optional, allowlisted low-risk events.

Review the policies and adapt them before adding product-specific tables.

## Authentication providers

The sample UI supports Google OAuth, GitHub OAuth, and email/password auth.

- For email/password, enable the Email provider and choose whether new users
  must confirm their email address.
- For Google or GitHub, configure the provider credentials and use the
  Supabase callback URL shown below in the provider dashboard.
- Keep the application redirect URI in the Supabase allowlist when OAuth is
  enabled.

If email confirmation is enabled, sign-up returns a confirmation message and
the user can sign in after completing the email link.

## Client configuration

Copy the example file and keep the real file local:

```bash
cp config/dart-defines.example.json config/dart-defines.json
```

The client needs:

- `SUPABASE_URL`: the project URL.
- `SUPABASE_PUBLISHABLE_KEY`: the publishable/anon client key only.
- `SUPABASE_REDIRECT_URI`: the custom callback scheme.

Use the file with:

```bash
flutter run --dart-define-from-file=config/dart-defines.json
```

## OAuth callback

The sample callback is:

```text
com.example.supabasefluttertemplate://login-callback
```

If you change it, update all of these locations:

1. `config/dart-defines.json`.
2. The URL scheme in `ios/Runner/Info.plist`.
3. The deep-link intent filter in `android/app/src/main/AndroidManifest.xml`.
4. Supabase Auth → URL Configuration → Additional Redirect URLs.

For Google/GitHub, the provider dashboard still needs the Supabase callback URL:

```text
https://<your-project-ref>.supabase.co/auth/v1/callback
```

The exact provider settings, consent screen, and production domains belong to the app owner and should be reviewed before release.

## Account deletion function

Deploy the function with JWT verification enabled:

```bash
supabase functions deploy delete-account
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
```

The service-role key must remain a Supabase server secret. Do not copy it into any `.env` committed to Git, Dart define file, CI log, or mobile build.
