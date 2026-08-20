# Architecture

FlashCard AI keeps the learning engine generic and lets the prompt define the domain.

## Runtime flow

```text
main()
  ├─ LocalStateStore.load()       presentation preferences
  ├─ FlashCardAiStore.load()      local conversation + Library
  ├─ AuthService.initialize()     optional Supabase session
  ├─ RemoteStateSyncService       authenticated state sync
  └─ FlashCardAiApp
       ├─ Studio                   guided conversation and actions
       ├─ Library                  persisted artifacts
       └─ Settings                 Google auth, theme, sync, deletion
```

## Guided assistant contract

The assistant is not treated as an unstructured chat-only endpoint. Each turn can contain:

- `message`: the natural-language response.
- `actions`: stable IDs, labels, and optional descriptions for the next buttons.
- `artifact`: an optional flashcard set, quiz, topic map, or study plan.

The Flutter client can render the same interaction whether it is using the local fallback or the Supabase `study-assistant` Edge Function. When configured, that function sends the authenticated turn to Gemini and returns the same contract.

## Data boundaries

`FlashCardAiStore` is the local source of truth for the current MVP. It persists versioned JSON so the product remains usable offline. `RemoteStateSyncService` syncs the same versioned payload to the authenticated `user_state` row.

The Supabase migrations also create normalized, RLS-protected tables for the next persistence step:

- `study_conversations`
- `study_messages`
- `study_artifacts`

As the Library grows, those tables can replace the single payload sync without changing the UI contract.

## AI boundary

The mobile app never receives an AI provider secret. `study-assistant` verifies the Supabase bearer session, sends the recent conversation and optional source text to Gemini, and returns the strict assistant contract. The function must remain source-aware and should not invent official exam answers.

## Extension rules

- Do not add hard-coded product areas for KPSS, .NET, or another domain; store the user’s topic and source as data.
- Keep generated artifacts editable and versionable.
- Save selected action IDs as part of conversation history.
- Add RLS policies before adding a user-facing table.
- Keep PDF parsing and export behind services so the mobile UI is not coupled to a provider.
