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

| Task ID | What changes | Paths | Check |
|---------|--------------|-------|-------|

Each task states the current state, the intended modification, and the check that
proves it done.

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

## Batches

The cohesive units implementation will run, in order. Each batch leaves the
worktree buildable and never separates a contract from its implementation and
wiring.
