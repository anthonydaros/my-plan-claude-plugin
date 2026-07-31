# Stage: Planning

Turn the approved specification into an executable plan, and have an independent
Worker review it before any code is written.

Entered only after `approvedSpecHash` matches the current specification.

## Before planning: the worktree

Approval authorizes repository mutation. Set up isolation first.

1. Fetch and resolve the latest default-branch base. Record the exact base SHA.
2. Create a Run-unique temporary branch and an external worktree at that SHA.
   Short path, outside both the source repository and the plugin cache.
3. In Workspace Mode, one worktree per affected repository.
4. In Greenfield Mode, revalidate before mutating anything: the directory must
   still be empty and the approved Git identity must still be active. Time passed
   between discovery and approval, and `git init` over a directory someone has
   since put files into is not the operation the user approved. Any new file
   aborts the mutation and goes back to the user as evidence, exactly as a
   non-empty directory would have during discovery.

   Then initialize Git with `main`, create the minimal empty Bootstrap Commit, and
   create the branch and worktree from it. The Bootstrap Commit contains no
   scaffold and no feature code.

Worktree creation takes a short atomic repository lock. Release it immediately. A
lock is never held while a model reasons.

The primary checkout is never touched, and a dirty checkout is never stashed,
reset, cleaned, or overwritten.

## Writing the plan

Render `plan.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/plan.md.tpl`.

Dispatch the `my-plan-planner` agent, Opus, in both backends. Fable does discovery
and review; it does not plan.

Build a handoff with `role: "planner"`, `mode: "plan-write"`, and artifact paths and
hashes for the approved specification, the Architecture Memory, the project skill,
and the discovery record. Its write set is the single `plan.md` path.

Record each normative fact once. Reference the specification, Architecture Memory,
project skill, research record, and contracts by path. Do not copy their contents
into the plan; a plan that duplicates the specification will drift from it.

Each task states:

- Exact files or modules, and whether they exist or will be created.
- Current state.
- Intended modification.
- Dependencies on other tasks, if real.
- Test impact.
- The check that proves it done.

Rules:

- No implementation code in the plan. Pseudocode that is really code is code.
- One phase, unless a genuine sequencing dependency requires more. Phases invented
  for tidiness slow the Run and prove nothing.
- The write set equals the approved specification's write set exactly. A path the
  tasks need but approval does not cover is a scope change: revise the
  specification, take an ordinary approval, renew `approvedSpecHash`. The plan
  never widens its own authority.
- That set already includes the Run Dossier directory, the Architecture Memory
  when this Run updates it, and the Project Skill when this Run materializes it.
  If the approved specification is missing any of them, it is the specification
  that needs the revision, not the plan that needs an exception. Reviewers check
  the diff against this set with no carve-outs, so an unlisted Run document blocks
  delivery exactly like an unlisted source file.
- Reuse before adding. Name the existing helper, pattern, or installed dependency
  the task should use. A new abstraction needs a reason the existing code cannot
  serve.
- Non-trivial new behavior gets a check. Auth, deletion, persistence, payment,
  cost, and external contract paths require a behavioral or integration check.
- A refactor task touching code with no existing coverage declares a
  characterization check as its first step: pin the current behavior exactly as it
  is, without judging whether it is correct, then refactor under that net.
  Otherwise the task adds no new behavior, so no check is required, and a silent
  regression ships through every gate untouched.

## Overlap with other Runs

Once the write set is fixed, compare it against the write sets of every other
unfinished Run for this repository in state.

Report any overlapping path as integration risk. Do not block on it: the Runs are
in separate worktrees and can both proceed safely. The risk is at integration, and
the person who should know about it early is the user, not a lock.

Note in the same place any shared external resource the work needs that cannot be
namespaced per Run: a fixed database, a fixed port, an emulator, a deployment
target. Those cannot be isolated by a worktree and are handled with a lease during
implementation.

## Tasks are sized for the writer, not for the reader

The models that write code hold a limited working context and degrade over a long
session. A task that is obvious to a planner reading the whole specification can
be impossible for a writer that only receives that task.

So the unit of work is not "a feature". It is the smallest change that:

- Touches a handful of files, not a subsystem.
- Carries one idea. If describing it needs the word "and" twice, it is two tasks.
- Can be verified on its own by a check the task itself names.
- Leaves the worktree buildable.
- Needs no knowledge the handoff does not carry. Assume the writer has never seen
  this repository and will not see the other tasks.

A large goal becomes many small tasks. Never one task that says "build the
feature": that is the single most reliable way to get plausible code that does not
work. Write the sequence out, however long it gets. A plan with twenty precise
tasks beats a plan with three ambitious ones.

Never separate a contract from its implementation and its wiring: that task is not
buildable on its own and its check proves nothing. Cohesion decides where the line
falls; size decides how many lines there are.

Genuinely trivial work stays one task. Splitting a two-line change into ceremony
wastes a Run.

## Order and parallelism

Declare real dependencies per task, and only real ones.

- **Sequential** when a task needs the output, the types, or the conventions
  another task establishes. Foundations first: a contract before its consumers, a
  migration before the code that reads it.
- **Parallel** when tasks touch disjoint paths and neither needs the other's
  result. Independent writers can run at once, one per path. Never two writers on
  the same file.

A task that only "feels" like it should come later is not a dependency. False
sequencing turns a parallel plan into a slow one for no safety gained.

## Plan review

Dispatch a different Worker than the one that wrote the plan. Claude-only: the
`my-plan-reviewer` agent, Fable, read-only. Hybrid: Sol at `xhigh` effort via
Codex, read-only sandbox, per `${CLAUDE_PLUGIN_ROOT}/internal/codex.md`.

Build a handoff matching `${CLAUDE_PLUGIN_ROOT}/internal/contracts/handoff.schema.json`
with `role: "reviewer"`, `mode: "plan-check"`, and artifact paths and hashes for
the specification, plan, Architecture Memory, and project skill. Pass the handoff
path. Never paste the documents into the prompt.

Validate the returned result against
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/review-result.schema.json` before
trusting it. Check that `subjectHash` matches the plan you sent. Invalid or
unparseable output is a failed attempt, never an implicit approval.

### Remediation

Fix valid findings. Record justified pushback with its reasoning; a finding you
disagree with stays visible, it does not silently disappear.

Findings live in the Finding Ledger and, at the end, in `review.md`. They never
accumulate inside `plan.md`. A plan carrying its own review history becomes
unreadable by the third round.

Loop until there are no open blockers. This introduces no second user gate; the
approved specification already authorized this phase.

### Budget

After three plan-review rounds or thirty minutes, rotate to a fresh role session
with the current plan, only the pending findings, and new evidence. Closed
findings stay in the ledger and are not resent.

Rotation is not failure and not a reason to rewrite the plan or ask for approval.

### Stagnation

Progress means a pending finding closed, or new evidence materially changed one.
Rewording a finding, changing prose, or re-reading an unchanged plan is not
progress.

Three consecutive rounds without progress end the Run as `BLOCKED`. Report what
remains open and why. Do not approve incomplete work to escape the loop.
