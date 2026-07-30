#!/bin/bash
# Rename this whitelabel template into a new app (identity only — no content).
# Run from the app root (the folder that contains project.yml).
#
#   ./scripts/rename-app.sh <OLD_TARGET> <NEW_TARGET> <new_slug> "<Display Name>"
#
# Example:
#   ./scripts/rename-app.sh PrepKitImage AsvabPrep asvabprep "ASVAB Prep"
#
# It replaces, case-sensitively:
#   - the Xcode target token  OLD_TARGET -> NEW_TARGET   (dirs, files, code)
#   - the bundle/app-group/scheme slug   old -> new_slug (app.hermesdigital.<slug>)
#   - the display name in project.yml / Info.plist
set -euo pipefail
cd "$(dirname "$0")/.."

OLD_TARGET="${1:?OLD_TARGET (e.g. PrepKitImage)}"
NEW_TARGET="${2:?NEW_TARGET (e.g. AsvabPrep)}"
NEW_SLUG="${3:?new_slug (lowercase, e.g. asvabprep)}"
DISPLAY="${4:?"Display Name" (e.g. \"ASVAB Prep\")}"

# derive the current slug from project.yml (app.hermesdigital.<slug>)
OLD_SLUG="$(grep -oE 'app\.hermesdigital\.[a-z0-9]+' project.yml | head -1 | sed 's/app.hermesdigital.//')"
[ -n "$OLD_SLUG" ] || { echo "Could not detect current slug from project.yml"; exit 1; }
echo "Renaming: target $OLD_TARGET -> $NEW_TARGET | slug $OLD_SLUG -> $NEW_SLUG | display \"$DISPLAY\""

FILES=( -type d \( -name .git -o -name '*.xcassets' -o -name '*.xcodeproj' \) -prune -o
        -type f \( -name '*.swift' -o -name '*.yml' -o -name '*.storekit'
                   -o -name '*.entitlements' -o -name '*.plist' -o -name '*.py'
                   -o -name '*.md' -o -name '*.json' -o -name 'Fastfile' -o -name 'Appfile' \) -print )

# 1) target token in file contents
while IFS= read -r f; do LC_ALL=C sed -i '' "s/${OLD_TARGET}/${NEW_TARGET}/g" "$f"; done < <(find . "${FILES[@]}")

# 2) identity slug + display name
while IFS= read -r f; do
  LC_ALL=C sed -i '' \
    -e "s/app\.hermesdigital\.${OLD_SLUG}/app.hermesdigital.${NEW_SLUG}/g" \
    -e "s/${OLD_SLUG}:\/\//${NEW_SLUG}:\/\//g" \
    -e "s/== \"${OLD_SLUG}\"/== \"${NEW_SLUG}\"/g" \
    "$f"
done < <(find . "${FILES[@]}")

# 3) rename files & dirs whose NAME contains the target token (deepest first)
find . -depth -name "*${OLD_TARGET}*" -not -path './.git/*' | while IFS= read -r p; do
  np="$(dirname "$p")/$(basename "$p" | sed "s/${OLD_TARGET}/${NEW_TARGET}/g")"
  [ "$p" != "$np" ] && mv "$p" "$np"
done

# 4) display name (best-effort; adjust in project.yml if your old display differs)
while IFS= read -r f; do LC_ALL=C sed -i '' "s/Prep Kit Image/${DISPLAY}/g; s/Prep Kit Text/${DISPLAY}/g" "$f"; done \
  < <(find . -name '*.yml' -o -name '*.plist')

echo "Done. Now: set the display name / SKU in project.yml + fastlane, then run:"
echo "  /opt/homebrew/bin/xcodegen generate"
echo "Remaining references to the old identity (should be none):"
grep -rn "${OLD_TARGET}\|hermesdigital.${OLD_SLUG}" . --include='*.swift' --include='*.yml' 2>/dev/null | grep -v './.git/' || echo "  ✓ none"
