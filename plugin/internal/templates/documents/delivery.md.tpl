---
runId: {{runId}}
phase: delivery
date: {{date}}
specHash: {{specHash}}
reviewSubjectHash: {{reviewSubjectHash}}
target: {{targetRemote}}/{{targetBranch}}
---

# Delivery Manifest

Pre-push intent, rendered before committing. Fixed-template evidence record,
excluded from the Review Subject.

This document never claims a commit, push, or remote verification that has not
happened. Actual commit identifiers, integration base, push result, verified
remote SHA, and final status live in durable local Run state and the final
response.

## Approved hashes

| Artifact | Hash |
|----------|------|
| Specification | {{specHash}} |
| Plan | {{planHash}} |
| Review Subject | {{reviewSubjectHash}} |
| Base SHA | {{baseSha}} |

## Target

Remote, default branch, and the integration method: non-force fast-forward only.

## Planned commits

| Commit | Message | Paths |
|--------|---------|-------|

Staged paths equal the Review Subject plus this file and `review.md`. Nothing
else. No `git add -A`.

## Integration preconditions

- Required validation is green.
- REVIEW_APPROVED binds to the Review Subject hash above.
- The remote target still equals the reviewed expected base at the moment of the
  final short lease.
- The temporary branch is never pushed. No pull request is created.

## Recovery policy

What happens if the base moved: release the lease, rebase the temporary branch,
rerun affected validation, renew the final review and Review Subject hash, then
reacquire and retry. Already published history is never rewritten or rolled back.

## Deployment hold

Code delivery does not imply deployment. Deployment requires separate explicit
approval for a named target. State the target if one is expected, and state that
it is on hold.
