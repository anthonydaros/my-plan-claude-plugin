# Stage: Implementation

Build the reviewed plan in the isolated worktree, prove it works, and deliver it.
Covers task execution, the Validation Gate, commit, integration, and push.

No user gate exists in this stage. The approved specification already authorized
all of it. Asking for permission you already have is a defect, not caution.

## Tasks

The plan's tasks are the unit of work. Run one task at a time, or several in
parallel when the plan marks them independent and their paths are disjoint. Never
hand a writer several sequential tasks at once, however small they look: the point
of small tasks is that the writer only ever holds one.

### Parallel tasks share one worktree

The writers are separate sessions, but the working tree, the Git index, and
`implementation.md` are not. Two tasks finishing at once would interleave their
staging and each measure its delta against the other's checkpoint.

So writers run concurrently; everything else serializes:

- Each parallel writer gets a write set restricted to its own task's paths. Two
  writers never share a path.
- Build each reviewer's subject as a diff filtered to that task's paths
  (`git diff -- <paths>`), not as the whole working tree. A reviewer must see its
  task's work and nothing else, whatever else is in flight.
- Staging, `implementation.md` updates, and ledger writes happen one task at a
  time, in the Coordinator, never inside a writer.
- **Micro-gates and validation commands are serialized too.** Writing is parallel;
  checking is not. Do not put gate commands in a parallel writer's handoff: the
  Coordinator runs them, one task at a time, once that task's edits have settled.

That last rule is the one that looks unnecessary and is not. Disjoint write sets
isolate files, but `tsc`, `lint`, and `build` scan the whole project. A writer
running its gate while another is mid-edit gets errors in files it does not own
and may not touch, so it reports `blocked` with its own work perfectly correct.
Nothing in the diagnosis table explains that, the Coordinator escalates a defect
that does not exist, and three attempts later the Run is `BLOCKED` over a race.
Shared incremental build caches corrupt the same way.

If a task's paths cannot be isolated from another's, the two are not independent.
Run them in sequence and correct the plan.

For each task:

1. **Assign.** Build a handoff matching
   `${CLAUDE_PLUGIN_ROOT}/internal/contracts/handoff.schema.json` with
   `role: "implementer"`, `mode: "build"`, this task's ID, the write set,
   artifact paths and hashes, and the micro-gate commands. Pass the handoff path,
   never the documents themselves.

   Claude-only: the `my-plan-implementer` agent, Sonnet. Hybrid: Luna via Codex,
   workspace-write sandbox, per `${CLAUDE_PLUGIN_ROOT}/internal/codex.md`.

   Include a `kind: "task"` artifact: the instruction, the requirements that bear
   on this task, the paths, the dependencies already satisfied, and the checks
   that prove it done. Extract it from the plan; do not hand over the plan.

   **Write it to `<worktree>/.my-plan/task.md`, and add `.my-plan/` to the
   worktree's `.git/info/exclude`.** A Codex Worker is confined to the worktree
   and cannot read Run state outside it, so the artifact has to live inside; and
   anything inside that Git tracks would show up in the Review Subject as a path
   nobody approved. Excluding it locally solves both: readable by the Worker,
   invisible to the diff, and never committed.

   `.git/info/exclude` rather than `.gitignore`, because `.gitignore` is a tracked
   file in the user's repository and this is scaffolding, not a project decision.

   Overwrite it per task. It is a scratch file for the current Worker, not a
   record; `implementation.md` is the record.

   Send `validationCommands` only for a task running alone. A task running
   alongside others gets none: the Coordinator runs its gate afterwards, in turn.

   The writer must not need the full specification or the full plan. Sending them
   defeats the point of small tasks: the writer burns its context on work that is
   not its own and arrives at its own task with less room than it started with.
   Anything it needs that is not in the repository goes in the task artifact or in
   `notes`.

2. **Reuse the session, within reason.** Keep the same implementation Worker
   across tasks so verified conventions and correction notes carry forward.

   Reset at a task boundary when the session is demonstrably confused, repeating
   corrected mistakes, or has simply run long. These models degrade over a long
   session, and a fresh session with good notes outperforms a tired one with full
   history. Resetting mid-task throws away context that was still working.

3. **Verify the claim.** Validate the returned result against
   `${CLAUDE_PLUGIN_ROOT}/internal/contracts/build-result.schema.json`. Then check
   `changedPaths` against the real Git diff and the approved write set. A Worker's
   report of what it changed is a claim; Git is the evidence. A path outside the
   write set stops the task.

4. **When a task comes back `blocked`.** Never re-dispatch the same handoff to
   the same Worker and hope. Diagnose first, then act:

   | Cause | Response |
   |-------|----------|
   | The handoff was missing context the Worker needed | Fix the handoff, re-dispatch in the same session |
   | The task needs more reasoning than the model has | Escalate one step up the fallback table |
   | The task was too large to hold at once | Split it and reassign. Then check whether its siblings are oversized too |
   | The plan itself is wrong | Return to planning with the evidence |
   | Failures are in files this task does not own | A parallel writer's in-flight edit, not a defect. Re-run the check once that task settles. Never escalate this |
   | `needsDecision: true` | A product question. It goes to the user, not to another Worker |

   Three failed attempts at the same finding means the defect is in the plan or
   the design, not in the attempt. Route it upward instead of patching a fourth
   time.

5. **Micro-gate.** Run the fastest relevant lint, type-check, compile, or build
   check. Not the full suite; that is the Validation Gate's job.

6. **Review the delivery, now.** Do not wait for the last task.

   First inspect the delta yourself against the specification, plan, project
   skill, and Architecture Memory. Then dispatch the independent reviewer in
   `incremental` mode over just this task's diff.

   Reviewing each delivery as it arrives is what keeps the writer's job small. A
   defect found now costs one small correction against code the writer just wrote.
   The same defect found after ten tasks arrives as a large diff, against context
   the writer no longer holds, in a session that has already degraded.

7. **Remediate before moving on.** Send verified findings back to the writer
   sequentially, not as a list.

   One finding, or one tightly related group, per correction round. Confirm it
   closed, then send the next. A writer handed twelve findings at once fixes the
   first few properly and pattern-matches the rest, and the review round after
   that has to sort out which is which.

   Between correction rounds run the micro-gate and the checks affected by that
   correction. Not the full Validation Gate: with one finding per round, running
   every required Project Profile command each time costs more than the entire
   implementation and proves nothing new about untouched code. The full gate runs
   after the last task and after final-review remediation, where it belongs.

   Do not assign the next task until this one's findings are closed or explicitly
   dispositioned. A problem carried forward multiplies: the next task builds on
   it, and the correction stops being local.

   For parallel tasks, each has its own review and remediation, keyed by its
   `taskId`. Do not merge their findings into one queue; the writers are different
   sessions and identical finding ids can mean different defects.

8. **Stage and record.** Stage only paths this task and this Run own. Never
   `git add -A`. Confirm the completed plan checkbox against the actual diff, then
   update `implementation.md`, rendering it from
   `${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/implementation.md.tpl` on
   the first task.

   Staging is the checkpoint. The next task's delta is then measured against the
   index, so each review sees only what is new.

## Adapt as you go

The plan's task sizes were an estimate made before any code existed. Correct them
with what actually happens.

A task that came back clean, first try, with no findings, suggests the next one
can be slightly larger. A task that needed three correction rounds, came back
`blocked` as too large, or produced findings about things the writer could not
have known, means the remaining tasks are too big. Split them before assigning,
not after they fail.

**Splitting a task revises the plan.** Do not invent task IDs on the fly and
dispatch them: the plan was independently reviewed, and work that never appeared
in it was never reviewed either. Update `plan.md` with the new task IDs, their
paths, dependencies, and checks; run `plan-check` over the revision; renew the
plan hash; then dispatch. The review is cheap because only the changed section is
new, and skipping it means the write set, the dependencies, and the checks of the
work you are about to run had no independent look at all.

Growing a task within its existing scope needs no revision. Adding work does.

Record the resizing in `notes` so the writer inherits the convention rather than
rediscovering it.

## Shared resources

A worktree isolates files. It does not isolate a fixed database, a fixed port, an
emulator, or a deployment target: two Parallel Runs reaching for the same one will
collide, and the failure looks like a flaky test rather than a collision.

Take a resource lease around the window where that resource is actually in use,
and release it as soon as the work is done. Never hold one across a whole phase,
and never hold one while a model is reasoning.

## After the last task

Per-task review catches local defects. It cannot catch what emerges between tasks,
because no single delivery contains it.

So review the complete feature diff before the Validation Gate, looking for:

- Drift: the same concept implemented two ways in different tasks.
- Duplicated helpers introduced independently by writers that could not see each
  other's work.
- Inconsistent naming across task boundaries.
- Dead code left behind by a later task.
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

### Changelog

Before committing, record what shipped in the repository's changelog.

Adopt whatever the repository already uses: `CHANGELOG.md`, a `changelog/`
directory, release notes, or the convention its history shows. Create
`CHANGELOG.md` in Keep a Changelog form only when none exists.

Write one entry for the Run, from the user's point of view: what changed for
someone using this software, grouped as added, changed, fixed, or removed. Not
task IDs, not internal steps, not which worker did what. Someone reading it later
wants to know what the software does differently now.

Skip it when the change is invisible to users: a refactor with no behavior change,
a test-only change, internal documentation. An entry that says "refactored
internals" is noise in a file people read to find out what broke.

The changelog is part of the Review Subject, so it is written before the review
that approves delivery, not after.

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
