# Stage: Planning

Turn the approved specification into an executable plan, and have an independent
Worker review it before any code is written.

Entered only after `approvedSpecHash` matches the current specification.

## Before planning: the worktree

Approval authorizes repository mutation. Set up isolation first.

In an existing repository:

1. Fetch and resolve the latest default-branch base. Record the exact base SHA. A
   repository with no remote skips the fetch; local `main` is the base.
2. Create a Run-unique temporary branch, named `my-plan/<run-id>`, and an external
   worktree at that SHA under `<stateRoot>/worktrees/<repo-key>/<run-short>/`.
3. In Workspace Mode, one worktree per affected repository.

In Greenfield Mode, steps 1 to 3 do not apply: there is no repository to fetch
from and no base to resolve. Start at step 4, which creates all of it.

4. In Greenfield Mode, revalidate before mutating anything: the directory must
   still be empty, and the Git identity must still be the one recorded in the
   specification. Time passed between discovery and approval, and `git init` over
   a directory someone has since put files into is not the operation the user
   approved. Any new file aborts the mutation and goes back to the user as
   evidence, exactly as a non-empty directory would have during discovery.

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
   configuration. Everything else is materialized inside the worktree afterwards.

Worktree creation takes a short atomic repository lock. Release it immediately. A
lock is never held while a model reasons.

The primary checkout is never touched, and a dirty checkout is never stashed,
reset, cleaned, or overwritten.

## Writing the plan

Render `plan.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/plan.md.tpl`.

A plan is a depth problem, so it goes to the deepest tier available. Hybrid: Sol
at `high` via Codex, per `${CLAUDE_PLUGIN_ROOT}/internal/codex.md`. Claude-only:
the `my-plan-planner` agent, Opus at `high`.

`high` is the working default, because a plan is rarely improved by spending
twice as long on it. A plan that changes architecture, moves data, spans several
systems, or makes a decision nobody can walk back is the exception, and it
escalates to Sol at `xhigh`.

Build a handoff with `role: "planner"`, `mode: "plan-write"`, and artifact paths
and hashes for whichever of these exist: the approved specification, the discovery
record, the Architecture Memory, and the project skill. Its write set is the
single `plan.md` path.

In Greenfield Mode the last two do not exist yet, and that is expected: they are
created inside the worktree after this. Send what exists. Never send a path to a
file that is not there, and never omit one that is.

Copy any pre-approval artifact the Worker needs into `<worktree>/.my-plan/` before
dispatching, and point the handoff at the copy. A Worker confined to the worktree,
which every Codex Worker is, cannot read a Run artifacts path outside it — and a
plugin path is outside it too, so a Codex planner gets `plan.md.tpl` copied there
as well.

Add `.my-plan/` to the worktree's `.git/info/exclude` when creating the worktree,
so those copies never reach the Review Subject or a commit.

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
- The structure is the smallest one that still holds the rules, the security, and
  the testability the specification asks for.
  `${CLAUDE_PLUGIN_ROOT}/internal/checklists/architecture.md` is the standard,
  and the plan answers its five questions in writing for every layer, interface,
  factory, or pattern it introduces. The plan reviewer checks exactly that, so an
  unanswered question is a round that could have been avoided here.
- Non-trivial new behavior gets a check. Auth, deletion, persistence, payment,
  cost, and external contract paths require a behavioral or integration check.
- A refactor task touching code with no existing coverage declares a
  characterization check as its first step: pin the current behavior exactly as it
  is, without judging whether it is correct, then refactor under that net.
  Otherwise the task adds no new behavior, so no check is required, and a silent
  regression ships through every gate untouched.

## Overlap with other Runs

Once the write set is fixed, run its impact radius against the code graph when
one is `fresh`. A path the radius returns that the approved write set does not
cover is an integration risk to state in the plan, next to the overlaps below.

It is never a reason to widen the write set. The rule above stands unchanged: a
path the tasks need but approval does not cover is a scope change that goes back
to the specification. What the graph adds is finding that out now instead of at
the final review.

Then compare the write set against the write sets of every other
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

### When the writer decides what you left out

Every writer fills a gap in a task with something. The models differ only in
whether they tell you. A task that says "add validation to the endpoint" without
saying what counts as valid, what the failure response is, and whether existing
callers may break gets an answer to all three, and the answer arrives as working
code with no note attached.

That is why the size rules above are not the whole standard. A small task can be
underspecified and a large one can be complete. What decides whether a task is
ready to dispatch is whether a writer could execute it without deciding anything
the specification already decided:

- Exact paths, named. Not "the validation module".
- The behavior, including what happens on the failure path, stated rather than
  implied by the happy path.
- The edge cases this task owns, and the ones it deliberately does not, so the
  writer neither invents them nor assumes another task covers them.
- The check that proves it done, precise enough to run.

Read each task back asking what a writer would have to guess. Whatever it is,
write it down or make it a blocker. A guess that turns out right still cost the
review that had to verify it; a guess that turns out wrong costs a remediation
round and arrives disguised as working code.

This matters most where implementation is routed to a Worker chosen for
throughput or cost rather than for judgement — see the opencode note in
`project.md`'s Model mapping. It is worth doing regardless: none of the writers
here benefit from being made to guess.

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

Dispatch a different Worker than the one that wrote the plan. Hybrid: Terra at
`high` via Codex, read-only sandbox, per
`${CLAUDE_PLUGIN_ROOT}/internal/codex.md`. Claude-only: the `my-plan-reviewer`
agent, Sonnet at `high`, read-only. Either way the reviewer is a different model
as well as a different session, because Sol wrote the plan in one backend and
Opus in the other.

Terra at `high` is not the stronger reviewer; it is enough for most plan reviews
at a fraction of the cost, which is why it goes first. Escalating it cannot mean
Sol, which wrote the plan: when Terra reports a blocker it cannot resolve, or the
plan touches security, concurrency, payments, infrastructure, or a data
migration, the review crosses to `my-plan-reviewer-deep` on Opus.

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
