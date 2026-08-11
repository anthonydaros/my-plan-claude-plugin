---
name: implement
description: Build one task from docs/tasks/, or a plain request when there's no task board, with the implementation defect catalogue loaded and a declared write set. Leaves the task file for commit to delete once the work is in history. Manual only.
argument-hint: "<task file path, or a plain request>"
disable-model-invocation: true
---

# My Plan: Implement

Builds one task, completely, and stops. Doesn't review its own work — that's
`review`'s job, in a fresh session — and doesn't fix things nobody assigned.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:implement` in the user's message
instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

## Declared blindness

If the argument names a file under `docs/tasks/`, read only that file — not
`docs/plan.md`, not the other task files. That's deliberate: the task file
is supposed to carry everything you need, and reading the rest costs you
context you need for the work that's actually yours. If the task file is
genuinely missing something, that's worth saying plainly rather than going
and reading around it.

If the argument is a plain request instead — no task board exists, or this
change doesn't warrant one — say so, and hold yourself to the same
standard: name the exact paths you're about to touch and the check that
proves it done, before you start, the same way a task file would.

Read `docs/map.md` if it exists, for boundaries and conventions. Read
`../../knowledge/checklists/implementation.md`, but only the parts your
task's surface actually touches — a task that adds a string constant has no
transaction story.

## Boundaries

- Modify only the paths the task (or your own stated scope, if there's no
  task) names. A path you need that's outside it is a blocker to report,
  not a reason to widen scope quietly.
- Implement only the task in front of you. Don't start the next one, don't
  finish what an earlier task left undone, don't improve code you happen to
  read along the way — work nobody assigned is work nobody reviewed.
- Don't reopen a decision the brief or plan already settled. Ambiguity you
  can't resolve from what you were given is a blocker, not something to
  decide silently.
- Never `git add -A` or stage anything — this skill doesn't commit.
  `commit` is a separate skill, run separately, on purpose.
- Never write a secret into any file this change will hand to `commit` —
  a brand-new file isn't tracked yet, and "untracked right now" is exactly
  how a secret reaches the staged set later.

## How to work

1. Record `git status --porcelain` before touching anything — your
   closing note's Changed list is the delta against this, not everything
   already dirty. Then read the current state of the files you're about
   to touch — someone may have changed the tree since the task was
   written.
2. Follow the repository's existing conventions, helpers, and installed
   dependencies. Reuse before you add; a new abstraction or dependency
   needs a reason the existing code can't serve.
3. Write the smallest change that satisfies the task. No speculative
   configuration, no interface with one implementation, no scaffolding for
   work nobody asked for.
4. Add the smallest meaningful automated test when the new behavior is
   non-trivial. Auth, deletion, persistence, payment, cost, and external
   contract paths require a behavioral check; trivial code doesn't.
5. If you're fixing a reported defect rather than building new behavior,
   prove the test before you prove the fix: write the check, run it, watch
   it **fail** against the current code, then fix it and watch it pass. A
   test written after the fix, that never failed, proves the code does
   what the code does — nothing more.
6. Run whatever validation the task names (or the commands in
   `docs/map.md`) as a gate before you call this done. Leave the tree
   buildable. This is a sanity check, not the real validation — that's
   `review`'s job, run independently afterward.

## Before you call it done

`../../knowledge/checklists/implementation.md` covers what compiling and
passing tests doesn't: N+1 queries, a missing transaction, a read-check-write
race, authorization checked per session instead of per resource, an error
swallowed into `null`, a migration that can't deploy separately, a call to
an API that doesn't exist in the installed version. Those come back as
remediation if skipped, and every one is cheaper to avoid than to be told
about.

No mock, hardcoded value, `TODO`, or silent fallback left as the answer. No
dead code or second implementation kept alongside the first. No `any`,
cast, or disabled lint rule added to quiet the compiler.

## When the task is done

If you were given a task file under `docs/tasks/`, leave it in place and
name it in your closing note: `commit --tasks` bounds the staged set with
it and deletes it once the work is actually in history. Its absence is the
only progress tracking that exists, and "implemented but never committed"
isn't done — deleting it here would mark the board complete for work that
can still be lost.

## Closing note

```
Changed: <paths actually touched, verified against git status --porcelain
  compared with the step-1 baseline — bare git diff misses new files you
  created>
Validated: <commands run here as a sanity check, and their results — not
  a substitute for /my-plan:review>
Open risks: <anything you couldn't validate, or "none">
Suggested next skill: review, then
  commit --tasks <this task file> — or the next task under docs/tasks/,
  if more remain
```
