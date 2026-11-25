---
name: super-pr-loop
description: Drive one PR's Codex-bot review threads to closure for the super-board Review lane, or standalone. Polls for the Codex bot's review and any unresolved thread, verifies each finding against the real code, fixes what is small, defers what needs design into a GitHub Backlog ticket, replies to and resolves every thread, then pushes once per pass (a push re-triggers Codex). At most 3 fix passes. Never merges: the repo's own workflow, or a human, does that. A repo with no Codex review is not an error. Use when the user says "/super-pr-loop", "super-pr-loop", "fix the Codex review", "resolve Codex comments on this PR", or when the Review lane runs in pr_review "codex-bot" mode.
argument-hint: "<PR number> [--ignore \"keyword\"] [--wont-fix \"keyword\"]"
---

# /super-pr-loop

Board port of `thirdactlabs-codex-fix-pr-loop`. Same verify → fix or defer → reply → resolve
discipline, with the Linear and ADR parts replaced by the board's own filer. Lane contract:
[codex-bot-review.md](../super-board/references/codex-bot-review.md).

One PR per run. Several PRs → refuse and name the one to start with.

## Preconditions (once)

1. `gh pr view <PR> --json state,isDraft,headRefName,baseRefName`. Not `OPEN` → stop. Draft →
   `gh pr ready <PR>` (a draft is never reviewed or merged).
2. Does the repo post a Codex trigger? `git grep -l '@codex review' origin/<base> -- .github/workflows`.
   It only sets how long step 1 waits for a first review (12 minutes with a trigger, 3 without,
   since the Codex app can also review on its own). Nothing to install: a repo with no Codex
   review is a normal result (`no-codex` below), not an error.
   **Never post `@codex review` yourself**; the repo's workflow does it on every push.
3. Pick the config in `.claude/super-board/configs/`. Its `verify_commands` are the suites to
   run before every push.
4. **Never merge, never push to the base branch.** Fix commits go to the PR's own branch.

## The loop

Repeat until a poll after your latest push finds nothing new, or a stop below fires.

### 1 · Poll

```bash
gh pr view <PR> --json state,mergedAt,headRefOid,reviews,comments
gh api --paginate repos/<owner>/<repo>/pulls/<PR>/comments --jq '[.[] | .id] | sort'
```

- `state` first, every poll. `MERGED` → stop and report who and when (the workflow merged it).
  `CLOSED` → stop.
- Codex answers in one of two forms, both by a login starting `chatgpt-codex-connector` (GraphQL
  drops the `[bot]` suffix, REST keeps it):
  - **Findings:** a `reviews[]` entry with a non-empty body on a commit equal to `headRefOid`,
    plus inline threads.
  - **Clean:** a `comments[]` entry containing `**Reviewed commit:**` whose sha prefix matches
    `headRefOid`. This is the comment `merge-after-codex-review.yml` reacts to. Clean means this
    comment on the current head AND no unresolved thread on the worklist above.
  A findings review also quotes `**Reviewed commit:**`; only a `comments[]` entry counts as clean.
  Neither form on the head yet is **not clean**: wait, up to the window from Preconditions 2
  for the first review (after a push, up to 12 minutes). Past the window with no Codex review at
  all on this PR, stop `no-codex`.
- **Wait with a background `sleep 300`, repeated.** Never `ScheduleWakeup` or `/loop`: they
  end a lane's turn and the orchestrator reads that as a failure. Stay in this agent.
- Always `--paginate`. Diff comment ids against the last pass, never counts.
- Worklist = every unresolved thread, bot or human (paginated GraphQL, `isResolved`), except a
  thread whose only comment is the lane's own author note (first line `<!-- super-board:author-note`)
  with no reply from anyone else: it explains a file, it is not a finding. A reply makes it work.

### 2 · Verify

A review comment is a claim. Read the file, trace the call path, confirm or refute. A finding
that does not hold gets a reply with the disproving evidence, not a fix, and is resolved.

### 3 · Fix or defer

- **Fix now:** small, well understood, no new product decision. Minimal edit plus a test that
  would have caught it. One commit per fix, files staged by name, never `git add -A`, never
  `--no-verify`. Do not push yet.
- **Defer or won't-fix:** needs a new concept, is out of scope, or is unenforced style. File it,
  never force a hacky fix:

  ```bash
  .claude/bin/super-review-file-refactor.sh --config <cfg> --title "<bare problem>" \
    --body-file <body.md> --fingerprint "<file>|<finding-slug>" --pr <PR> --area <scope>
  ```

  Body = `## Problem` · `## Context` (`- **Where:**`) · `## Fix`, and **no**
  `## Acceptance Criteria`, so it lands in Backlog for lint and the board never builds it
  unasked. Put the issue number in the reply.
- **Needs a human decision:** finish the rest of the pass, leave that thread untouched, then
  stop with the question, the options and your recommendation.

### 4 · Reply and resolve

Reply on every thread you handled (fixed with the commit sha, deferred with `#N`, false positive
with the evidence), react +1 or -1, then resolve it. Never resolve a thread whose fix failed
its tests.

### 5 · One push per pass

Run every `verify_commands` entry. A **new** failure (run.md → "Pre-existing failures") → stop, do not push; a pre-existing one is noted in the thread reply and does not stop the pass. Else
`git pull --rebase && git push`. The push re-triggers Codex; go back to 1.

## Stops

| Reason | Result |
|---|---|
| `MERGED` | report it; the lane confirms the commit on the base branch |
| Clean: the bot's clean comment is on the current head and no thread is unresolved; PR still `OPEN` | report clean; the project's merge workflow takes over |
| 3 fix passes pushed and Codex still raises real findings | `round-cap` |
| A finding needs a human decision | `needs-decision` |
| No Codex review or clean comment on the head within the wait, and no human thread to work | `no-codex`: the repo has no Codex review. Report it and stop; nothing is wrong |
| A suite fails newly after a fix (not red on the base) | `tests`, nothing pushed |

The lane turns `round-cap`, `needs-decision` and `tests` into a Blocked card (or a QA bounce) using the block template; `no-codex` and clean both continue. Standalone, print
the reason and stop.

## Rules

- NEVER merge, close or mark the PR ready beyond the draft check above.
- NEVER post a top-level PR comment; thread replies only.
- NEVER `--force`, `--no-verify`, `git add -A`. One push per pass.
- NEVER use `ScheduleWakeup` or `/loop`.
- NEVER touch Linear or write ADRs: deferred findings go to the board's Backlog.
