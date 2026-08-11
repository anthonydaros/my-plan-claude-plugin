---
name: validate
description: Independently execute the repository's real validation commands and report what actually passed — never trusts a claimed result. Checks that acceptance criteria are actually exercised, not just that a suite is green. Manual only.
argument-hint: "[--spec docs/brief.md]"
disable-model-invocation: true
---

# My Plan: Validate

Runs the repository's validation commands itself and reports the real exit
codes. It exists because "the tests pass" reported by whoever just wrote
the code is a claim, and this skill is the first party to actually check
it. Doesn't edit, fix, or stage anything — a defect it can see the fix for
is still a finding, not a repair.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:validate` in the user's message
instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

## Independence

**Claude Code.** Dispatch the run to the `my-plan-reviewer` agent (defined
at `../../agents/my-plan-reviewer.md`) via the Task tool — it already
knows this role: dispatched to execute validation commands, it runs them
itself and reports the real exit codes. Give it the commands you resolved
below (or where to resolve them), the `--spec` path if any, and
`docs/map.md` if it exists. A validation run inside the session that just
wrote the code is the claim this skill exists to check, not the check.

**Codex CLI.** No subagent primitive exists here. If your own context
shows you wrote or substantially shaped the change being validated, say
that plainly at the top of the report — the exit codes are still real, but
"independently executed" isn't, and the report must not claim it.

## Declared blindness

Find the commands to run, in this order: `docs/map.md`'s Validation
section, then the repository's CI configuration, then its package
scripts. If none of these settle it, ask rather than guess — running the
wrong command and reporting green is worse than asking. If `--spec <path>`
was given or `docs/brief.md` exists, read its acceptance criteria; if
neither, say plainly: `Conformance: not evaluated — no brief supplied or
found. Acceptance criteria were not checked.`

## What you own

Three lenses: `tests`, `correctness`, `conformance` — not the other eight.
Whoever asked you to run also wants a review; that's `review`'s job, run
separately.

1. **Run every validation command, one at a time, and record its real exit
   code.** A command you didn't run doesn't appear in your report. A
   failing command doesn't become a pass because the rest of the suite is
   green.

2. **If a claimed result exists** (a closing note from `implement`, a
   comment, a prior report), compare what you actually observed against
   it. A disagreement is the finding, whichever way it points: a command
   claimed green that fails for you is a `blocker`. A claimed result you
   can't reproduce running the same command is a `blocker` — an
   unreproducible green is not a green.

3. **Check the acceptance criteria are actually exercised.** For each one
   in the brief, find the command or test that would fail if it were
   violated. A criterion nothing exercises is a `conformance` finding at
   `major`, or `blocker` when it covers auth, deletion, persistence,
   payment, cost, or an external contract. "The suite passes" is not
   evidence a specific criterion is met.

## Flakiness is a finding, not a retry

If a command fails and then passes on a second identical run, don't report
the pass alone. Report both runs and open a `tests` finding: a check that
decides differently on identical input can't prove anything about this
change, and whatever runs after this is about to trust it anyway.

## Leave the tree the way you found it

Record `git status --porcelain` before the first command. Build output,
caches, and coverage files a command leaves behind are expected, not a
finding — unless a command wrote somewhere surprising. But never run a
command in a mode that rewrites tracked files: no snapshot-update flag, no
`--fix`, no formatter in write mode, no codegen that edits sources. If the
repository's own validation script does that by design, or the after-run
`git status --porcelain` differs from the before-run on any tracked file,
report the exact paths — "read-only" is a claim this skill verifies about
itself the same way it verifies everything else, and `commit`'s "commit
what's dirty" mode would sweep those files in next.

## Output

A report in the shape of `../../knowledge/templates/report.md`, scoped to
`tests`, `correctness`, `conformance`. Every finding cites the command and
its exit code, or the path and line range — a finding whose evidence is a
summary of output you didn't keep isn't reportable. "There were no tests to
run" is a `blocker`, not a reason to mark the lens not-applicable. Mark the
other eight lenses `not-applicable` in the coverage table — the template
expects every row, and "scoped to three" is a reason, not an omission.

## Closing note

```
Changed: <none, or the tracked paths a validation command modified —
  git status --porcelain before vs after>
Validated: <every command run, with its real exit code>
Tree: <git status --porcelain at completion — so commit can tell whether
  it's committing the tree that was actually validated>
Open risks: <blocker count, or "none">
Suggested next skill: commit, if everything's green
```
