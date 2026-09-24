#!/usr/bin/env bash
# License gate, run by `make licenses` and CI:
#   1. every Swift file carries the MIT SPDX header (provenance of original code)
#   2. every resolved package dependency is listed in THIRD_PARTY_NOTICES.md
set -euo pipefail
cd "$(dirname "$0")/.."

status=0

while IFS= read -r file; do
    if ! head -n 3 "$file" | grep -q 'SPDX-License-Identifier: MIT'; then
        echo "error: $file is missing the '// SPDX-License-Identifier: MIT' header"
        status=1
    fi
done < <(git ls-files --cached --others --exclude-standard '*.swift')

# SwiftPM's pins, plus Xcode's once `make build` has resolved the app's packages.
for resolved in Package.resolved OpenNotch.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved; do
    [[ -f "$resolved" ]] || continue
    while IFS= read -r package; do
        if ! grep -qi -- "$package" THIRD_PARTY_NOTICES.md; then
            echo "error: dependency '$package' ($resolved) is not listed in THIRD_PARTY_NOTICES.md"
            status=1
        fi
    done < <(sed -n 's/.*"identity" *: *"\([^"]*\)".*/\1/p' "$resolved")
done

[[ $status -eq 0 ]] && echo "licenses OK"
exit $status
