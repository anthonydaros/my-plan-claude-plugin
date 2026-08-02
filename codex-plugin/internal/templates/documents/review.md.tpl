---
runId: {{runId}}
phase: review
date: {{date}}
specHash: {{specHash}}
reviewSubjectHash: {{reviewSubjectHash}}
verdict: {{verdict}}
---

# Review

Fixed-template evidence record. Excluded from the Review Subject because it
records that subject's outcome. Contains only Markdown evidence: never product
code, configuration, or executable content.

Contains conclusions, not model conversation.

## Plan review

| Finding ID | Severity | Disposition | Evidence |
|------------|----------|-------------|----------|

Disposition is resolved, not reproducible, blocked by owner decision, or accepted
and not blocking. Every finding has one; an open finding at approval time means
the ledger is unfinished.

## Code review

Reviewers and their lenses, then the ledger.

| Finding ID | Severity | Lens | Disposition | Evidence |
|------------|----------|------|-------------|----------|

Finding IDs are stable semantic keys. The same defect keeps its ID across every
round. A reworded finding is not a new finding.

## Rounds

| Round | Mode | Findings opened | Findings closed | Progress |
|-------|------|-----------------|-----------------|----------|

Progress means a pending finding closed or new evidence materially changed one.
Rewording, prose changes, and re-reading an unchanged subject are not progress.
Three consecutive rounds without progress end the Run as `BLOCKED`.

## Lens coverage

| Lens | Outcome | Reason if not applicable |
|------|---------|--------------------------|

Every lens each reviewer owned, from the final complete review. A lens marked
`not-applicable` carries the reason the changed surface does not touch it.

An absent lens is not the same as a clean one. If a row is missing, the review was
incomplete and the verdict below does not stand.

## Final verdict

The result of one final complete review against the exact Review Subject hash in
the frontmatter. Approval requires zero unresolved blockers from every reviewer
role.

REVIEW_APPROVED binds to: specification hash, plan hash, base SHA, Review Subject
hash, runtime, Worker identity, and model. Any later change to a Review Subject
path invalidates this approval and requires affected validation and a renewed
final review.
