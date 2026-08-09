# Stage: Planning

Turn the approved specification into an executable plan — one overview document
plus one file per task — and have an independent Worker review it before any
code is written.

Entered only after `approvedSpecHash` matches the current specification.

This stage creates no worktree and no branch. The planner reads the user's live
checkout and writes nothing into it; the only repository write in this whole
command is the task files, and they arrive only after the plan has passed its
independent review. Everything else lands in the Run's artifacts directory.
`$my-plan:exec` is what later creates the isolated worktree, per
`implementation.md`.

## Writing the plan

The plan has two parts, both written by the Coordinator from the planner's
returned content:

- `plan.md`, rendered from
  `<pluginRoot>/internal/templates/documents/plan.md.tpl` into
  `<stateRoot>/runs/<run-id>/artifacts/`. The overview: approach, task index,
  write set, test impact, risks, execution order. Its frontmatter binds
  `specHash` — the approval this plan implements — and `plannedBase`, the local
  default-branch SHA the repository was read at, together with the two facts no
  later fetch can repair: whether HEAD sat somewhere else, and any dirty path
  intersecting the write set. Planning never fetches; a fetch writes to the
  primary checkout's refs, and nothing here may touch the primary checkout.
- One file per task, rendered from
  `<pluginRoot>/internal/templates/documents/task.md.tpl` into
  `<stateRoot>/runs/<run-id>/artifacts/tasks/` for review. They reach the
  repository only when the plan closes clean, below, so the user never sees a
  task board that independent review is still rewriting.

A plan is a depth problem, so it goes to Sol at `high` per
`<pluginRoot>/internal/codex.md`.

`high` is the working default, because a plan is rarely improved by spending
twice as long on it. A plan that changes architecture, moves data, spans several
systems, or makes a decision nobody can walk back is the exception, and it
escalates to Sol at `xhigh`.

The planner is read-only, because there is nothing for it to write into: no
worktree exists, and the primary checkout is not its to touch. Dispatch it with
`--sandbox read-only`, `-C` at the primary checkout, the prompt rendered from
`<pluginRoot>/internal/prompts/plan-write.tpl`, and `--output-schema` pointed at
`<pluginRoot>/internal/contracts/plan-result.schema.json`.

Build a handoff with `role: "planner"`, `mode: "plan-write"`, an empty
`writeSet`, and artifact entries naming absolute paths: the approved
specification and discovery record in Run artifacts, this Run's Architecture
Memory, the project skill when one exists, and the plan and task templates in
the plugin. This is exactly how discovery already reads: a read-only Worker at
the primary checkout reads the absolute paths its handoff lists; only
workspace-write Workers are confined to their workspace. Never send a path to a
file that is not there, and never omit one that is.

**Greenfield Mode.** The planner's workspace is the empty target directory; the
specification, discovery record, and research carry all the evidence, and the
Architecture Memory and project skill do not exist yet. Send what exists.
`plannedBase` renders as the literal `none`: there is no repository to read a
base from, and execution's revalidation, not a diff, is the drift check.

Verify the result before writing anything: `taskCount` equals the number of task
entries, `planContent` ends with the exact line `END OF PLAN`, and no `{{`
placeholder survives anywhere in the returned content. A result failing any of
these is a truncated or failed attempt against the same candidate, never a
plan. Then write `plan.md` and the task files from the returned content, byte
for byte, and compute `planHash` from what you wrote. The Worker never writes;
the files are yours.

Record each normative fact once. Reference the specification, Architecture
Memory, project skill, research record, and contracts by path. Do not copy their
contents into the plan; a plan that duplicates the specification will drift from
it.

Rules:

- No implementation code in the plan or in a task file. Pseudocode that is
  really code is code.
- One phase of work, unless a genuine sequencing dependency requires more.
  Phases invented for tidiness slow the Run and prove nothing.
- The write set equals the approved specification's write set exactly. A path
  the tasks need but approval does not cover is a scope change: revise the
  specification, take an ordinary approval, renew `approvedSpecHash`. The plan
  never widens its own authority.
- That set never includes the Run's own paperwork. The working documents live in
  Run state, the task files are never staged, and the one Run document that
  ships — the changelog, when the change is user-visible — is already in the
  approved specification's write set. Reviewers check the diff against this set
  with no carve-outs.
- Reuse before adding. Name the existing helper, pattern, or installed
  dependency the task should use. A new abstraction needs a reason the existing
  code cannot serve.
- The structure is the smallest one that still holds the rules, the security,
  and the testability the specification asks for.
  `<pluginRoot>/internal/checklists/architecture.md` is the standard, and the
  plan answers its five questions in writing for every layer, interface,
  factory, or pattern it introduces. The plan reviewer checks exactly that, so
  an unanswered question is a round that could have been avoided here.
- Non-trivial new behavior gets a check. Auth, deletion, persistence, payment,
  cost, and external contract paths require a behavioral or integration check.
- A refactor task touching code with no existing coverage declares a
  characterization check as its first step: pin the current behavior exactly as
  it is, without judging whether it is correct, then refactor under that net.
  Otherwise the task adds no new behavior, so no check is required, and a silent
  regression ships through every gate untouched.

## Overlap with other Runs

Once the write set is fixed, compare it against the write sets of every other
unfinished Run for this repository in state.

Report any overlapping path as integration risk. Do not block on it: the Runs
can both proceed safely, and the risk is at integration, where the person who
should know about it early is the user, not a lock.

Note in the same place any shared external resource the work needs that cannot
be namespaced per Run: a fixed database, a fixed port, an emulator, a deployment
target. Those cannot be isolated by a worktree and are handled with a lease
during implementation.

Execution repeats this comparison at its own entry, because by then this
snapshot may be weeks old.

## Tasks are sized for the writer, not for the reader

The models that write code hold a limited working context and degrade over a
long session. A task that is obvious to a planner reading the whole
specification can be impossible for a writer that only receives that task.

So the unit of work is not "a feature". It is the smallest change that:

- Touches a handful of files, not a subsystem.
- Carries one idea. If describing it needs the word "and" twice, it is two tasks.
- Can be verified on its own by a check the task itself names.
- Leaves the tree buildable.
- Needs no knowledge its task file does not carry. Assume the writer has never
  seen this repository and will not see the other tasks.
- Carries its references: the helpers to reuse, patterns to match, contracts to
  satisfy, and tests that pin behavior, as paths in the task file, so execution
  starts from the file and never from a search of the codebase. A task may
  leave no decision open; what the specification did not decide and the
  repository cannot is a blocker, not a choice for the writer.

A large goal becomes many small tasks. Never one task that says "build the
feature": that is the single most reliable way to get plausible code that does
not work. Write the sequence out, however long it gets. A plan with twenty
precise tasks beats a plan with three ambitious ones.

Never separate a contract from its implementation and its wiring: that task is
not buildable on its own and its check proves nothing. Cohesion decides where
the line falls; size decides how many lines there are.

Genuinely trivial work stays one task. Splitting a two-line change into ceremony
wastes a Run.

There is one more reader now: the user. Task files sit in the repository between
planning and execution precisely so the user can read them, reorder their
expectations, and edit them. A task file a writer could execute without guessing
is also one its owner can veto without archaeology.

## Order and parallelism

Declare real dependencies per task, and only real ones.

- **Sequential** when a task needs the output, the types, or the conventions
  another task establishes. Foundations first: a contract before its consumers,
  a migration before the code that reads it.
- **Parallel** when tasks touch disjoint paths and neither needs the other's
  result. Independent writers can run at once, one per path. Never two writers
  on the same file.

A task that only "feels" like it should come later is not a dependency. False
sequencing turns a parallel plan into a slow one for no safety gained.

## Plan review

Dispatch Terra at `high` in a new read-only session per
`<pluginRoot>/internal/codex.md`, `-C` at the primary checkout. The reviewer is
a different model and a different session because Sol wrote the plan.

Terra at `high` is enough for most plan reviews and keeps the model boundary
intact. When Terra reports a blocker it cannot resolve, or the plan touches
security, concurrency, payments, infrastructure, or a data migration, rotate to
a fresh Terra review session at `xhigh`. Never use Sol, which wrote the plan.

Build a handoff matching `<pluginRoot>/internal/contracts/handoff.schema.json`
with `role: "reviewer"`, `mode: "plan-check"`, and artifact entries naming
absolute paths for the specification, the plan, every task file in the artifacts
task directory, the Architecture Memory, and the project skill. Pass the handoff
path. Never paste the documents into the prompt.

Validate the returned result against
`<pluginRoot>/internal/contracts/review-result.schema.json` before trusting it.
Check that `subjectHash` matches what you sent: the plan hash, in the pinned
form `project.md` defines — `plan.md` and every task file together. Invalid or
unparseable output is a failed attempt, never an implicit approval.

### Remediation

Fix valid findings. Record justified pushback with its reasoning; a finding you
disagree with stays visible, it does not silently disappear.

Every rewrite of the plan or a task file changes the subject: recompute the plan
hash before the next round, so no review ever runs against a hash its subject
has already left behind.

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

## When the plan closes

Zero open blockers ends this stage, and the close is mechanical:

1. Write the task files into `<tasksDir>` in the primary checkout — `docs/tasks/`
   unless the Project Profile overrides it — byte for byte from the reviewed
   artifacts copies. This is the only write this command makes to the user's
   repository. A file already there that this product does not own is left
   untouched and reported; a task never overwrites a foreign file. In
   Greenfield Mode the target directory has no repository yet; the task files
   are simply files, recorded the same way.
2. Compute the plan hash over `plan.md` and every task file, in the pinned form
   `project.md` defines, and record it as `planHash` — now, after the last
   review round, never from an earlier draft. Record each task file's path and
   own hash in `taskFiles`.

   Ownership is the manifest: a file is this Run's only if `taskFiles` lists
   it, and everything else — another Run's task files included — is foreign,
   left untouched, and reported. When a filename is already taken, this Run's
   files take a `<run-short>-` prefix instead; `taskFiles` records the paths
   exactly as written, and execution reads paths from the manifest, never from
   a glob. In Workspace Mode the board lives at the workspace root's task
   directory — one board for the whole Run, whichever repositories it
   touches.
3. Update `run.json`: set `phase` to `planned`, `currentTaskId` null, status
   `active`. `baseSha`, `branch`, and `worktree` stay null; nothing exists yet
   for them to name.
4. Show the user the task board — the count, one line per task, the dependency
   and parallel shape — and name the command that runs it: `$my-plan:exec`. Do
   not ask whether to continue. The user runs execution when they decide to,
   and they may edit any task file first; execution verifies the hashes and
   re-reviews whatever changed.

A Run parked at `planned` is this command's finished state, not an interrupted
one. It holds no worktree and no branch; the task files and the Run artifacts
are everything it owns.
