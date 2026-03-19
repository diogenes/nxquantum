#!/usr/bin/env bash
set -euo pipefail

out=".vscode/cucumber-glue/steps.js"
mkdir -p "$(dirname "$out")"

{
  echo "// Generated from features/*.feature for VSCode Cucumber step discovery."
  echo "// Do not hand-edit. Regenerate with: ./scripts/generate_cucumber_glue.sh"
  echo "/* global Given, When, Then */"
  echo
  rg --no-filename '^[[:space:]]*(Given|When|Then|And|But)[[:space:]]+' features/*.feature \
    | sed -E 's/^[[:space:]]*//' \
    | sed -E 's/^(And|But)[[:space:]]+/Given /' \
    | sort -u \
    | while IFS= read -r line; do
        keyword="${line%% *}"
        text="${line#* }"
        escaped="$(printf '%s' "$text" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
        printf '%s("%s", function () {});\n' "$keyword" "$escaped"
      done
} > "$out"

echo "Wrote $out"
