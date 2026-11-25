# Codex-bot review (Reviewer lane, `pr_review: "codex-bot"`)

Opt-in. Config key `"pr_review": "gate"` (default) keeps the Reviewer's own review and the
merge gate. `"codex-bot"` is the shipmaxxing shape: **the lane reviews before the PR is raised,
raises it ready, fixes whatever the repo's Codex review finds, and leaves the merge to the repo.**

Super-board installs nothing and never assumes the repo has Codex or an auto-merge. It detects
both at run time and works either way:

| The repo has | The lane does |
|---|---|
| A Codex review (the bot comments on the PR) | Drives its findings to closure with `/super-pr-loop` (max 3 fix passes). |
| No Codex review | Nothing to fix. The PR is raised and the lane moves on. Not a block. |
| An auto-merge (a merge workflow, or GitHub auto-merge on the PR) | Confirms the merge landed, then closes the card. |
| No auto-merge | Leaves the PR ready and open for a human to merge. Not a block. |

"Codex" here is the GitHub review bot. It is unrelated to the Codex CLI host
(`super-board-codex-lane.sh`, config `host`).

Why there is no draft PR: a repo's merge workflow may merge any non-draft PR once Codex is clean,
and its trigger may review on every open and push. A PR opened at build time would spend review
rounds on unfinished work and could merge before QA and review finish. So the PR does not exist
until the Reviewer raises it.

Tradeoff when the repo auto-merges: money, auth, schema and large PRs merge too, because the
repo's workflow has no policy check. The merge gate and `merge_policy` do not run in this mode.

## Reviewer lifecycle in this mode

Replaces run.md → Reviewer steps 3, 3b, 4, 6 and 7 and the merge protocol. Steps 1 (worktree) and
5 (test rerun) are unchanged; step 2 (Gate 1) reads the issue report, see "Before the PR".

0. **Resume check, first.** `gh pr list --head issue-<N>-<slug> --state all --json number,state`.
   A PR already exists (an earlier pass raised it) → skip to "Resuming" below; do not review,
   sync or raise again.
1. **Review before the PR is raised.** One pass, no loop:
   - `FP=$(git merge-base HEAD origin/<base>)`. Spec file: the issue title, body and ACs.
   - Invoke `mattpocock-skills:code-review` with `FP` and the spec file.
   - Standards findings: fix the documented violations. Spec findings: remove scope creep, fix a
     requirement implemented wrongly. An AC gap that cannot close within the card → Blocked needs-you
     (human gate, block template).
   - Commit each fix by file name, then rerun `verify_commands`. A new failure → a `[qa]` finding line
     in the issue report and card to QA, as in Reviewer step 5.
2. **Sync with the base.** `git fetch origin && git merge origin/<base>` (never a force push).
   A conflict that is not mechanical → `loop:rebase`, per run.md → "The rebase pass".
   The merge changed any file → rerun `verify_commands` once before the push; a new failure is handled
   as in step 1 (pre-existing ones: run.md → "Pre-existing failures").
3. **Raise the PR, ready, never a draft.** `git push`, then `gh pr create --base <base> --head
   issue-<N>-<slug>`: title in the commit-subject format, body = run.md → "PR description template"
   with every block filled once from the issue reports (see "Before the PR"). Post the
   [PR author notes](pr-author-notes.md). If the repo has a Codex trigger it fires on the open.
4. **Codex loop, only if the repo has a Codex review.** Run `/super-pr-loop <PR>` inline, in this
   agent (`super-board-skills-ready.py --require super-pr-loop` first). Never `ScheduleWakeup` or
   `/loop`. It waits for a Codex review, fixes what it raises, and stops on one of:

   | `super-pr-loop` result | Card |
   |---|---|
   | clean (the bot's `**Reviewed commit:**` comment on the head, no open thread), or `MERGED` | continue to step 5 |
   | `no-codex` (no Codex review appeared: the repo has none) | continue to step 5. Say so in the report. Not a block. |
   | `round-cap` (3 fix passes) | Blocked, block template |
   | `needs-decision` | Blocked, the question, options and recommendation |
   | `tests` | `[qa]` thread, card to QA |

5. **Merge, if the repo merges by itself.** Never `gh pr merge`, never the merge gate. Auto-merge
   exists when `gh pr view <PR> --json autoMergeRequest` is set, or `origin/<base>` has a
   workflow that merges PRs (`git grep -lE 'gh pr merge|enablePullRequestAutoMerge|auto-merge'
   origin/<base> -- .github/workflows`).
   - **Auto-merge exists:** poll about every 60 s for up to 15 minutes:
     `gh pr view <PR> --json state,mergeCommit,mergeStateStatus`. On `MERGED`,
     `git fetch origin <base> && git merge-base --is-ancestor <sha> origin/<base>` must pass.
     Still `OPEN` at 15 minutes: handle it as "no auto-merge" below, and quote `mergeStateStatus`
     and any failing check in the report.
   - **No auto-merge, or not merged in time:** the PR stays ready and open for a human to merge.
     Edit the `[reviewer] [report]` to `in progress · PR #<N> is ready, waiting for a human
     merge`. Label the issue `awaiting-merge` (`gh label create awaiting-merge --force` first; the
     planner leaves such cards out of a wave). The card stays in Review. It is not Blocked and not
     Done. Stop here.
6. **Close out** on `MERGED` (by the workflow or by a human) as run.md → Merge protocol step 4:
   close the issue, remove the `awaiting-merge` label, card Review → Done, rewrite `status` and `history`, post `[reviewer]
   [report] merged` citing the merge commit. The card **never** reaches Done before the merge
   is confirmed.

**Resuming.** A Review card whose PR is already raised is not reviewed again. Check `state`:
`MERGED` → step 6; `OPEN` with the Codex loop not yet finished (no `[reviewer] [report]` saying
`waiting for a human merge`) → continue at step 4; `OPEN` and waiting → leave it and move on;
`CLOSED` unmerged → Blocked `PR closed`, the human decides. Cards that depend on it
(`## Blocked by`) wait until it is Done.

The Reviewer report (writing-standard.md § 4) is still one comment per PR, edited in place. Its
`Did:` line names the code-review pass and the Codex rounds; findings Codex raised are rows
owned by `builder` with the Status the loop reached.

## Before the PR (no PR until Review)

This applies while no PR exists. A card that comes back with a PR already open (a `tests` return or a resume) uses the PR threads and blocks exactly as run.md says.

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

Raising the PR (lifecycle step 3) writes the body from those reports: `status` for Review,
`problem` and `solution` from the Builder report, `ac` ticked from QA's proof lines, `visual` from
QA's screenshots, one `history` row per lane report, `risk` from the Builder. From then on each
lane rewrites only its own block with `super-board-pr-body.sh`, as run.md says.

Pre-flight (run.md → "Builder pre-flight") finds no open PR for a card in Building or QA. For each
in-flight card also compare the changed files of its remote branch (`git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/issue-<M>-*'`, then `git diff --name-only origin/<base>...<that ref>`) with the
files the new card names.

## Not in this mode

The independent hypothesis pass, the adversarial truth-check and `truth_threshold`, and the
merge gate and `merge_policy`. The repo's Codex review, when it has one, is the second reviewer,
and the repo's own workflow, or a human, merges.
