# Codex-bot review (Reviewer lane, `pr_review: "codex-bot"`)

Opt-in. Config key `"pr_review": "gate"` (default) keeps the Reviewer's own review and the
merge gate. `"codex-bot"` makes the Codex GitHub review bot the reviewer and a repo workflow
the merger. Same shape as shipmaxxing: **the lane reviews before the PR is raised, drives the
bot's findings to closure, never merges, and confirms the merge landed.**

"Codex" here is the GitHub review bot. It is unrelated to the Codex CLI host
(`super-board-codex-lane.sh`, config `host`).

## One-time setup (per repo)

1. The project already has the Codex pieces its other repos use: the Codex GitHub app, the
   `CODEX_REVIEW_TOKEN` secret, a trigger workflow that posts `@codex review`, and a
   `merge-after-codex-review` workflow that squash-merges after Codex's clean comment. Super-board
   ships **no merger of its own**: that workflow is the only thing that merges, and the merge
   gate and `merge_policy` do not run in this mode.
2. The trigger must **skip drafts and also fire on `ready_for_review`** (see below). Missing, or
   the project's own fires on drafts: `.claude/bin/super-board-codex-bot-install.sh --config
   .claude/super-board/configs/<slug>.json` writes `codex-review-trigger.yml` with the base branch
   filled in. It refuses to overwrite a different file without `--force`; for an existing
   project trigger, make the same two edits by hand.
3. Merge the trigger to the board's base branch (`pull_request_target` runs from the PR's base).
4. Set `"pr_review": "codex-bot"` in the config.

## The project's workflows

| Workflow | Needed behaviour |
|---|---|
| Trigger | Posts `@codex review` when a PR is **ready for review** and on every push after that. **Not on a draft.** |
| Merge | Merges after the bot's clean comment (`**Reviewed commit:**`) for the current head. Super-board does not touch it. |

Why the trigger must skip drafts: the Builder opens a draft and QA pushes to it. A trigger that
fires on `opened` spends a Codex round on that draft, and Codex's clean comment on a draft head
is consumed: the merge workflow cannot merge a draft, and `gh pr ready` fires nothing, so the PR
would sit clean and unmerged. With the draft skipped, `gh pr ready` is the moment Codex runs.

Tradeoff of using the project's merge workflow as it is: money, auth, schema and large PRs
auto-merge too, because that workflow has no policy check.

## Reviewer lifecycle in this mode

Replaces run.md → Reviewer steps 3, 3b, 4, 6 and 7 and the merge protocol. Steps 1–2 (worktree,
Gate 1 thread scan) and 5 (test rerun) are unchanged.

1. **Installed?** `git ls-tree origin/<base> .github/workflows/` shows no workflow containing
   `@codex review` → Blocked `🔐 codex-bot not installed`, with the install command from setup step 2.
2. **Review before the PR is raised.** One pass, no loop:
   - `FP=$(git merge-base HEAD origin/<base>)`. Spec file: the issue title, body and ACs.
   - Invoke `mattpocock-skills:code-review` with `FP` and the spec file.
   - Standards findings: fix the documented violations. Spec findings: remove scope creep, fix a
     requirement implemented wrongly. An AC gap that cannot close within the card → Blocked 🙋
     (human gate, block template).
   - Commit each fix by file name, then rerun `verify_commands`. A new failure → `[qa]` thread
     and card to QA, as in Reviewer step 5.
3. **Sync with the base.** `git fetch origin && git merge origin/<base>` (never a force push).
   A conflict that is not mechanical → `loop:rebase`, per run.md → "The rebase pass".
   The merge changed any file → rerun `verify_commands` once before the push; a new failure is handled
   as in step 2 (pre-existing ones: run.md → "Pre-existing failures").
4. **Raise the PR.** `git push`, then `gh pr ready <PR>`. The trigger workflow fires now.
5. **Codex loop.** Before using the helper, `super-board-skills-ready.py --require super-pr-loop`. Run `/super-pr-loop <PR>` inline, in this agent. Never `ScheduleWakeup` or
   `/loop`. Its stops map to the board:

   | `super-pr-loop` result | Card |
   |---|---|
   | clean (the bot's `**Reviewed commit:**` comment on the head, no open thread), or `MERGED` | continue to step 6 |
   | `🛡 round-cap` (3 fix passes) | Blocked, block template |
   | `🙋 needs-decision` | Blocked, the question, options and recommendation |
   | `⏱ no-codex-review` (neither a review nor a clean comment on the head) | Blocked: is the app installed, is the secret set? |
   | `🧪 tests` | `[qa]` thread, card to QA |

6. **Confirm the merge.** Never `gh pr merge`, never the merge gate. Poll about every 60 s for up
   to 15 minutes: `gh pr view <PR> --json state,mergeCommit,mergeStateStatus`. On `MERGED`:
   `git fetch origin <base> && git merge-base --is-ancestor <sha> origin/<base>` must pass.
   - Still `OPEN` at 15 minutes: Blocked `⏱ not merged`. Quote `mergeStateStatus`, any failing
     check, and whether the bot's clean comment is on the head. The human merges or fixes it.
7. **Close out** as run.md → Merge protocol step 4: close the issue, card Review → Done, rewrite
   `status` and `history`, post `[reviewer] [report] ✅ merged` citing the merge commit. The card
   **never** reaches Done before step 6 passes.

The Reviewer report (writing-standard.md § 4) is still one comment per PR, edited in place. Its
`Did:` line names the code-review pass and the Codex rounds; findings Codex raised are rows
owned by `builder` with the Status the loop reached.

## Not in this mode

The independent hypothesis pass, the adversarial truth-check and `truth_threshold`, and the
merge gate and `merge_policy`. Codex is the second reviewer and the project's workflow merges.
