---
name: plan
description: Turn a goal into a decision-complete brief through a bounded, batched interview, then a task board sized for whoever builds each task, then an independent review before treating the plan as approved. Writes docs/brief.md, docs/plan.md, and docs/tasks/*.md. Manual only.
argument-hint: "<goal> | [path to brief] | [path to plan, to re-review]"
disable-model-invocation: true
---

# My Plan: Plan

Turns a goal into `docs/brief.md`, then a task board — `docs/plan.md` plus
one file per task under `docs/tasks/` — then dispatches an independent
review of that plan before treating it as approved. This replaces three
earlier skills (`spec`, `plan`, `review-plan`) as one invocation. The
guarantee that used to come from running them as three separate
commands — an interview producing a brief, a planner turning it into
tasks, a reviewer who isn't the planner checking it — still holds in
Claude Code, where the review phase is a genuinely fresh dispatch; in
Codex CLI it degrades further than it used to, since the same session now
usually runs all three phases — see Independence below for exactly what
that means and how to restore a real check when it matters.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:plan` in the user's message instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

## Resolving the argument

The argument is one of four things, resolved before anything else runs:

1. **A path to a file shaped like a plan** (the conventional
   `docs/plan.md`, or content matching `../../knowledge/templates/plan.md`'s
   shape — a `## Tasks` table, a `## Planned against` section):
   **review-only.** Skip straight to Independence below, against that
   plan and its task files — nothing gets interviewed or (re)written.
2. **A path to a file shaped like a brief** (the conventional
   `docs/brief.md`, or content matching `../../knowledge/templates/brief.md`'s
   shape): declared blindness — treat it as decided, skip the interview,
   continue at Declared blindness below.
3. **No argument, and `docs/brief.md` exists**: same as case 2, found
   implicitly.
4. **Anything else** — prose, a path that doesn't exist yet, or no
   argument with no `docs/brief.md`: a new goal. Run the interview below,
   write `docs/brief.md`, then continue into planning and review.

If `docs/tasks/` already holds files and this invocation is about to write
new ones (cases 2–4 — case 1 is the only one that writes nothing), stop
and ask before writing: they're either an unfinished earlier plan
(`commit` deletes each task file once its work is actually committed) or
orphans from an abandoned one — never leave two plans' tasks mixed in one
directory, an empty directory is the only "finished" signal the system
keeps. Offer review-only mode as one of the answers: "these are the
current plan's tasks — just re-review `docs/plan.md`, or are they
orphans?"

## Before asking anything

Only on the goal path (case 4). Read `docs/map.md` if it exists — stack,
boundaries, conventions, pitfalls, already verified. If it doesn't exist,
say so plainly and do a lighter version yourself: read the code the goal
touches, canonical docs, tests, and relevant history. Every question you
ask that the repository could have answered spends the user's attention
on work you should have done first. Suggest `/my-plan:map` in the closing
note when its absence cost you real digging.

**Research, when the repository can't settle it.** Specialized business
terminology, market behavior, regulation, standards, current facts, an
external integration, or a greenfield idea with nothing local to check
against — any of these means the web is the evidence and the code isn't.
Search generically and never send repository code, secrets, personal data,
customer identifiers, or confidential business details to a search
provider. Regulated or high-stakes claims need a primary or official
source where one exists; note where you couldn't find one.

Both the repository read and this research run again before every
round below, not only the first — a newly-exposed frontier question gets
the same treatment a first-round one does.

## The interview

Build the decision tree before asking anything: every open decision that
actually changes something — product behavior, user experience, business
policy, scope, acceptance criteria, consequential risk, credentials, an
external side effect, or a real preference between similarly valid
options — and that the repository, an obviously-safer reversible default,
or declared blindness doesn't already settle. A reversible technical
detail with one clearly safer answer never becomes a node — resolve it
silently and log it as a row in the brief's Decisions table. If nothing
survives this filter, say so plainly and write the brief straight from
what's already settled — zero questions is a valid, complete round, not a
failure to find any.

**The frontier** is every node whose prerequisites are already settled —
by the repository, by research, or by an earlier round's answer. A
question whose honest answer depends on another still-open question
belongs to the next round, not this one. The interview ends when a
recomputed frontier comes back empty, or the budget below is spent —
whichever happens first; either one means proceed to writing the brief,
not wait for further input.

**Ask the whole frontier in one numbered round.** Numbering is global
across rounds — round 2 continues at Q4, it doesn't reset to Q1 — so the
budget below stays trackable. Each question: a precise title, 2-4 concrete
options with honest tradeoffs, and one clearly marked recommendation.
Arrive with a recommendation, not an open request to think for the user —
"it depends" is not an answer to hand back.

Wait for every answer in the round before recomputing the frontier. An
answer can resolve its own question, eliminate an option on a sibling
question, or expose a genuinely new node — any of those reshapes the tree
for the next round.

**Budget: stay under roughly ten questions total, summed across every
round.** Past that you're interrogating, not specifying — write what's
left as flagged assumptions, each with your recommended answer, and let
the user reopen the ones that matter. When a single round's own frontier
already exceeds what's left of the budget, ask the highest-stakes
questions in that round up to the budget and flag the rest as assumptions
immediately — never blow through the budget to fit one round in whole.

**Sharpen the language as you go.** When the user's term conflicts with
what the repository already calls it, say so and ask which governs. When a
word is vague or overloaded, propose a precise term and confirm it. When
the user describes behavior the code contradicts, surface the
contradiction directly — don't quietly pick a side. Record each resolved
term in the brief with the synonyms it displaces, so the same collision
doesn't reopen later.

## Write `docs/brief.md`

Render it from `../../knowledge/templates/brief.md`. Every requirement
testable, every acceptance criterion checkable by someone who wasn't in the
room. The expected write set is the product paths the goal actually
touches — name a directory or glob where the exact files aren't knowable
yet; the planning phase below narrows it, never widens it — plus the
repository's changelog when it keeps one and the change will be visible to
a user of the software.

If `docs/brief.md` already exists and this is a new goal, ask before
overwriting it — a stale brief nobody reads is better than a real one
silently lost. If it's the same goal revised, say what changed and why.

**Pause here.** Print the decisions made without asking (the
Decisions-table rows that never became questions) and every flagged
assumption, and wait for the user to confirm or redirect before
continuing into planning — this pause is what approving the brief now
looks like, the same conversational mechanism every interview round above
already used, not a separate command to run.

## Declared blindness

Cases 2 and 3 above land here directly, brief already in hand: read it and
treat it as decided — this doesn't reopen its decisions. Read `docs/map.md`
if it exists for boundaries and conventions; note if it doesn't.

## Write set

The plan's write set stays within the brief's expected write set — exact
files, each inside a path, directory, or glob the brief named. A path the
tasks need that falls outside it is a scope change: stop and ask, and on a
yes revise `docs/brief.md` with a note on what changed and why before the
plan includes it.

## Structure, before sizing tasks

Work the shape of the solution against `../../knowledge/checklists/architecture.md`
before writing tasks. Every layer, interface, factory, or pattern the plan
introduces answers that file's five questions in the plan's Approach
section. The review phase below checks exactly this, so an unanswered
question here is a round it will bounce back.

Reuse an existing helper, pattern, or installed dependency before adding an
abstraction, and name the existing thing in the task that should use it.

## Sizing tasks

The unit of work is not "a feature." It's the smallest change that:

- Touches a handful of files, not a subsystem.
- Carries one idea — if describing it needs "and" twice, it's two tasks.
- Can be verified on its own, by a check the task itself names.
- Leaves the tree buildable.
- Needs no knowledge its task file doesn't carry. Assume the writer has
  never seen this repository and won't see the other tasks.

A large goal becomes many small tasks, never one task that says "build the
feature" — that's the most reliable way to get plausible code that doesn't
work. Never separate a contract from its implementation and wiring: that
task isn't buildable alone and its check proves nothing.

Read each task back asking what a writer would have to guess. Whatever it
is, write it down or flag it as a blocker in the plan's Risks section —
don't let a task leave a decision open. Exact paths, not "the validation
module." The failure path, stated, not implied by the happy path. The edge
cases this task owns, and the ones it deliberately doesn't. The check that
proves it done, precise enough to run as written. The reference paths —
helpers to reuse, patterns to match, tests that pin behavior — so building
starts from the file, not a search of the repository.

Non-trivial new behavior gets a check. Auth, deletion, persistence,
payment, cost, and external contract paths require a behavioral or
integration check, without exception. A refactor over previously uncovered
code gets a characterization check as its first task: pin current behavior
before changing it.

Name task files `docs/tasks/NN-slug.md` — a zero-padded position in
dependency order, so a bare listing reads in build order — and use that
filename as the task's identifier everywhere: the plan's Tasks table and
each task's `Depends on:` line.

## Ordering and parallelism

Sequential only when a task genuinely needs another's output, types, or
conventions — foundations first. Parallel when tasks touch disjoint paths
and neither needs the other's result. A task that only "feels" like it
should come later isn't a real dependency; false sequencing makes the plan
slower for no safety gained.

Parallel means "no ordering constraint," not "two sessions in one
checkout at once" — concurrent `implement` runs share a working tree, so
their diffs mingle until commit. Use separate worktrees, or run them one
at a time.

Fill the plan's Planned against section from the live tree: the commit
you planned from (`git rev-parse HEAD`), any dirty path (`git status
--porcelain`) that intersects the write set, and the path of the brief
you planned from — `implement` and this skill's own review phase resolve
against these.

## Independence

**Claude Code.** Dispatch the review to the `my-plan-reviewer` agent
(`../../agents/my-plan-reviewer.md`) via the Task tool — a fresh subagent
with no `Write`/`Edit`/`NotebookEdit`, that hasn't watched this plan get
written. Give it, in the dispatch prompt: that the scope is a plan
review, not a code review, owning only the `conformance`, `correctness`,
`tests`, and `complexity` lenses; the path to the plan under review; every
task file it lists; the brief the plan's Planned against section names,
else `docs/brief.md` if it exists — if neither names one, dispatch
without a brief path and let the reviewer's own declared-blindness
fallback handle it, never a path that doesn't exist; and `docs/map.md` if
it exists. Relay its report as it returned — findings, severities, and
counts unedited. If this same session ran the interview and planning
phases above, the dispatch is still genuinely independent — but say so at
the top of the report anyway: this session authored the plan and framed
the dispatch, even though the subagent judging it didn't.

**Codex CLI.** No subagent primitive exists here. If your own context
shows you wrote or substantially shaped this plan — which, because the
interview, the planning, and this review now run in one invocation, is
the default outcome here, not an edge case — say that plainly at the top
of the report instead of presenting the review as independent. Suggest a
fresh Codex session, or handing the review to Claude Code, whenever
independence actually matters for this change.

## What the review checks

Read `../../knowledge/checklists/architecture.md` — it's the standard the
plan should have been written against.

1. **Conformance.** Does the plan deliver every requirement and acceptance
   criterion in `docs/brief.md`, if one exists? Name any requirement with
   no task behind it. A plan that quietly narrows, widens, or
   reinterprets the brief is blocked; if there's no brief, judge
   conformance against whatever the plan itself states as its goal, and
   open the report's Scope with one line: `Conformance: judged against
   the plan's own stated goal — no brief found.`
2. **Executability.** Does every task name real paths that exist, or state
   clearly that it creates them? A task file that leaves a decision open —
   a missing failure path, an edge case neither owned nor excluded, a check
   that can't run as written, a References section that omits a file the
   Details plainly depend on — is a finding on that task, because the
   writer receives that file and nothing else.
3. **Write set.** Does the declared write set cover every path the tasks
   actually touch, and nothing more — and does it stay inside the brief's
   expected write set? A user-visible change with no changelog path in the
   write set is a finding, when the repository keeps a changelog.
4. **Sequencing.** Do the dependencies reflect real ordering constraints?
   Phases invented for tidiness, where nothing actually depends on the
   previous one, are a finding.
5. **Repository fit.** Does the plan reuse existing helpers, patterns, and
   installed dependencies, or add abstractions the repository already has
   an answer for? Name the existing thing it should use instead. A layer,
   interface, factory, or pattern introduced without answering
   `architecture.md`'s five questions is a finding — name the simpler
   structure.
6. **Tests.** Does non-trivial new behavior get an observable-behavior
   check? Auth, deletion, persistence, payment, cost, and external contract
   paths require one. Don't demand tests for trivial code.
7. **Risk.** What breaks if this plan runs exactly as written? Regression
   surface, data loss, an irreversible external effect, security exposure.

## Not priorities — do not report these

Style and structure preferences. Theoretical risk requiring conditions this
product doesn't have. Decisions the brief already settled — a plan
following it is doing its job, not diverging from something better. Work
the brief deliberately excluded. Implementation detail a plan correctly
left out — a plan is not code.

## Severity

A `blocker` means the plan cannot be built as written, or contradicts the
brief it claims to deliver. Everything else is `major`, `minor`, or `note`
and doesn't by itself stop building — say so, and let whoever's driving
decide.

## Output

A report in the shape of `../../knowledge/templates/report.md`, scoped to
the four lenses this review owns from `../../knowledge/checklists/review.md`:
`conformance`, `correctness`, `tests`, `complexity`. Mark the other seven
`not-applicable` — no code exists yet.

## On a blocker

Stop and report — never replan or re-dispatch automatically. A blocker
often reflects a product or scope question, not a mechanical error;
auto-replanning risks silently reinterpreting a decision the interview
phase deliberately put in front of the user. Fix the findings — by hand,
or by re-running this skill against the brief to replan — then re-run
this skill against the plan (case 1, review-only) to get a genuinely
fresh review, especially in Codex CLI, where looping again from an
already self-declared non-independent review only compounds it.

## Closing note

```
Changed: <docs/brief.md written/updated, docs/plan.md and N files under
  docs/tasks/ written, or "none — read-only" for a review-only invocation>
Validated: not this skill's job
Open risks: <flagged assumptions the brief carries, plus the review's
  blocker count, or "none">
Suggested next skill: fix the findings (by hand, or by re-running this
  skill to replan) and re-run against the plan to re-review — or
  implement, if there are zero blockers
```
