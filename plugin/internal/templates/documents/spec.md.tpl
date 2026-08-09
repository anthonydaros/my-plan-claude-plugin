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
  plan: ./plan.md
  implementation: ./implementation.md
  validation: ./validation.md
  review: ./review.md
  delivery: ./delivery.md
  # Add research or audit only when that phase actually ran. Predeclaring a link
  # to a document that will never exist points future readers at nothing.
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

Every path this Run is authorized to modify. A path outside this set stops the
Run.

It always includes the repository's changelog when this Run's change is visible
to a user of the software — the path the repository already uses, or
`docs/CHANGELOG.md` when none exists yet. The changelog is the one Run document
that ships with the work, and delivery may only write inside this set, so
leaving it out silently decides that no entry will exist.

Then the product paths the work actually touches.

Nothing else of the Run's belongs here. Its working documents live outside the
repository and are never committed, and its task files are managed by the Run
itself and never staged.
