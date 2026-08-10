# Task: {{title}}

Depends on: {{dependencies}} — task filenames, or `none`.

One task, one idea. Whoever builds this receives this file and nothing
else — not the plan, not the brief, not the other tasks — so everything they
would otherwise have to guess is written here or is in the repository
itself. Everything here is technical, terse, and decided: a task that leaves
a decision open is not ready to hand off.

Progress isn't tracked in this file or anywhere else: `commit` deletes it
once the task's work is verified in history (`--tasks` names it). An empty
task directory is the signal a plan finished and landed; a file still
sitting there is the signal it didn't.

## Paths

The exact files this task may touch — its entire write set. For each:
whether it exists or will be created, its current state, and the intended
modification. Never "the validation module"; always the path.

## References

The paths to read but not modify: the helpers to reuse, the patterns to
match, the contracts to satisfy, the tests that pin current behavior, and the
documents that settle edge cases — each with one line on why it matters here.
Start from this list instead of searching the repository from scratch.

## Details

The behavior, including what happens on the failure path, stated rather than
implied by the happy path. The edge cases this task owns, and the ones it
deliberately does not, so nothing gets invented and nothing gets assumed to
belong to another task. Conventions and existing helpers to use, named, so
reuse is an instruction rather than a discovery.

## Test strategy

The check that proves this task done, precise enough to run as written.
