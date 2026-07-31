# Stage: Implementation

Build the reviewed plan in the isolated worktree, prove it works, and deliver it.
Covers batching, the Validation Gate, commit, integration, and push.

No user gate exists in this stage. The approved specification already authorized
all of it. Asking for permission you already have is a defect, not caution.

## Batches

Work the batches the plan defined. Adapt as you go: clean mechanical work may grow
the next batch, correction-heavy work shrinks it and gets explicit notes.

For each batch:

1. **Assign.** Build a handoff matching
   `${CLAUDE_PLUGIN_ROOT}/internal/contracts/handoff.schema.json` with
   `role: "implementer"`, `mode: "build"`, this batch's task IDs, the write set,
   artifact paths and hashes, and the micro-gate commands. Pass the handoff path,
   never the documents themselves.

   Claude-only: the `my-plan-implementer` agent, Sonnet. Hybrid: Luna via Codex,
   workspace-write sandbox, per `${CLAUDE_PLUGIN_ROOT}/internal/codex.md`.

2. **Reuse the session.** Keep the same implementation Worker across batches so
   verified conventions and correction notes carry forward. Reset only at a batch
   boundary, and only when the session is demonstrably confused or repeating
   corrected mistakes. Resetting a working session throws away everything it
   learned about the repository.

3. **Verify the claim.** Validate the returned result against
   `${CLAUDE_PLUGIN_ROOT}/internal/contracts/build-result.schema.json`. Then check
   `changedPaths` against the real Git diff and the approved write set. A Worker's
   report of what it changed is a claim; Git is the evidence. A path outside the
   write set stops the batch.

4. **When a batch comes back `blocked`.** Never re-dispatch the same handoff to
   the same Worker and hope. Diagnose first, then act:

   | Cause | Response |
   |-------|----------|
   | The handoff was missing context the Worker needed | Fix the handoff, re-dispatch in the same session |
   | The task needs more reasoning than the model has | Escalate one step up the fallback table |
   | The batch was too large to hold at once | Split it and reassign |
   | The plan itself is wrong | Return to planning with the evidence |
   | `needsDecision: true` | A product question. It goes to the user, not to another Worker |

   Three failed attempts at the same finding means the defect is in the plan or
   the design, not in the attempt. Route it upward instead of patching a fourth
   time.

5. **Inspect the delta.** Review only this batch's delta against the
   specification, plan, project skill, and Architecture Memory. Correct verified
   problems before assigning the next batch. A problem carried into the next batch
   multiplies.

6. **Micro-gate.** Run the fastest relevant lint, type-check, compile, or build
   check. Not the full suite; that is the Validation Gate's job.

7. **Stage and record.** Stage only paths this batch and this Run own. Never
   `git add -A`. Confirm completed plan checkboxes against the actual diff, then
   update `implementation.md`, rendering it from
   `${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/implementation.md.tpl` on
   the first batch.

## Shared resources

A worktree isolates files. It does not isolate a fixed database, a fixed port, an
emulator, or a deployment target: two Parallel Runs reaching for the same one will
collide, and the failure looks like a flaky test rather than a collision.

Take a resource lease around the window where that resource is actually in use,
and release it as soon as the work is done. Never hold one across a whole phase,
and never hold one while a model is reasoning.

## After the last batch

Review the complete feature diff before the Validation Gate, looking for what
per-batch inspection cannot see:

- Cross-batch drift: the same concept implemented two ways.
- Duplicated helpers introduced independently in different batches.
- Inconsistent naming across batch boundaries.
- Dead code left behind by a later batch.
- Files that were never supposed to be there.

## Codex fallback

Failure classification and the exact invocations are in
`${CLAUDE_PLUGIN_ROOT}/internal/codex.md`. In short: authentication, quota, usage,
credit, and explicit provider limits fall back immediately without retry;
transient failures get one bounded retry first.

The transition is sticky for this Run. Record phase, role, error class,
replacement model, and time in `implementation.md`. A later Run probes Codex
again.

Fallback continues from current canonical artifacts. It never repeats discovery,
requests approval again, or discards valid work. If a Codex Worker left a partial
diff, verify the real changed paths against the write set first, then let Sonnet
continue the remaining tasks in the same worktree.

A fallback never merges writer and reviewer identities. If the only remaining
option would, the Run blocks instead.

## Validation Gate

Runs before commit, and again after every remediation round.

Render `validation.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/validation.md.tpl`.

Always run: every affected test, and every required command in the Project
Profile.

Also run, when the Project Profile, risk classification, or a changed external
contract requires them: full suite, integration, emulator, browser, and end-to-end
checks.

Record the exact commands and their real exit codes. A command you did not run
does not appear in the record. Never summarize a result you did not observe.

Coverage:

- New behavior gets observable-behavior coverage.
- Auth, deletion, persistence, payment, cost, and external contract paths require
  a behavioral or integration check. These are not eligible for coverage debt.
- A hard-to-test non-critical path may enter coverage debt with its reason and
  escape plan.

A failing required check prevents delivery. Report the failure with its output.
Never report a gate as green when it is not.

## Delivery

Only after `REVIEW_APPROVED` binds to the current Review Subject hash.

### Cold resume revalidates

If this Run reached delivery in a different session than the one that produced
`validation.md`, rerun every required Project Profile command before committing.

The Review Subject hash proves the code did not change. It proves nothing about
the machine. A Run resumed days later inherits a green record produced against a
toolchain, dependency set, and base that may all have moved since. Trusting that
record is exactly the "a text sentinel alone never approves a phase" failure,
wearing a hash.

A failure here returns to remediation. It does not block the Run.

### Manifest

Render `delivery.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/delivery.md.tpl` before
committing. It states intent: approved hashes, target remote and branch, planned
commit grouping, integration preconditions, recovery policy, and deployment hold.

It never claims a commit, push, or remote verification that has not happened.

### Commit

One commit for a small cohesive change; multiple atomic commits when independent
changes make better history.

**Authorship is the user's, always.** Commit with the repository's configured Git
identity, exactly as it is. Never override `user.name` or `user.email`, never add
a `Co-Authored-By` trailer, and never name a model, an assistant, or this plugin
anywhere in a commit message. The message describes the change, not what produced
it. A repository's history belongs to the person responsible for it.

Write the message about what changed and why, in the repository's existing commit
style. If the repo uses conventional commits, use them; if it does not, do not
introduce them.

Stage exactly the Review Subject plus the two fixed-template evidence records,
`review.md` and `delivery.md`. Verify the staged path list equals that set before
committing. Never `git add -A`.

Version bumps and tags only when the Project Profile or the approved specification
requires them. Do not impose semantic versioning, tags, README version edits, or
generated changelogs on ordinary work.

Never write a secret into a tracked file. Never use `--no-verify`.

### Integration

Optimistic two-phase locking:

1. Take a short lease. Fetch. Record the target remote SHA. Release the lease.
2. If the base moved: rebase only the temporary branch, resolve conflicts, rerun
   affected validation, run a final review, and renew the Review Subject hash. All
   of this happens outside the lease.
3. Reacquire the lease. Fetch again. Proceed only if the remote target still
   equals the reviewed expected base.
4. Non-force fast-forward integration or push, then verify the remote SHA, under
   that short lease.
5. A changed base or a server-side non-fast-forward rejection releases the lease
   and restarts from step 2.

Bound the retry. On a branch that other people are actively pushing to, every
cycle costs a rebase, a revalidation, and a fresh review, and the base can keep
moving faster than the Run can finish. After a few consecutive base changes, or a
sensible time window, stop and end the Run as `BLOCKED` and recoverable: preserve
the worktree, the commits, and the exact SHAs observed. A Run that never converges
must stop spending, not spin.

Never hold a lease while a model reasons, rebases, validates, reviews, or edits.

Never: push the temporary branch, create a pull request, force push, rewrite
published history, or delete a remote branch.

In Workspace Mode, every affected repository must have an approved diff, a green
gate, a scoped commit, and a revalidated base before the first push. Pushes then
run serially under per-repository locks. If a later push fails after an earlier
one succeeded, record the exact local and remote SHAs, mark the Run `BLOCKED`, and
resume only the unpushed repositories. Never roll back published history.

### Completion

Record in durable local Run state: exact commit identifiers, integration base,
push result, verified remote SHA, completion status, and timestamp.

Create no post-push documentation commit. The approved specification stays
unchanged.

Remove the worktree and temporary branch only after remote SHA verification.
Preserve unintegrated or dirty Runs for recovery.

Final status:

| Situation | Status |
|-----------|--------|
| Pushed and remote SHA verified, no deployment target | `DONE` |
| Verified, deployment target exists | `READY_FOR_DEPLOY` |
| Greenfield, intentionally local-only, local commit verified | `DONE_LOCAL` |
| Required remote failed, or a push failed mid-workspace | `BLOCKED`, recoverable |

Deployment is never implied by code delivery. It requires separate explicit
approval naming the target.

### Final report

Short: completed work, validations run, commit identifiers, verified remote SHA,
and any deployment hold. The Run Dossier and local Run state hold the detail.

If something was blocked, say plainly what and why. Never report success you did
not verify.
