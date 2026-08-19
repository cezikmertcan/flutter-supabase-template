# Contributing

Thanks for helping improve the template.

## Before opening a pull request

```bash
dart format lib test
flutter analyze
flutter test
bash tool/check_secrets.sh
```

Keep changes focused, explain the trade-offs in the pull request, and add tests for behavior that can be verified without a device simulator.

## Pull requests

- Use a short, imperative title.
- Explain what changed and why.
- Call out database migrations, RLS changes, native configuration, or release notes.
- Do not include credentials, signing files, production user data, or private screenshots.
- Prefer one coherent change per pull request so it can be reviewed and reverted safely.
