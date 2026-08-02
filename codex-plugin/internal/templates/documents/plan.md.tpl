---
runId: {{runId}}
phase: plan
date: {{date}}
specHash: {{specHash}}
baseSha: {{baseSha}}
---

# Plan

Executable steps for the approved specification. Records each normative fact once
and references the specification, Architecture Memory, project skill, and research
record rather than copying them. Contains no implementation code.

Review findings do not accumulate here. They live in the Finding Ledger and
`review.md`.

## Approach

The shape of the solution in a few sentences, and why this shape rather than the
alternatives considered.

## Phases

One phase unless a real sequencing dependency requires more. Tidiness is not a
dependency.

### Phase {{n}}: {{title}}

Depends on: {{dependencies}}

| Task ID | What changes | Paths | Depends on | Check |
|---------|--------------|-------|------------|-------|

Each task states the current state, the intended modification, and the check that
proves it done.

Tasks are sized for the model that will build it: a handful of files, one idea,
verifiable alone, buildable, and complete without knowledge the handoff does not
carry. A large goal becomes many small tasks, never one big one.

`Depends on` lists only real dependencies. Tasks with no dependency and disjoint
paths run in parallel; everything else runs in order.

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
run at the same time. Each task leaves the worktree buildable and never separates
a contract from its implementation and wiring.

Every delivery is reviewed as it arrives, so this order is also the review order.
