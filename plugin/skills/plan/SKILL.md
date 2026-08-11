---
name: plan
description: Turn a brief (or a plain request) into a task board — a plan overview plus one file per task, each sized for a writer who sees only that file. Writes docs/plan.md and docs/tasks/*.md. Manual only.
argument-hint: "[path to brief, or a plain request]"
disable-model-invocation: true
---

# My Plan: Plan

Turns a brief into `docs/plan.md` (the overview) plus one file per task under
`docs/tasks/`, rendered from `../../knowledge/templates/{plan,task}.md`.
Writes no product code — a task file is not code, and pseudocode that reads
like code is code. `implement` builds what this writes; `review-plan`
checks it first.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:plan` in the user's message instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

## Declared blindness

Read the brief — the path the argument names, or `docs/brief.md` when the
argument names none — and treat it as decided: this skill plans from it,
it doesn't reopen its decisions. If no brief exists and the argument is a
plain request, say plainly that you're planning without a brief, and hold
yourself to the same bar anyway: requirements and acceptance criteria you
infer belong in the plan's Approach section, explicit, not left implicit.
Read `docs/map.md` if it exists for boundaries and conventions; note if it
doesn't.

If `docs/tasks/` already holds files, stop and ask before writing
anything: they're either an unfinished earlier plan (`implement` deletes
each task file as it's committed) or orphans from an abandoned one. Never
leave two plans' tasks mixed in one directory — an empty directory is the
only "finished" signal the system keeps, and mixing destroys it.

## Write set

The plan's write set stays within the brief's expected write set — exact
files, each inside a path, directory, or glob the brief named. A path the
tasks need that falls outside it is a scope change: stop and ask, and on a
yes revise `docs/brief.md` with a note on what changed and why (or say
explicitly you're widening it, if there's no brief to revise) before the
plan includes it.

## Structure, before sizing tasks

Work the shape of the solution against `../../knowledge/checklists/architecture.md`
before writing tasks. Every layer, interface, factory, or pattern the plan
introduces answers that file's five questions in the plan's Approach
section. A `review-plan` run checks exactly this, so an unanswered question
here is a round it will bounce back.

Reuse an existing helper, pattern, or installed dependency before adding an
abstraction, and name the existing thing in the task that should use it.

## Sizing tasks

The unit of work is not "a feature." It's the smallest change that:

- Touches a handful of files, not a subsystem.
- Carries one idea — if describing it needs "and" twice, it's two tasks.
- Can be verified on its own, by a check the task itself names.
- Leaves the tree buildable.
- Needs no knowledge its task file doesn't carry. Assume the writer has
  never seen this repository and won't see the other tasks.

A large goal becomes many small tasks, never one task that says "build the
feature" — that's the most reliable way to get plausible code that doesn't
work. Never separate a contract from its implementation and wiring: that
task isn't buildable alone and its check proves nothing.

Read each task back asking what a writer would have to guess. Whatever it
is, write it down or flag it as a blocker in the plan's Risks section —
don't let a task leave a decision open. Exact paths, not "the validation
module." The failure path, stated, not implied by the happy path. The edge
cases this task owns, and the ones it deliberately doesn't. The check that
proves it done, precise enough to run as written. The reference paths —
helpers to reuse, patterns to match, tests that pin behavior — so building
starts from the file, not a search of the repository.

Non-trivial new behavior gets a check. Auth, deletion, persistence,
payment, cost, and external contract paths require a behavioral or
integration check, without exception. A refactor over previously uncovered
code gets a characterization check as its first task: pin current behavior
before changing it.

Name task files `docs/tasks/NN-slug.md` — a zero-padded position in
dependency order, so a bare listing reads in build order — and use that
filename as the task's identifier everywhere: the plan's Tasks table and
each task's `Depends on:` line.

## Ordering and parallelism

Sequential only when a task genuinely needs another's output, types, or
conventions — foundations first. Parallel when tasks touch disjoint paths
and neither needs the other's result. A task that only "feels" like it
should come later isn't a real dependency; false sequencing makes the plan
slower for no safety gained.

Parallel means "no ordering constraint," not "two sessions in one
checkout at once" — concurrent `implement` runs share a working tree, so
their diffs mingle until commit. Use separate worktrees, or run them one
at a time.

Fill the plan's Planned against section from the live tree: the commit
you planned from (`git rev-parse HEAD`), any dirty path (`git status
--porcelain`) that intersects the write set, and the path of the brief
you planned from — `implement` and `review-plan` resolve against these.

## Closing note

```
Changed: docs/plan.md and N files under docs/tasks/ written
Validated: not this skill's job
Open risks: <anything flagged in the plan's Risks section, or "none">
Suggested next skill: review-plan — in Claude Code the dispatch already
  gives you a fresh reviewer; in Codex, open a fresh session first
```
