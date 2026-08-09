---
runId: {{runId}}
phase: plan
date: {{date}}
specHash: {{specHash}}
plannedBase: {{plannedBase}}
---

# Plan

Executable overview for the approved specification. Records each normative fact
once and references the specification, Architecture Memory, project skill, and
research record rather than copying them. Contains no implementation code.

The tasks themselves live as one file each in the repository's task directory,
rendered from the task template; this document is the shape of the work, not a
second copy of it. Review findings do not accumulate here. They live in the
Finding Ledger and `review.md`.

## Approach

The shape of the solution in a few sentences, and why this shape rather than the
alternatives considered.

## Planned against

`plannedBase` is the local default-branch commit the repository was read at,
or the literal `none` in Greenfield Mode.
Execution resolves a fresh base later and compares what changed in between, so
two facts are recorded here because no fetch can repair them:

- Whether the checkout's HEAD sat on the default branch when the plan was
  written, and where it sat if not.
- Every dirty path that intersected the write set, because the planner read the
  live checkout, not a frozen base.

## Tasks

| Task ID | Title | Depends on |
|---------|-------|------------|

One row per task file. `Depends on` lists only real ordering constraints; tasks
with no dependency and disjoint paths run in parallel.

Tasks are sized for the model that will build them: a handful of files, one
idea, verifiable alone, buildable, and complete without knowledge the task file
does not carry. A large goal becomes many small tasks, never one big one.

## Write set

Every path the plan authorizes implementation to touch. It must equal the
approved specification's write set exactly.

A plan cannot widen what approval covers. If the work genuinely needs a path the
specification does not list, that is a scope change: revise the specification, get
an ordinary approval, and renew `approvedSpecHash`. Explaining an extra path does
not authorize it.

## Test impact

Which existing tests are affected and which new checks the work requires.

## Risks

| Risk | Impact | Mitigation in this plan |
|------|--------|-------------------------|

## Execution order

The sequence the tasks run in, with the independent ones grouped where they can
run at the same time. Each task leaves the tree buildable and never separates a
contract from its implementation and wiring.

Every delivery is reviewed as it arrives, so this order is also the review order.

END OF PLAN
