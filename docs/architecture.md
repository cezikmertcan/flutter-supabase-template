# Architecture

The template keeps the application layer small and makes infrastructure easy to replace.

## Runtime flow

```text
main()
  ├─ LocalStateStore.load()
  ├─ AuthService.initialize()
  ├─ RemoteStateSyncService.start()
  └─ SupabaseFlutterTemplateApp
       └─ HomeScreen
            ├─ authentication actions
            ├─ local-first sample state
            └─ remote sync status
```

## Boundaries

### `AppConfig`

Reads build-time values only. It deliberately has no project URL, key, or account-specific fallback. A missing configuration keeps the demo usable but disables network actions.

### `AuthService`

Owns the Supabase client, the current session, OAuth entry points, profile creation, sign-out, and account deletion. Widgets do not handle service-role operations or raw auth state streams.

### `LocalStateStore`

Is the immediate source of truth for the example state. Replace its sample fields with a domain model or a dedicated persistence layer when building a product.

### `RemoteStateSyncService`

Listens to auth and local-state changes, fetches the authenticated `user_state` row, merges the payload, and writes it back with a short debounce. The sample behavior is intentionally simple; conflict resolution should be designed for each product’s data model.

### Supabase database

The migrations create private-by-default tables. Every client-facing policy is scoped to the authenticated user. The account-deletion function uses a service-role key only on the server and deletes account-owned analytics rows before removing the auth user.

## Extension guidance

- Keep feature code under `lib/features/<feature>/` when the product grows beyond the sample screens.
- Keep Supabase reads and writes in repositories or services rather than in widgets.
- Treat local payloads as versioned data and write migrations when their shape changes.
- Add RLS policies before shipping a new table; do not rely on the client to filter rows.
- Keep analytics event names allowlisted and avoid free text, health data, and identifiers that are not needed for the product decision.
