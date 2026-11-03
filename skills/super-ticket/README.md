# /super-ticket

Turns a feature you describe into tickets the board can run, then files them into Backlog.

## What It Does

- **Grills you one question at a time.** Recommended answer first; reads the code instead of asking when the code can answer.
- **Writes the ticket format.** Problem · Context · Fix · Acceptance Criteria · Risk · Blocked by, from [ticket-format.md](../super-board/references/ticket-format.md).
- **Checks its own draft against the [lint criteria](../super-board/references/lint.md)**, so a ticket it files needs no lint pass.
- **Splits oversized work** into vertical slices under the 400-line PR cap, chained with `## Blocked by`.
- **Files through `super-collect-file.sh --source ticket`.** Dry-run first, repo-wide duplicate check, always lands in Backlog, never Ready. Labelled `feature` and `source:ticket`.

## When To Use It

- You have a feature idea and no ticket yet.
- You want Backlog cards that pass `/super-board lint` untouched.

Bugs and refactors found in code come from `/super-collect`, not here.

## Install

Ships in the super-board pack. `install.sh` copies `skills/super-ticket/` to `.claude/skills/super-ticket/`. Needs `gh` and the `super-collect` skill and `.claude/bin` scripts, which the same install provides.
