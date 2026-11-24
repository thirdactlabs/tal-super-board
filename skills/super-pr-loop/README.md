# /super-pr-loop

Drives one PR's Codex review threads to closure, then hands off to the merge workflow.

## What It Does

- **Polls for the Codex bot's review.** No review yet is not clean; it waits with a background sleep.
- **Verifies every finding against the real code** before touching anything.
- **Fixes the small ones**, one commit each, then runs `verify_commands` and pushes once per pass. The push re-triggers Codex.
- **Defers the rest** into a GitHub Backlog ticket through `super-review-file-refactor.sh`, replies with the number and resolves the thread.
- **Stops at 3 fix passes**, on a human decision, or when the repo has no Codex review (reported, not an error).
- **Never merges.** The repo's own workflow, or a human, merges.

## When To Use It

- The Review lane runs it when the config says `"pr_review": "codex-bot"`.
- You can run it yourself on any open PR with unresolved Codex comments.

## Install

Ships in the super-board pack. Installs nothing and needs no setup: if the repo has a Codex review it fixes the findings, if not it reports `no-codex`; whether the PR then auto-merges or waits for a human is the repo's business. See [codex-bot-review.md](../super-board/references/codex-bot-review.md).
