---
runId: {{runId}}
phase: implementation
date: {{date}}
specHash: {{specHash}}
planHash: {{planHash}}
worktree: {{worktree}}
---

# Implementation

Owns the completed task record. The approved specification is never edited by
progress; it is recorded here.

Contains no agent transcripts.

## Completed tasks

| Task ID | Batch | Changed paths | Verified against |
|---------|-------|---------------|------------------|

`Verified against` is the Git evidence that the reported paths are the real ones.

## Deviations

Where the work differs from the plan, with the reason and the evidence that made
the plan wrong. A deviation that changes product behavior belongs in a new
specification revision, not here.

## Corrections

Problems found during batch delta inspection and how they were fixed, so the same
mistake does not repeat in a later batch.

## Backend transitions

Recorded only if one occurred: phase, role, error class, replacement model, and
time. Preserved work is listed explicitly.

## Final diff review

Cross-batch drift, duplicated helpers, inconsistent naming, dead code, and
unintended files checked before the Validation Gate. State what was found or state
that nothing was.
