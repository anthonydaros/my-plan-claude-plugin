# Task ID: {{taskId}}
# Title: {{title}}
# Dependencies: {{dependencies}}
# Description: {{description}}

One task, one idea. The writer that builds this task receives this file and
nothing else — not the plan, not the specification, not the other tasks — so
everything it would otherwise have to guess is written here or is in the
repository itself. Everything here is technical, terse, and decided: a task
that leaves a decision open is not ready to dispatch. Status is not tracked in
this file: the Run manifest records progress, and this file is deleted when the
task completes.

## Paths

The exact files this task may touch — its entire write set. For each: whether it
exists or will be created, its current state, and the intended modification.
Never "the validation module"; always the path.

## References

The paths the writer reads but must not modify: the helpers to reuse, the
patterns to match, the contracts to satisfy, the tests that pin current
behavior, and the documents that settle edge cases — each with one line on why
it matters here. The writer starts from this list instead of searching the
repository.

## Details

The behavior, including what happens on the failure path, stated rather than
implied by the happy path. The edge cases this task owns, and the ones it
deliberately does not, so the writer neither invents them nor assumes another
task covers them. Conventions and existing helpers the writer must use, named,
so reuse is an instruction rather than a discovery.

## Test Strategy

The check that proves this task done, precise enough to run as written.
