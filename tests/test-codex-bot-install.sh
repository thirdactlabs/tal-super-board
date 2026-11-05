#!/usr/bin/env bash
# Tests scripts/super-board-codex-bot-install.sh: the Codex trigger workflow is written with the
# base branch filled in, drafts are skipped, no merge workflow is ever written, and an existing
# different file is never overwritten without --force. Offline.
#
#   bash tests/test-codex-bot-install.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/super-board-codex-bot-install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ✅ %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  ❌ %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()  { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "contains: $3" "$2" ;; esac; }
hasnt() { case "$2" in *"$3"*) bad "$1" "absent: $3" "$2" ;; *) ok "$1" ;; esac; }

cd "$WORK"
mkdir cfg
echo '{"version":1,"base_branch":"staging"}' > cfg/staging.json
echo '{"version":1}' > cfg/nobase.json
printf '// note\n{"version":1,"base_branch":"board-test"}\n' > cfg/commented.json
echo '{"version":1,"base_branch":"a b;rm"}' > cfg/unsafe.json

echo "staging base: trigger written, base filled in"
OUT=$(bash "$SCRIPT" --config cfg/staging.json --out w1 2>&1); RC=$?
is "exit 0" 0 "$RC"
is "only the trigger is written" "codex-review-trigger.yml" "$(ls w1)"
hasnt "no placeholder left" "$(cat w1/codex-review-trigger.yml)" "__"
has "trigger filters the base" "$(cat w1/codex-review-trigger.yml)" "branches: [staging]"
has "trigger fires on ready_for_review" "$(cat w1/codex-review-trigger.yml)" "ready_for_review"
has "trigger skips drafts" "$(cat w1/codex-review-trigger.yml)" "draft == false"
has "trigger posts @codex review" "$(cat w1/codex-review-trigger.yml)" '"@codex review"'
has "prints the secret reminder" "$OUT" "CODEX_REVIEW_TOKEN"
has "says the project's workflow is the only merger" "$OUT" "only merger"
if python3 -c 'import yaml' 2>/dev/null; then
  python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' w1/codex-review-trigger.yml && ok "parses as YAML" || bad "parses as YAML" ok failed
fi

echo "base defaults and comment lines"
bash "$SCRIPT" --config cfg/nobase.json --out w2 >/dev/null 2>&1
has "no base_branch: main" "$(cat w2/codex-review-trigger.yml)" "branches: [main]"
bash "$SCRIPT" --config cfg/commented.json --out w3 >/dev/null 2>&1
has "base read through // comments" "$(cat w3/codex-review-trigger.yml)" "branches: [board-test]"

echo "existing files"
bash "$SCRIPT" --config cfg/staging.json --out w1 >/dev/null 2>&1; is "rerun is idempotent" 0 $?
echo "# edited" >> w1/codex-review-trigger.yml
bash "$SCRIPT" --config cfg/staging.json --out w1 >/dev/null 2>&1; RC=$?
is "a different file is refused" 1 "$RC"
has "refused file is untouched" "$(tail -1 w1/codex-review-trigger.yml)" "# edited"
bash "$SCRIPT" --config cfg/staging.json --out w1 --force >/dev/null 2>&1; is "--force replaces it" 0 $?
hasnt "forced file is the template again" "$(cat w1/codex-review-trigger.yml)" "# edited"

echo "bad input"
bash "$SCRIPT" --config cfg/unsafe.json --out w4 >/dev/null 2>&1; is "unsafe base refused" 65 $?
bash "$SCRIPT" --config cfg/none.json --out w5 >/dev/null 2>&1; is "missing config" 66 $?
bash "$SCRIPT" --bogus >/dev/null 2>&1; is "unknown arg" 64 $?

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
