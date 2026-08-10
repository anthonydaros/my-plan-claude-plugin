# Brief: {{goal}}

Written by `spec`. Treat it as decided once `plan` starts from it — revise it
explicitly, with a note on what changed and why, rather than letting it drift
silently while planning or implementation are already underway.

## Goal

{{goal}}

## Repository evidence

What a quick look at the repository established, each item with the path that
proves it. A fact the code already answers never became a question.

## Domain interpretation

The business domain, its terminology, and how the goal reads inside it. Omit
this section when the goal is purely technical and local.

## Questions and answers

| Question | Answer | Decision |
|----------|--------|----------|

One row per answered question. The decision column records what the answer
changed.

## Research

Only when a claim needed a source outside the repository. Delete this section
when nothing triggered it.

| Claim | Source | Confidence | Effect on the brief |
|-------|--------|------------|----------------------|

`Confidence` is derived, not felt: `high` — official source, version matches
what's actually installed; `medium` — official source, compatible version;
`low` — secondary source or a version mismatch; `none` — could not establish,
flag it and ask rather than carrying it forward silently.

## Requirements

Numbered, testable statements of what must be true when this is done.

## Non-goals

What this explicitly does not do. This is what stops scope from drifting
during implementation.

## Acceptance criteria

Observable conditions that decide whether this is done, written
Given/When/Then (or the repository's own test-description style), so each
one is checkable by someone who did not write the code and `validate` can
find the command or test that would fail if it were violated.

## Expected tests

The checks that must exist and pass. Auth, deletion, persistence, payment,
cost, and external contract paths require a behavioral or integration check.

## Risks

What could go wrong, its impact, and how the plan should reduce it.

## Expected write set

Every path this change is expected to touch — a directory or glob where
the exact files aren't knowable yet is fine; `plan` narrows it. A `plan`
built from this brief stays inside it without saying so explicitly; a
`review` run against this brief treats a path outside it as a finding, not
a silent extra.
