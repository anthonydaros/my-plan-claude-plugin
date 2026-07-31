---
runId: {{runId}}
phase: spec
date: {{date}}
goal: {{goal}}
repositories: {{affectedRepositories}}
modules: {{affectedModules}}
status: approval-candidate
tags: {{tags}}
records:
  discovery: ./discovery.md
  research: ./research.md
  plan: ./plan.md
  implementation: ./implementation.md
  validation: ./validation.md
  review: ./review.md
  delivery: ./delivery.md
---

# Working Spec

Frozen at approval. Later phases link back to this file's hash; none of them edit
it. A scope change creates a new revision and a new approval.

## Requirements

Numbered, testable statements of what must be true when this is done.

## Non-goals

What this explicitly does not do. This is what stops scope from drifting during
implementation.

## Affected repositories and modules

Every repository and module the work touches, with the reason each is involved.

## Evidence

The repository facts and cited research this specification rests on, each with its
path or source.

## Decision register

| ID | Decision | Source | Rationale |
|----|----------|--------|-----------|

Both user answers and automatic Recommendation Authority decisions. `Source` says
which.

## Acceptance criteria

Observable conditions that decide whether this is done. Each one is checkable by
someone who did not write the code.

## Expected tests

The checks that must exist and pass. Auth, deletion, persistence, payment, cost,
and external contract paths require a behavioral or integration check.

## Risks

What could go wrong, its impact, and how the plan reduces it.

## Preliminary write set

Every path implementation is authorized to modify. A path outside this set stops
the Run.
