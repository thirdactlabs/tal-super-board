#!/usr/bin/env bash
# super-board-codex-bot-install.sh — write the one GitHub workflow that asks the Codex review
# bot to review a board PR once it is ready (config pr_review "codex-bot").
#
#   super-board-codex-bot-install.sh --config <cfg.json> [--out .github/workflows] [--force]
#
# Run from the repo root. Fills the base branch into skills/super-board/templates/codex-bot/
# codex-review-trigger.yml. Never overwrites a different existing file without --force.
# Ships no merge workflow: the project's own merge-after-codex-review workflow merges.
set -euo pipefail

CONFIG=""; OUT=".github/workflows"; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2:-}"; shift 2 ;;
    --out)    OUT="${2:-}"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    -h|--help) sed -n 2,9p "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done
[ -n "$CONFIG" ] && [ -f "$CONFIG" ] || { echo "config not found: ${CONFIG:-<unset>}" >&2; exit 66; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$HERE/../skills/super-board/templates/codex-bot/codex-review-trigger.yml"
[ -f "$TPL" ] || { echo "template not found: $TPL" >&2; exit 66; }

BASE="$(python3 - "$CONFIG" <<'PY'
import json, re, sys
c = json.loads(re.sub(r'(?m)^\s*//.*$', '', open(sys.argv[1]).read()))
print(c.get("base_branch") or "main")
PY
)"
case "$BASE" in *[!A-Za-z0-9._/-]*|"") echo "unsafe base_branch: $BASE" >&2; exit 65 ;; esac

mkdir -p "$OUT"
DEST="$OUT/codex-review-trigger.yml"
TMP="$(mktemp)"
sed "s|__BASE__|$BASE|g" "$TPL" > "$TMP"
if [ -f "$DEST" ] && ! cmp -s "$TMP" "$DEST" && [ "$FORCE" -eq 0 ]; then
  rm -f "$TMP"; echo "✗ $DEST exists and differs — rerun with --force to replace" >&2; exit 1
fi
mv "$TMP" "$DEST"
echo "✓ $DEST (base: $BASE)"

cat <<EOF

Still yours to do:
  1. Merge it to $BASE (pull_request_target runs from the PR's base branch).
  2. The repo needs the CODEX_REVIEW_TOKEN secret and the Codex GitHub app.
  3. Keep the project's own merge-after-codex-review workflow: it is the only merger.
  4. Set "pr_review": "codex-bot" in the board config.
EOF
