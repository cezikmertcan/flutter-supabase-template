# FlashCard AI

FlashCard AI is a guided study workspace for any topic. The user starts with a free-form prompt, then continues through compact AI-generated choices: flashcards, quizzes, topic maps, study plans, source-based study, and export.

The app is intentionally topic-agnostic. “Backend .NET”, “KPSS”, a language, a certification, or a user-provided document are all inputs to the same study engine.

## Product flow

```text
free-form topic or goal
  → guided assistant message
  → action buttons / custom input
  → flashcards, quiz, map, or plan
  → saved Library artifact
  → repeat, edit, review, and track progress
```

The assistant response is designed as structured data: a message, a list of next actions, and an optional generated artifact. This keeps the interface conversational while making every button an explicit product action.

## Included foundation

- Flutter iOS and Android application shell.
- Dark-first matrix visual system with green accents and monospace metadata labels.
- Local-first conversation and Library persistence using `shared_preferences`.
- Guided flashcard, quiz, topic-map, and study-plan flows that work without network configuration.
- Supabase Auth hooks with Google OAuth, profile creation, account deletion, and debounced state sync.
- RLS-protected conversations, messages, and Library artifact migrations.
- JWT-protected `study-assistant` Edge Function boundary for server-side AI calls.
- Allowlisted, low-risk analytics foundation and secret-pattern CI checks.

## Run locally

```bash
flutter pub get
cp config/dart-defines.example.json config/dart-defines.json
# Add the FlashCard AI Supabase URL and publishable key.
flutter run --dart-define-from-file=config/dart-defines.json
```

Without Supabase configuration, local mode remains usable. Sign-in, cloud sync, and the server-side assistant require a configured project.

## Supabase

The project expects a dedicated Supabase project named **FlashCard AI**. Apply the migrations with:

```bash
supabase link --project-ref <flashcard-ai-project-ref>
supabase db push
supabase functions deploy delete-account
supabase functions deploy study-assistant
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<server-only-key>
supabase secrets set GEMINI_API_KEY=<server-only-key>
supabase secrets set GEMINI_MODEL=gemini-3.5-flash-lite
```

Only a publishable/anon key belongs in the Flutter app. The service-role key and Gemini provider key stay in Supabase secrets.

The callback URI is:

```text
com.futurefry.flashcardai://login-callback
```

Keep it aligned across `config/dart-defines.json`, iOS, Android, and Supabase Auth URL configuration.

## Project structure

```text
lib/
  core/       Theme and runtime configuration
  models/     Topic-agnostic study entities
  screens/    Studio, Library, and settings UI
  services/   Auth, local store, sync, and study flow
supabase/
  migrations/ RLS-protected profile and study data
  functions/  Account deletion and structured AI boundary
test/         Host-side widget and service tests
```

## Verification

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
bash tool/check_secrets.sh
```

The app is local-first, but generated content should still be reviewed before being used for official exam preparation. Source-grounded content and official answer keys should take priority over unverified model output.
