# Security policy

## Scope

This repository is a template. Before using it with real users, review every migration, policy, Edge Function, provider setting, and analytics event for the intended product.

## Secrets

Never commit:

- Supabase service-role or secret keys.
- OAuth client secrets.
- Store signing certificates, keystores, provisioning profiles, or passwords.
- Production data, access tokens, session cookies, or personal user exports.

The mobile app may use a publishable/anon key, but this template still expects it through local build-time configuration rather than source control. The service-role key belongs only in Supabase Edge Function secrets.

## Reporting

Do not open a public issue for an active vulnerability. Contact the repository maintainers privately with reproduction steps, impact, and a safe contact method. Remove credentials from logs and rotate any exposed key immediately.
