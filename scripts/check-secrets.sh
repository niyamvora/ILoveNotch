#!/usr/bin/env bash
# Secret gate, run by `make check` and CI: fails if a signing key, certificate, provisioning
# profile, private key, or App Store Connect key reference is tracked by git. Release credentials
# live outside the repository (release.env points at them; see docs/releasing.md).
set -euo pipefail
cd "$(dirname "$0")/.."

status=0

# Files that must never be committed.
while IFS= read -r file; do
    echo "error: $file looks like a key, certificate, profile, or credentials file; it must not be committed"
    status=1
done < <(git ls-files --cached --others --exclude-standard |
    grep -E '\.(p8|p12|pfx|cer|pem|key|mobileprovision|provisionprofile|keychain-db)$|(^|/)(release\.env|\.env(\..*)?)$' |
    grep -vE '\.example$' || true)

# Private key blocks, and App Store Connect key file names with a real key ID (not the X placeholder).
while IFS= read -r match; do
    echo "error: ${match%%:*} contains a private key or an App Store Connect key reference"
    status=1
done < <(git grep -nIE -e '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' -e '(AuthKey|ApiKey)_[A-Z0-9]{10,}\.p8' \
    -- ':!scripts/check-secrets.sh' | grep -vE '(AuthKey|ApiKey)_X+\.p8' || true)

[[ $status -eq 0 ]] && echo "secrets OK"
exit $status
