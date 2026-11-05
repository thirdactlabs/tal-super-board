# /super-pr-loop

Drives one PR's Codex review threads to closure, then hands off to the merge workflow.

## What It Does

- **Polls for the Codex bot's review.** No review yet is not clean; it waits with a background sleep.
- **Verifies every finding against the real code** before touching anything.
- **Fixes the small ones**, one commit each, then runs `verify_commands` and pushes once per pass. The push re-triggers Codex.
- **Defers the rest** into a GitHub Backlog ticket through `super-review-file-refactor.sh`, replies with the number and resolves the thread.
- **Stops at 3 fix passes**, on a human decision, or when Codex never reviews.
- **Never merges.** The project's own `merge-after-codex-review.yml` merges once Codex is clean.

## When To Use It

- The Review lane runs it when the config says `"pr_review": "codex-bot"`.
- You can run it yourself on any open PR with unresolved Codex comments.

## Install

Ships in the super-board pack. Needs the trigger workflow from `.claude/bin/super-board-codex-bot-install.sh` (or the project's own equivalent), the project's merge-after-codex-review workflow, the `CODEX_REVIEW_TOKEN` secret and the Codex GitHub app on the repo. See [codex-bot-review.md](../super-board/references/codex-bot-review.md).
