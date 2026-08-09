# Stage: Implementation

Build the reviewed plan in the isolated worktree, prove it works, and deliver it.
Covers worktree creation, task execution, the Validation Gate, commit,
integration, and push. Entered from `/my-plan:exec` against a Run whose phase is
`planned` or later; that skill's entry checks have already verified the spec,
the plan, and the task files before this stage begins.

No user gate exists in this stage. The approved specification already authorized
all of it, and invoking `/my-plan:exec` was the user deciding when. Asking for
permission you already have is a defect, not caution.

## Before the first task: the worktree

Runs once, when the phase is exactly `planned`. A Run resumed later than that
already has a worktree, and re-entering here would re-resolve a base that is
already fixed.

1. Fetch and resolve the latest default-branch base. Record the exact base SHA.
   A repository with no remote skips the fetch; local `main` is the base.
2. Compare what moved since planning:
   `git diff --name-only <plannedBase>..<baseSha>`, where `plannedBase` comes
   from the plan's frontmatter, intersected with the write set and the paths
   the task files declare. A hit on a task's path, or a path a task names as
   existing that no longer does, goes back through `plan-check` over the
   affected tasks before any code is written: the plan was reviewed against a
   repository that has since moved. A hit only on the wider write set is
   reported as risk, and execution proceeds. If `plannedBase` is unreachable —
   force-pushed away, shallow history — fall back to checking that every path
   the tasks name as existing still exists, and say that the weaker check is
   the one that ran. Repeat planning's Overlap comparison against other
   unfinished Runs in the same pass; that snapshot may be weeks old.
3. Create a Run-unique temporary branch, named `my-plan/<run-id>`, and an
   external worktree at that SHA under
   `<stateRoot>/worktrees/<repo-key>/<run-short>/`. In Workspace Mode, one
   worktree per affected repository.
4. Write `baseSha`, `branch`, and `worktree` to `run.json` immediately, in one
   manifest update, before anything else happens. A crash between creation and
   this write leaves a branch no manifest explains. On re-entry, non-null
   values at phase `planned` mean creation already happened: resume from the
   next step and never re-resolve the base — the recorded `baseSha` wins. A
   branch that already exists when this step tries to create it is either this
   Run's own interrupted entry — a crash after creation, before the write — or
   another session's. Adopt it only when all three hold: the Run's worktree is
   registered at the expected path, its status is clean, and the branch tip
   still equals the base just resolved, meaning nothing was ever built on it.
   Then record the real values in `run.json` and continue. Anything else —
   commits on the branch, a dirty tree, an unregistered branch — is not yours
   to adopt: stop and say so.
5. Set `phase` to `implementation` under the same discipline every manifest
   write uses: re-read `manifestRevision` first, increment it, and treat a
   revision that moved underneath as another session's Run.

In Greenfield Mode, steps 1 to 3 do not apply: there is no repository to fetch
from and no base to resolve. Revalidate before mutating anything: the directory
must still be empty apart from the task files this Run wrote, exactly as
`taskFiles` records them, and the Git identity must still be the one recorded
in the specification. Time passed between planning and execution, and
`git init` over a directory someone has since put files into is not the
operation the user approved. Any unexpected file aborts the mutation and goes
back to the user as evidence.

Greenfield discovery records the Git identity in the specification's decision
register, because an empty directory has no repository to read one from. If the
configured identity differs from the recorded one, stop and ask: committing
under an identity the user did not approve is not recoverable by editing a
file.

Then:

```sh
git init -b main            # requires Git 2.28+, verified during setup
git commit --allow-empty -m "Initialize repository"
git rev-parse HEAD          # this is baseSha
git worktree add -b my-plan/<run-id> <worktree-path> <baseSha>
```

The Bootstrap Commit is empty by construction: no scaffold, no feature code, no
configuration. Everything else happens inside the worktree afterwards. The task
files stay untracked where they are; the bootstrap commits nothing.

Worktree creation takes a short atomic repository lock. Release it immediately.
A lock is never held while a model reasons.

The primary checkout is never stashed, reset, cleaned, or overwritten, and this
stage writes nothing into it with one exception: the Run's own task files,
which it deletes one by one as their tasks complete, and never stages.

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

   Hybrid: Terra at `high` via Codex, workspace-write sandbox, per
   `${CLAUDE_PLUGIN_ROOT}/internal/codex.md`. Claude-only: the
   `my-plan-implementer` agent, Sonnet at `high`. Some tasks belong on Luna and
   some on Sol from the first attempt; the criteria are in
   `${CLAUDE_PLUGIN_ROOT}/internal/stages/project.md` and the choice is per task,
   not per Run.

   opencode `Pro` runs this task instead of Codex when the user names it
   explicitly for the task or Run, or when Codex fails this task on a
   quota/usage-cap classification — see Codex fallback, below, and the
   Implementation paragraph under Model mapping in `project.md`. Per
   `${CLAUDE_PLUGIN_ROOT}/internal/opencode.md`.

   Include a `kind: "task"` artifact: the task's own file from `<tasksDir>`,
   plus the conventions accumulated in `notes`. Planning wrote that file for
   exactly this reader — it already carries the paths, the behavior, the edge
   cases, and the checks — so there is nothing to extract and no plan to hand
   over.

   **Copy it to `<worktree>/.my-plan/task.md`, and add `.my-plan/` to the
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
   `${CLAUDE_PLUGIN_ROOT}/internal/contracts/build-result.schema.json`, then check
   `changedPaths` against the real Git diff and the approved write set. A Worker's
   report of what it changed is a claim; Git is the evidence. A path outside the
   write set stops the task.

   Validate by reading the schema and checking the result against it yourself:
   every required field present, every enum a listed value, no field the schema
   does not allow. Do not install a validator, and do not add a dependency to the
   user's project to check your own plumbing. If a validator already exists in the
   repository, using it is fine.

   The schemas are small and the check is mechanical. What matters is that it
   actually happens: an unvalidated result is a Worker's word for what it did.

4. **When a task comes back `blocked`.** Never re-dispatch the same handoff to
   the same Worker and hope. Diagnose first, then act:

   | Cause | Response |
   |-------|----------|
   | The handoff was missing context the Worker needed | Fix the handoff, re-dispatch in the same session |
   | The task needs more reasoning than the model has | Escalate one step: Luna to Terra, Terra to Sol at `xhigh`, Sonnet to Opus. Sol at `max` only after `xhigh` has failed |
   | The task was too large to hold at once | Split it and reassign. Then check whether its siblings are oversized too |
   | The plan itself is wrong | Return to planning with the evidence |
   | Failures are in files this task does not own | A parallel writer's in-flight edit, not a defect. Re-run the check once that task settles. Never escalate this |
   | The host denied the Worker's write to a path inside its write set | Have the Worker return the exact intended content, apply it yourself byte for byte, and record in `implementation.md` what was applied and why the Worker could not. You are the Worker's hands here, not a second writer: never alter, extend, or improve what it specified |
   | `needsDecision: true` | A product question. It goes to the user, not to another Worker |

   An escalation moves the reviewer too. Sol reviews Terra's code, so a task Sol
   wrote goes to `my-plan-reviewer-deep` on Opus instead; the writer never
   reviews itself, whichever direction the ladder moved.

   Three failed attempts at the same finding means the defect is in the plan or
   the design, not in the attempt. Route it upward instead of patching a fourth
   time.

5. **Micro-gate.** Run the fastest relevant lint, type-check, compile, or build
   check. Not the full suite; that is the Validation Gate's job.

6. **Review the delivery, now.** Do not wait for the last task.

   First inspect the delta yourself against the specification, plan, project
   skill, and Architecture Memory. Then dispatch the independent reviewer in
   `incremental` mode over just this task's diff.

   Run `git add -N` on any new file first. Untracked files do not appear in
   `git diff` at all, so a task that only adds files produces an empty diff and
   the reviewer approves nothing while believing it reviewed everything. This is
   silent: no error, no warning, just a clean review of an invisible change.

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

8. **Stage, record, then delete the task file.** Stage only paths this task and
   this Run own. Never `git add -A`. Confirm the task's delta against what its
   task file promised, then update `implementation.md` in Run artifacts,
   rendering it from
   `${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/implementation.md.tpl` on
   the first task.

   Staging is the checkpoint. The next task's delta is then measured against the
   index, so each review sees only what is new.

   Record the task in `run.json` — `completedTaskIds`, `currentTaskId` — and
   only then delete its file from `<tasksDir>` and drop it from `taskFiles`.
   The record always precedes the deletion: a deleted file with no record is a
   task that will be run twice. The file's absence is what tells the user the
   task is done, and the shrinking directory is the visible progress bar. Task
   files are never staged and never committed; deleting one is housekeeping in
   the primary checkout, not part of the Review Subject.

## Between tasks, shed what you no longer need

Task boundaries are the safe place to compact, and a twenty-task Run needs them.

After recording a task, drop its details from working context: the diff you
already inspected, the findings you already closed, the file contents you already
acted on, the Worker's reasoning. Keep the plan's remaining tasks, open findings,
the conventions in `notes`, and the current phase.

Record before you drop. `run.json` gets `currentTaskId` and `completedTaskIds`;
`implementation.md` gets the task's row. A task that completed but was not
recorded is a task that will be done twice, and the second attempt will conflict
with the first.

Never compact mid-task or mid-review-round. Finish the unit, record it, then
shed.

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
in it was never reviewed either. Update `plan.md`'s task table, write the new
task files into `<tasksDir>`, delete the file of the task they replace; run
`plan-check` over the revision; renew `planHash` and `taskFiles`; then dispatch.
The review is cheap because only the changed section is new, and skipping it
means the write set, the dependencies, and the checks of the work you are about
to run had no independent look at all.

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

For implementation specifically, a quota/usage-cap classification does not drop
straight to `claude-only`. Try `opencode:pro@high` first, per
`${CLAUDE_PLUGIN_ROOT}/internal/opencode.md`, when opencode has passed its
capability probe. Fall to `my-plan-implementer` only when opencode is
unavailable or fails the same task too. A task already running on Sol does not
step down to opencode `Pro` on failure — that would be a capability downgrade
dressed as a fallback — it goes straight to the matching Claude depth instead.
Every other role's Codex fallback goes straight to `claude-only`, unchanged:
opencode is not wired into plan creation, review, or audit.

The transition is sticky for this Run. Record phase, role, error class,
replacement model, and time in `implementation.md`. A later Run probes Codex
again.

Fallback continues from current canonical artifacts. It never repeats discovery,
requests approval again, or discards valid work. If a Codex Worker left a partial
diff, verify the real changed paths against the write set first, then let
opencode `Pro` or Sonnet — whichever this fallback resolved to — continue the
remaining tasks in the same worktree.

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

This record is a claim until someone else runs it. The QA gate in `review.md`
executes these same commands from a Worker that did not write the code, and
compares what it observes against what this record says. Write the record so that
comparison is possible: exact commands, real exit codes, no summarizing.

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

The same rule covers the push gate: commits produced in an earlier session are
never pushed on that session's green record. Rerun the required commands first,
even when the base has not moved — a `DONE_LOCAL` Run whose push the user
finally approves gets this revalidation before anything leaves the machine.

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
`docs/CHANGELOG.md` in Keep a Changelog form only when none exists.

The changelog is the Run's only permanent record in the repository. The working
documents die with the Run, so this entry is written for a reader who will
never see the paperwork behind it.

Write one entry for the Run, from the user's point of view: what changed for
someone using this software, grouped as added, changed, fixed, or removed. Not
task IDs, not internal steps, not which worker did what. Someone reading it later
wants to know what the software does differently now.

Skip it when the change is invisible to users: a refactor with no behavior change,
a test-only change, internal documentation. An entry that says "refactored
internals" is noise in a file people read to find out what broke.

The changelog is part of the Review Subject, so it is written before the review
that approves delivery, not after.

### Before every commit: check what you are about to publish

Run this on the staged set, every time. A secret committed once is a secret
leaked, even if the next commit removes it, because the object stays in history
and history is what gets pushed.

1. **Inspect the staged list itself.** `git diff --cached --name-only`. Anything
   you did not expect stops the commit.

2. **Refuse these paths outright**, whatever the diff says:
   `.env` and `.env.*` other than `.env.example`, `*.pem`, `*.key`, `*.p12`,
   `*.pfx`, `id_rsa` and other private keys, `*.keystore`, `.npmrc` and `.pypirc`
   with credentials, `credentials.json`, `service-account*.json`,
   `*.tfstate`, `.aws/`, `.ssh/`, `.kube/config`, and any local database dump.

3. **Grep the staged content** for assigned secrets: `password`, `passwd`,
   `secret`, `token`, `api[_-]?key`, `private[_-]?key`, `authorization`,
   `bearer `, `BEGIN .* PRIVATE KEY`, plus provider prefixes such as `sk-`,
   `ghp_`, `gho_`, `AKIA`, `AIza`, `xox[baprs]-`. A hit that is a real value, not
   a variable name or a placeholder, stops the commit.

4. **Read the Run's own documents before staging them.** Discovery quotes code,
   research quotes sources, and specs quote configuration. A credential the
   Coordinator copied into `discovery.md` while investigating is a leak the code
   scan will not catch, because it is prose.

5. **Check the ignore rules cover what this project produces.** If the repository
   generates a local env file, a dump, or a key and `.gitignore` does not mention
   it, add it in this Run and say so. Do not silently rely on it never being
   staged.

When something trips this, do not commit and quietly drop the file. Tell the user
what was found and where, remove it from the staged set, and fix the ignore rule
so it cannot come back. A finding here is worth interrupting for.

Personal paths, machine names, internal hostnames, and customer identifiers get
the same treatment. They are not credentials, but they are not yours to publish.

### Commit

One commit for a small cohesive change; multiple atomic commits when independent
changes make better history.

Commit as the work completes, not once at the end. Local commits are authorized by
the approved specification, are reversible, and give the user real history to read
before deciding whether any of it should leave the machine.

**Authorship is the user's, always.** Commit with the repository's configured Git
identity, exactly as it is. Never override `user.name` or `user.email`, never add
a `Co-Authored-By` trailer, and never name a model, an assistant, or this plugin
anywhere in a commit message. The message describes the change, not what produced
it. A repository's history belongs to the person responsible for it.

Write the message about what changed and why, in the repository's existing commit
style. If the repo uses conventional commits, use them; if it does not, do not
introduce them.

Stage exactly the approved write set as the diff realized it: the product
paths, plus the changelog when the change is user-visible. Verify the staged
path list equals that set before committing. Never `git add -A`.

Nothing else exists to stage. The Run's working documents — including
`review.md` and `delivery.md`, which record this very commit's approval — live
in Run artifacts outside the repository, and the task files are never staged:
they are the Run's scaffolding in the primary checkout, already shrinking as
tasks complete, and none of them belong in the history. A staged path outside
the write set is a blocker, reported with the path, whatever it is and however
reasonable it looks.

Version bumps and tags only when the Project Profile or the approved specification
requires them. Do not impose semantic versioning, tags, README version edits, or
generated changelogs on ordinary work.

Never write a secret into a tracked file. Never use `--no-verify`.

**Check whether it already happened.** A dispatched commit has a window the inline
one did not: the Worker can create the commit and the session can end before the
result is recorded. Resume then finds a manifest that says the commit is pending
and a repository where it is done.

Ask the repository, not the manifest. `git log baseSha..HEAD` on the Run's branch,
against the Review Subject paths. If the work is already committed, record the
SHAs and move to the push gate. Do not dispatch again.

This check has to come first, because nothing downstream would catch its absence.
A committer dispatched onto an already-clean tree finds nothing to stage and
either commits empty or reports success with no commits, and the write-set
verification passes both times — no path changed, so no path is out of bounds. The
duplicate would surface at the push gate, as a commit the user did not expect,
which is the worst place to discover it.

**The commit is dispatched, not typed here.** Run the scan above yourself — it is
yours and it stays yours — then hand the commit to `my-plan-committer` on Sonnet,
in both backends, with `role: "committer"`, `mode: "commit"`, a `writeSet` of
exactly the paths this commit may contain, and the delivery manifest as an
artifact. Validate the result against
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/commit-result.schema.json`.

It is a fresh session for a reason. You have watched this entire Run and you know
why every file is present, which is precisely what makes you a poor judge of
whether a staged path belongs in the history. A Worker that reads the staged diff
cold, knowing only the approved write set, catches the thing familiarity hides.
That is the same argument that keeps the writer out of the review, applied to the
last step where anything can still be caught.

Then verify what it returned, against the repository rather than against its
report:

- `git diff --cached --name-only` and `git log` for the real staged set and the
  real SHAs. A commit it claims that Git does not have voids the attempt.
- Every path in every commit is inside the write set. A path outside it is a
  violation, not a surprise to accept.
- `git for-each-ref refs/remotes` is unchanged. `remoteRefsTouched` must be empty,
  and this is the check that proves it rather than trusting it. A committer that
  moved a remote ref has broken the push gate, and the Run stops there.

A `status: "refused"` result is the gate working. Show the user what it refused
and why, fix the cause, and dispatch again. Never stage around a refusal, and
never commit the remainder to make progress.

### The push gate

Stop here. Everything so far was local and reversible; everything after leaves the
machine and cannot be taken back.

Show the user:

- What was built, in a sentence or two.
- The commits, by subject line.
- What validation ran and that it is green.
- The target: remote and branch.
- Anything held back, such as a deployment.

Then ask whether to push.

Accept any plain affirmative: `yes`, `sim`, `push`, `pode`, `manda`. Anything else
is not approval, including silence, a question, or a comment about the work. If
the user asks something, answer it and ask again.

One push per Run, not one per commit. The user approves the whole body of work
once, having seen it.

If approval does not come, the Run is finished and unpushed. Record it, tell the
user the work is committed and safe on its branch and how to push it themselves,
and stop. Do not push later on the assumption they meant yes.

A Run parked `DONE_LOCAL` that way re-enters at exactly this gate:
`/my-plan:exec` on such a Run comes straight here — never back through
implementation — reruns the required validation commands per Cold resume
revalidates, shows this same summary, and asks again.

Never treat the specification approval as covering this. That approval was given
before any code existed.

### Integration

Only after the push gate. Optimistic two-phase locking:

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
push result, verified remote SHA, completion status, and timestamp. Compute and
record the delivered subject hash alongside them, in the pinned form
`project.md`'s hash table defines, over the integration base this record
already carries. The in-flight hash stops being recomputable once the index
moves; the delivered form is the one that still verifies weeks later.

In the same step, append this Run to `repos/<repo-key>/repo.json.runs[]`:
`runId`, `status`, `finalSha`, `completedAt`. A Run's own artifacts die with
it; this index is the only durable list of a repository's Runs, and it is what
keeps completed and cancelled Runs enumerable after their state is purged. In
Workspace Mode, repeat this per repository the Run touched, each under its own
`repoKey` with its own `finalSha`. Check first whether an entry for this
`runId` already exists in that `repo.json`; a Completion step re-run after a
resumed session records nothing twice.

Create no post-push documentation commit. The approved specification stays
unchanged.

Remove the worktree and temporary branch only after remote SHA verification. In
a repository with no remote there will never be one to wait for: the verified
local fast-forward — the default branch resolving to the Run's final commit —
takes its place. Preserve unintegrated or dirty Runs for recovery.

Do this only once status is `DONE`, `DONE_LOCAL`, or `READY_FOR_DEPLOY` and the
final commit is confirmed on the target branch: a `DONE_LOCAL` from a declined
push has no commit there yet, so its worktree stays for the eventual push. Never
remove a worktree carrying changes this Run has not staged, committed, and had
reviewed — that deletes unassessed work instead of deferring it.

Before removing, confirm the worktree is clean: `git -C <worktree-path> status
--porcelain` returns nothing. A non-empty result — staged, modified, or
untracked — is unassessed work, indistinguishable from a dirty Run, and this
step preserves it exactly like one: leave the worktree in place instead of
removing it, and revisit on the next session. Never pass `--force` to `git
worktree remove` to push past a non-empty status; forcing is what turns this
safeguard into the data loss it exists to prevent.

Run the removal from the main checkout, never from inside the worktree being
removed: `git worktree remove <worktree-path>`, then `git branch -d
my-plan/<run-id>`. The Run is not closed until this succeeds; a worktree still
on disk is a Run still open, whatever `run.json` says.

Purge the Run's state in the same closing step and under the same condition:
delete `<stateRoot>/runs/<run-id>/` — the artifacts were working documents, and
the changelog entry that shipped is the record — and confirm `<tasksDir>` holds
no file of this Run's, which should already be true because each was deleted as
its task completed. Remove the task directory itself only when this Run created
it and it is now empty. A `DONE_LOCAL` from a declined push keeps its artifacts
exactly as it keeps its worktree: the eventual push still needs the evidence,
and the purge happens when that push finally verifies, or when the user cancels
the Run instead.

Final status:

| Situation | Status |
|-----------|--------|
| Pushed and remote SHA verified, no deployment target | `DONE` |
| Verified, deployment target exists | `READY_FOR_DEPLOY` |
| Work complete and committed, push not approved | `DONE_LOCAL` |
| Greenfield, intentionally local-only, local commit verified | `DONE_LOCAL` |
| Repository has no remote at all, local commit verified | `DONE_LOCAL` |
| Required remote failed, or a push failed mid-workspace | `BLOCKED`, recoverable |

`DONE_LOCAL` from a declined push is a completed Run, not a failure. The work is
done, reviewed, validated, and committed; the user simply chose not to publish it
yet. Report it that way.

Deployment is never implied by code delivery. It requires separate explicit
approval naming the target.

### Final report

Short: completed work, validations run, commit identifiers, verified remote SHA,
and any deployment hold. The changelog entry carries the user-facing record and
`repos/<repo-key>/repo.json` the identifiers; the working documents are gone
with the Run, which is what they were for.

If something was blocked, say plainly what and why. Never report success you did
not verify.
