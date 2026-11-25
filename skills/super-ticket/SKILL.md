---
name: super-ticket
description: Turn a feature you describe into board-ready tickets on the super-board GitHub Project. Grills you one question at a time, drafts each ticket in the super-board ticket format, checks the draft against the lint criteria so it needs no lint pass, then files it into the board's Backlog through super-collect-file.sh. Interactive, run by you, never by the board. Use when the user says "/super-ticket", "super-ticket", "board ticket", or "add a feature to the super-board Backlog". Not for Linear tickets.
---

# /super-ticket

One job: take a feature the user describes and file tickets the board can run without a lint
pass. You write the ticket; `super-collect-file.sh` files it. Interactive only: a lane agent or
an unattended run never loads this skill.

Format: [ticket-format.md](../super-board/references/ticket-format.md). Checks:
[lint.md](../super-board/references/lint.md) criteria 1–19. Do not restate them; apply them.

## 1 · Set up

1. Pick the config in `.claude/super-board/configs/`: none → stop with "Run `/super-board
   onboard` first"; one → use it; several → ask which.
2. Read `docs/super-board/PROJECT.md` (scope), the repo's `AGENTS.md` and README.
3. Read the open cards once: `.claude/bin/super-board-card.sh --config <cfg> items`
   → `{items:[{status,title,content:{number,url}}]}`. The `content.number` values are the only
   issue numbers `## Blocked by` may name, and the list you check for duplicates against.

## 2 · Grill

Ask one question at a time, recommended answer first. Stop when you can write every
section. Read the code instead of asking whenever the code can answer.

You need: what is wrong or missing from the user's side · where it happens and the steps ·
who sees it · the intended change in 1–3 lines · 2–5 outcomes a test can assert, each with a
number, state or text (never "fast", "nice", "works") · what is out of scope · what must
land first · whether it touches money, auth or destructive schema (DROP/TRUNCATE/RENAME).

## 3 · Size

One ticket is one PR under 400 changed lines (`merge_policy.auto_max_lines`). Estimate from
the files the outcomes imply. Over the cap, or three or more separate areas (UI, API,
database, job, email): split into vertical slices, each thin end to end and independently
mergeable, each with its own ACs. Chain them with `## Blocked by`. Show the split and get a yes
before drafting.

## 4 · Draft

Write each body to a `mktemp` file, in the ticket-format.md shape (Problem · Context · Fix ·
Acceptance Criteria · Risk · Blocked by). Then:

- **Title:** the bare change, no emoji, kind or number (the filer adds `[feat] <scope>:`).
  Keep it under 50 characters. Pass the scope as `--area`.
- **Context:** `- **Where:**` then lettered steps, one per line, no arrows.
- **Acceptance Criteria:** `- [ ]` lines, 2–5, each checkable.
- **Blocked by:** `- #N — why` using only numbers from step 1, or exactly `- None.`. Put any
  explanation in a blockquote below, never on the bullet. A slice filed in this run is
  filed after its blocker so its number exists.
- **Risk:** low / medium / plus one line.
- No secrets or user data. No `TBD`, `TODO:` or `<placeholder>` left in the text.

## 5 · Check before filing

Walk the draft against lint criteria 1–19. Fix what fails; ask the user only when the fix
changes meaning. In particular:

- 13 `Blocked by` is bullets or a bare `- None.`; 14 an AC proven only against a fake names
  the card that builds the real one; 15 under the size cap; 16–18 sections, checklist and
  lettered steps; 19 an unsettled shared interface or hard-to-reverse choice gets two short
  sketches and the chosen one in Context.
- A `money`, `auth` or `schema` ticket gets that label (`--label money`): it routes the merge
  to a human.

Never file a ticket that fails a check. Say which one and why.

## 6 · Confirm, then file

For each ticket, in dependency order:

1. Dry-run (no `--yes`):

   ```bash
   S=.claude/skills/super-collect/scripts   # in the pack: skills/super-collect/scripts
   $S/super-collect-file.sh --config <cfg> --type feature --source ticket \
     --title "<bare title>" --body-file <body.md> --fingerprint "ticket|<kebab-slug>" \
     --area <scope> [--priority high|medium|low] [--label money|auth|schema]
   ```

   It prints `would-file|feature|<title>|Backlog`, `duplicate|#N|…` or `recurrence|#N|…`.
   `<kebab-slug>` is the title in lowercase kebab-case.
2. Show the user the title, the body and that line. `duplicate` → name the open issue and
   ask before going on (`--yes` posts the new text as a "Seen again" comment, not a new
   ticket). `recurrence` → name the closed issue; filing again is fine.
3. On a yes, rerun with `--yes`. Stdout is the issue number. Exit 71 means filed but not
   placed: report the number and tell the user to move it. Exit 79 means GitHub reads are
   paused: stop and report; do not retry.

## 7 · Report

One line per ticket: `#N <title>`, its URL, and `Backlog`. Then: "Move to Ready when you
want it built. The board never builds a Backlog card." Never move a card to Ready yourself.

## Rules

- NEVER ask a lane or a run to call this skill. It waits for answers.
- NEVER put a card in Ready, and never skip the dry-run.
- NEVER invent a `Blocked by` number. A missing or unreadable line stops the planner.
- Reuse `super-collect-file.sh`; do not call `gh issue create` yourself.
