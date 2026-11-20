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
2. The project's own trigger works as it is: this mode raises the PR already marked ready and never
   as a draft (see "Before the PR"), so it fires exactly when the PR is created and on every push
   after. Only a project with no trigger needs one:
   `.claude/bin/super-board-codex-bot-install.sh --config .claude/super-board/configs/<slug>.json`
   writes `codex-review-trigger.yml` with the base branch filled in.
3. A trigger the installer wrote must be on the board's base branch (`pull_request_target` runs from the PR's base).
4. Set `"pr_review": "codex-bot"` in the config.

## The project's workflows

| Workflow | Needed behaviour |
|---|---|
| Trigger | Posts `@codex review` when a PR opens and on every push after that. |
| Merge | Merges after the bot's clean comment (`**Reviewed commit:**`) for the current head. Super-board does not touch it. |

Why there is no draft PR: the merge workflow merges any non-draft PR once Codex is clean, and the
trigger reviews on every open and push. A PR opened at build time would spend Codex rounds on
unfinished work and could merge before QA and review finish. So the PR does not exist until the
Reviewer raises it.

Tradeoff of using the project's merge workflow as it is: money, auth, schema and large PRs
auto-merge too, because that workflow has no policy check.

## Reviewer lifecycle in this mode

Replaces run.md → Reviewer steps 3, 3b, 4, 6 and 7 and the merge protocol. Steps 1 (worktree) and
5 (test rerun) are unchanged; step 2 (Gate 1) reads the issue report, see "Before the PR".

1. **Installed?** `git ls-tree origin/<base> .github/workflows/` shows no workflow containing
   `@codex review` → Blocked `codex-bot not installed`, with the install command from setup step 2.
2. **Review before the PR is raised.** One pass, no loop:
   - `FP=$(git merge-base HEAD origin/<base>)`. Spec file: the issue title, body and ACs.
   - Invoke `mattpocock-skills:code-review` with `FP` and the spec file.
   - Standards findings: fix the documented violations. Spec findings: remove scope creep, fix a
     requirement implemented wrongly. An AC gap that cannot close within the card → Blocked needs-you
     (human gate, block template).
   - Commit each fix by file name, then rerun `verify_commands`. A new failure → a `[qa]` finding line
     in the issue report and card to QA, as in Reviewer step 5.
3. **Sync with the base.** `git fetch origin && git merge origin/<base>` (never a force push).
   A conflict that is not mechanical → `loop:rebase`, per run.md → "The rebase pass".
   The merge changed any file → rerun `verify_commands` once before the push; a new failure is handled
   as in step 2 (pre-existing ones: run.md → "Pre-existing failures").
4. **Raise the PR, ready, never a draft.** `git push`, then `gh pr create --base <base> --head
   issue-<N>-<slug>`: title in the commit-subject format, body = run.md → "PR description template"
   with every block filled once from the issue reports (see "Before the PR"). Post the
   [PR author notes](pr-author-notes.md). The project's trigger fires on the open.
5. **Codex loop.** Before using the helper, `super-board-skills-ready.py --require super-pr-loop`. Run `/super-pr-loop <PR>` inline, in this agent. Never `ScheduleWakeup` or
   `/loop`. Its stops map to the board:

   | `super-pr-loop` result | Card |
   |---|---|
   | clean (the bot's `**Reviewed commit:**` comment on the head, no open thread), or `MERGED` | continue to step 6 |
   | `round-cap` (3 fix passes) | Blocked, block template |
   | `needs-decision` | Blocked, the question, options and recommendation |
   | `no-codex-review` (neither a review nor a clean comment on the head) | Blocked: is the app installed, is the secret set? |
   | `tests` | `[qa]` thread, card to QA |

6. **Confirm the merge.** Never `gh pr merge`, never the merge gate. Poll about every 60 s for up
   to 15 minutes: `gh pr view <PR> --json state,mergeCommit,mergeStateStatus`. On `MERGED`:
   `git fetch origin <base> && git merge-base --is-ancestor <sha> origin/<base>` must pass.
   - Still `OPEN` at 15 minutes: Blocked `not merged`. Quote `mergeStateStatus`, any failing
     check, and whether the bot's clean comment is on the head. The human merges or fixes it.
7. **Close out** as run.md → Merge protocol step 4: close the issue, card Review → Done, rewrite
   `status` and `history`, post `[reviewer] [report] merged` citing the merge commit. The card
   **never** reaches Done before step 6 passes.

The Reviewer report (writing-standard.md § 4) is still one comment per PR, edited in place. Its
`Did:` line names the code-review pass and the Codex rounds; findings Codex raised are rows
owned by `builder` with the Status the loop reached.

## Before the PR (no PR until Review)

This applies while no PR exists. A card that comes back with a PR already open (a `tests` or
`not merged` return) uses the PR threads and blocks exactly as run.md says.

Builder and Tester work on the pushed branch `issue-<N>-<slug>`; their state lives in issue
comments. Where run.md says PR comment, post an issue comment; where it says PR thread, write a
finding line in the lane's issue report; where it says PR body block, put that content in the
lane's issue report. The Reviewer copies it into the PR body once, when it raises the PR.

| run.md says | In this mode |
|---|---|
| Builder step 6: open a draft PR | Push the branch only. No PR. |
| Builder steps 7–8: author notes, `[builder] [report]` on the PR, status comment with the PR URL | One `[builder] [report]` on the issue, with the text the `problem` and `solution` blocks will need, and the branch name instead of a URL. Author notes wait for the PR. |
| Size-cap split proposal "in a PR comment" | An issue comment. |
| Tester: read the PR and the Builder's PR comment | Read the issue and the Builder's issue report. The diff is `git diff origin/<base>...origin/issue-<N>-<slug>`. |
| Tester: tick the `ac` block, write `visual`, `history`, `status` | One `[qa] [report]` on the issue: per-AC proof lines, the screenshot table, the `history` row, the `Local tests:` line. No PR comment. |
| `[builder]` / `[qa]` PR threads, from the security pass or a review | A finding line `[builder] <file:line> — <finding>` in the lane's issue report. |
| `pr-security-review` on the PR | On the branch diff against `config.base_branch`, not `gh pr view`. |
| Rebuild: read and resolve `[builder]` / `[qa]` threads | Read the open finding lines in the latest issue report (QA's or the Reviewer's). The rebuild report cites a fix sha for each. |
| Reviewer Gate 1: scan PR threads | The latest lane report on the issue has no open finding line. No PR thread exists yet. |
| Reviewer report, edited in place on the PR | The same marker comment, edited in place, on the issue. |

Raising the PR (lifecycle step 4) writes the body from those reports: `status` for Review,
`problem` and `solution` from the Builder report, `ac` ticked from QA's proof lines, `visual` from
QA's screenshots, one `history` row per lane report, `risk` from the Builder. From then on each
lane rewrites only its own block with `super-board-pr-body.sh`, as run.md says.

Pre-flight (run.md → "Builder pre-flight") finds no open PR for a card in Building or QA. For each
in-flight card also compare the changed files of its remote branch (`git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/issue-<M>-*'`, then `git diff --name-only origin/<base>...<that ref>`) with the
files the new card names.

## Not in this mode

The independent hypothesis pass, the adversarial truth-check and `truth_threshold`, and the
merge gate and `merge_policy`. Codex is the second reviewer and the project's workflow merges.
