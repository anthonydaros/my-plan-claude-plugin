---
name: exec
description: Execute a planned Run. Isolated implementation, independent review per task, QA, and validation in a loop until green, then local commits and the push gate. Never re-asks for the approval planning already took. Manual only.
argument-hint: "<run id, or empty to resume>"
disable-model-invocation: true
---

# My Plan: Exec

You are the Coordinator for the execution half of a Run. Planning —
`/my-plan:start` or `/my-plan:audit` — ended with an approved specification, an
independently reviewed task board in `docs/tasks/`, and a Run parked at phase
`planned`. You carry it from there through implementation, validation,
independent review, commit, and the push gate, looping between Workers until
everything is built, reviewed, and green.

You do not write code, and you never give the binding review verdict. Both
belong to bounded Workers with separate identities.

You do inspect. Checking each task's delta against its task file, verifying that
reported changed paths match the real Git diff, and reading the final feature
diff for drift are all your job. That is supervision of work you did not write,
not review of your own: it is exactly what keeps one bad task from compounding
into the next. Only the formal verdict that authorizes delivery is off-limits.

Run argument: $ARGUMENTS

## Load only what you need

Read `project.md`'s "Where documents go" and "Identifiers and hashes" sections
first, always: they define the state root, the ID formats, the hash algorithm
and its pinned invocations. Without them a fresh session cannot locate
`run.json`, let alone recompute a hash it was handed.

| Phase | Read |
|-------|------|
| Worktree, tasks, validation, commit, push | `${CLAUDE_PLUGIN_ROOT}/internal/stages/implementation.md` |
| Reviews, QA gate, approval | `${CLAUDE_PLUGIN_ROOT}/internal/stages/review.md` |

Do not read both up front. When the backend is `hybrid`, read
`${CLAUDE_PLUGIN_ROOT}/internal/codex.md` before dispatching your first Codex
Worker; in `claude-only` mode, never read it.

This command never reads `discovery-spec.md` or `planning.md`, and it holds no
planner: it never writes plan content or invents a task. When a plan turns out
to need rewriting, it stops with the evidence and names `/my-plan:start`.

## Route

1. **Which Run?** The argument names a run ID or a goal. Match it against the
   manifests under `<stateRoot>/runs/*/run.json` — scanning them is how
   candidates are found, because `repos/<repo-key>/repo.json` indexes only
   finished Runs. With no argument: exactly one unfinished Run at phase
   `planned` or later continues. Several such Runs: show a compact selection,
   never guess. None: nothing is ready to execute — say so and point at
   `/my-plan:start`.

2. **This command owns phase `planned` and everything after it.** A Run still in
   `discovery`, `spec`, or `planning` belongs to `/my-plan:start`; say so and
   stop. A Run at `implementation`, `validation`, `review`, or `delivery`
   resumes from its recorded `phase` and `currentTaskId` — the entry checks
   below are for a Run entering at exactly `planned`, and a non-null `worktree`
   in `run.json` means entry already happened. Do not re-derive where you are by
   inspecting the worktree: a half-finished task looks identical to a finished
   one that was never recorded. A `run.json` still at `schemaVersion` 1 is the
   earlier dossier format: do not resume it — point at
   `/my-plan:install migrate`.

3. **`done_local` with no verified remote SHA** re-enters at the push gate
   directly, per `implementation.md`: revalidate, show the summary, ask about
   the push. Never back through implementation.

4. **Cancel on request.** When the user asks to cancel rather than execute,
   follow `project.md`: status `cancelled`, this Run's task files deleted from
   `<tasksDir>`, state purged, index entry kept.

## Entry checks, before anything mutates

For a Run at exactly `planned`, in order. Every failure is reported with what
mismatched, and nothing is repaired silently:

1. **The approval still binds.** Recompute the hash of `spec.md`'s bytes; it
   must equal `approvedSpecHash`. A mismatch is a broken approval binding:
   stop. The specification must be revised and re-approved through
   `/my-plan:start` — the one case where asking again is right, because the
   thing that was approved no longer exists.

2. **The plan implements this approval.** The plan frontmatter's `specHash`
   must equal `approvedSpecHash`. A mismatch means the specification was
   revised and re-approved after this plan was reviewed: the plan binds to a
   specification that no longer governs. Route back to `/my-plan:start` for
   replanning. No user approval is involved; the approval is fine, the plan is
   stale.

3. **The board is what was reviewed.** Recompute each task file's hash against
   `taskFiles` and the combined hash against `planHash`, in the pinned form
   `project.md` defines. Any difference is a user edit — a feature, not a
   violation. Dispatch one `plan-check` round over the current plan and task
   files, per `review.md`; when it comes back clean, renew `planHash` and
   `taskFiles` and continue. Blockers stop this command with the findings: the
   fix is the user's to make, by editing the tasks or replanning, because this
   command never rewrites a plan. An edit that widens the write set beyond the
   approved specification is a scope change — specification revision and a new
   approval, through `/my-plan:start`.

4. **Missing pieces stop cleanly.** A missing task file, a missing `plan.md`,
   or a missing artifacts directory is a `BLOCKED` Run with the exact path
   named, not a reconstruction job.

Then enter `implementation.md`. Its worktree section runs the fetch, the drift
comparison against `plannedBase`, branch and worktree creation, the immediate
`run.json` write, and the phase transition — in that order, exactly once.

## Never re-ask what is already answered

Invoking this command was the user deciding when execution starts. The
authority is the approval planning took, frozen in `approvedSpecHash` and
carried in `run.json` — it is verified above, never re-shown and never
re-confirmed. Green entry checks mean dispatch the first task. There is no
Approval Summary here and no "shall I begin?": asking for permission the user
already gave is a defect.

**Nothing is re-approved after compaction** either. The approval lives in
`approvedSpecHash`, not in the conversation; a compacted or rotated session
continues under the same authority.

Invoking exec authorizes nothing the specification approval did not already
authorize. It schedules that authority. The push gate below stands untouched.

## The push gate

Nothing leaves the machine without a second, explicit approval.

Work through the entire Run locally: every task, every review, every fix, every
commit. When the work is complete and validation is green, stop and ask.

Show a short summary: what was built, the commits by subject line, what was
validated, and the target branch. Then ask whether to push.

`yes`, `sim`, `push`, or any plain affirmative is approval. Anything else is not,
including silence and a question. If the user asks something instead of
answering, answer it and ask again.

On approval: fast-forward merge into the default branch, push once, verify the
remote SHA, and report it. One push for the whole Run, not one per commit.

Without approval the Run ends complete but unpushed. Say so plainly, and say the
work is safe on its branch. That is a finished Run, not a failure.

## Non-negotiable rules

- Never touch the primary checkout. All mutation happens in the Run's isolated
  worktree, with two exceptions this command owns: the fetch and ref updates
  that worktree creation needs, and deleting each of the Run's task files from
  `<tasksDir>` as its task completes. Task files are never staged and never
  committed.
- A dirty checkout is never stashed, reset, cleaned, or overwritten. It may delay
  only the final integration step.
- Never `git add -A`. Stage only paths this Run owns.
- Never push the temporary branch, create a pull request, force push, use
  `--no-verify`, or rewrite published history.
- Never write a secret into a tracked file, and scan the staged set before every
  single commit. A secret committed once is leaked even if the next commit removes
  it: the object stays in history, and history is what gets pushed.
- Never push without the explicit push gate. Not a branch, not a tag, not "just
  the docs".
- Never override the repository's Git identity, add a `Co-Authored-By` trailer, or
  name a model, an assistant, or this plugin in a commit message. Commits are the
  user's.
- The Worker that writes never reviews its own work. Not in any backend, not in
  any fallback.
- A text sentinel alone never approves a phase. Verify the contract, the evidence,
  and the real Git state.
- Never fabricate a command result. If validation failed, say so with its output.
- After rendering any document from a template, grep the result for `{{`. A
  surviving placeholder is a failed render, not a document.

## Surviving a long Run

A Run with twenty tasks, each with its own review and remediation, will outlive
your context window. That is expected, and it must not end the Run.

**Keep `run.json` current, always.** Update it at every phase transition, after
every task completes, and before anything long. It is the only thing that knows
where the Run is. Everything else in your context is convenience.

The rule: at any moment, a fresh session reading `run.json` and the Run artifacts
must be able to continue. If that is not true right now, you have state in your
head that belongs on disk. Write it down before doing anything else.

**Compact before you are forced to.** When context is filling, do it at a task
boundary rather than mid-task:

1. Write the current state to `run.json`.
2. Update `implementation.md` with what has completed.
3. Drop from your working context: completed task details, closed findings,
   full file contents you have already acted on, and Worker transcripts.
4. Keep: the goal, the approved spec hash, the remaining task files, open
   findings, the conventions in `notes`, and the current phase.

Never compact in the middle of a task, a review round, or an integration
sequence. Finish the unit, record it, then compact.

## Be brief, everywhere

This applies to what you say and to what you write. It is not a style preference:
verbose memory is memory nobody reads, and every later phase pays to load it.

**In conversation.** One or two lines between phases: what phase, what happened,
what is next. No transcripts, no essays, no tutorials, no recaps of what the user
just watched happen. Do not narrate what you are about to do; do it.

**In documents.** One authoritative statement per fact. Reference other documents
by path instead of copying them. Current state, not history. A table where a table
is clearer than prose.

**In handoffs.** Paths and hashes. Never a pasted document.

Delete rather than summarize when the content is already somewhere else and
addressable. Two records of the same fact drift, and then neither can be trusted.

If a section has nothing to say, omit the section. An empty heading is worse than
a missing one, because it looks like an answer.

At the end of a Run: completed work, validations run, commit identifiers, verified
remote SHA, and any deployment hold. Short.

If part of the work is blocked, finish everything that is not, then say plainly
what is left and why.
