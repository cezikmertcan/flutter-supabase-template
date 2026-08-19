#!/usr/bin/env bash

set -euo pipefail

if command -v rg >/dev/null 2>&1; then
  search=(rg -n --hidden -g '!.git/**' -g '!config/dart-defines.example.json' -g '!**/check_secrets.sh')
else
  search=(grep -RIn --exclude-dir=.git --exclude=config/dart-defines.example.json --exclude=check_secrets.sh)
fi

patterns=(
  'sb_(publishable|secret)_[A-Za-z0-9_-]{20,}'
  'SUPABASE_SERVICE_ROLE_KEY=[^<[:space:]][^[:space:]]{8,}'
  'AKIA[0-9A-Z]{16}'
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
  'gh[pousr]_[A-Za-z0-9_]{20,}'
)

found=0
for pattern in "${patterns[@]}"; do
  if "${search[@]}" -e "$pattern" .; then
    found=1
  fi
done

if [[ "$found" -ne 0 ]]; then
  echo "Potential secret pattern found. Remove it before committing."
  exit 1
fi

echo "No supported secret patterns found."
