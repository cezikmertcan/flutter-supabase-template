# Release checklist

Complete this checklist before making an app built from the template public or shipping it to a store.

## Repository

- [ ] Replace the sample app name, package name, bundle identifier, icons, and launch screen.
- [ ] Remove example screens and sample state that do not belong in the product.
- [ ] Add a privacy policy, terms where required, support contact, and data-retention policy.
- [ ] Review the license of every dependency and asset added to the project.
- [ ] Confirm no secrets, signing files, personal identifiers, or private project references are tracked.

## Supabase

- [ ] Apply and review all migrations in the intended project.
- [ ] Confirm RLS is enabled on every user-facing table.
- [ ] Test authenticated reads/writes with a non-admin account.
- [ ] Deploy Edge Functions and set secrets only through Supabase secrets.
- [ ] Confirm account deletion behavior and data-retention requirements.
- [ ] Review Auth providers, email settings, redirect URLs, and rate limits.

## Mobile

- [ ] Configure real iOS and Android identifiers and signing certificates.
- [ ] Configure deep links for the production scheme.
- [ ] Review release build flags and remove debug-only UI.
- [ ] Build and smoke-test on supported real devices or approved CI device coverage.
- [ ] Verify store metadata, screenshots, privacy declarations, and support links.

## Verification

- [ ] Run `dart format --set-exit-if-changed lib test`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Run `bash tool/check_secrets.sh`.
- [ ] Review the final diff and GitHub Actions result.
