# Plan: {{goal}}

Executable overview for a brief. Records each normative fact once and
references the brief and the map document rather than copying them. Contains
no implementation code.

The tasks themselves live as one file each, next to this plan, rendered from
`task.md`; this document is the shape of the work, not a second copy of it.

## Approach

The shape of the solution in a few sentences, and why this shape rather than
the alternatives considered.

## Planned against

The base this was planned from — a commit, a branch state, or `none` for a
new repository — and anything already dirty in the working tree that
intersects the write set below, because whoever planned this read the live
checkout, not a frozen snapshot. Also names the brief this plan delivers,
by path, or `none`. `implement` and `plan`'s own review phase resolve
against these; `implement` should re-check the base before trusting it,
since time passes between planning and building.

## Tasks

| Task | Title | Depends on |
|------|-------|------------|

One row per task file. `Depends on` lists only real ordering constraints;
tasks with no dependency and disjoint paths run in parallel. This table is
the roster, not the tracker: `commit` deletes a task's file once its work
is actually committed, so a row whose file is gone from `docs/tasks/` is
done, and an empty directory means the plan completed.

Tasks are sized for the model that will build them: a handful of files, one
idea, verifiable alone, buildable, and complete without knowledge the task
file does not carry. A large goal becomes many small tasks, never one big one.

## Write set

Every path this plan expects implementation to touch — exact files, each
inside the brief's expected write set. If it needs to reach outside that,
it's a scope change worth saying out loud, not a quiet addition.

## Test impact

Which existing tests are affected and which new checks the work requires.

## Risks

| Risk | Impact | Mitigation in this plan |
|------|--------|--------------------------|

## Execution order

The sequence the tasks run in, with the independent ones grouped where they
can run at the same time. Each task should leave the tree buildable and never
separate a contract from its implementation and wiring.
