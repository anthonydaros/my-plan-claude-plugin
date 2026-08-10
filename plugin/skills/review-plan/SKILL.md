---
name: review-plan
description: Adversarially review a plan and its tasks for missing acceptance coverage, impossible steps, unsafe scope, weak sequencing, weak tests, and overengineering — before any code exists. Run in a fresh session, not the one that wrote the plan. Manual only.
argument-hint: "[path to plan, default docs/plan.md]"
disable-model-invocation: true
---

# My Plan: Review Plan

Reviews `docs/plan.md` and its task files before anything gets built. This
is a separate skill from `plan` on purpose: the one guarantee worth
protecting here is that the plan's reviewer isn't the plan's author. If you
just ran `/my-plan:plan` in this same conversation: in Claude Code the
dispatch below still yields a genuinely fresh reviewer — but say in the
report that this session authored the plan, since it framed the dispatch.
In Codex, which has no subagent, open a fresh session first or hand the
review to Claude. Say so if you can't, rather than presenting the review
as independent when it wasn't.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:review-plan` in the user's message
instead. Empty means `docs/plan.md`.

## Independence

**Claude Code.** Dispatch the actual review to the `my-plan-reviewer` agent
(defined at `../../agents/my-plan-reviewer.md`) via the Task tool — a
fresh subagent with no `Write`/`Edit`/`NotebookEdit`, that hasn't watched
this plan get written. Give it, in the dispatch prompt: that the scope is
a plan review, not a code review, owning only the `conformance`,
`correctness`, `tests`, and `complexity` lenses; the path to the plan
under review (the argument, default `docs/plan.md`); every task file that
plan lists (default: every file under `docs/tasks/`); the brief the
plan's Planned against section names, else `docs/brief.md`, if it exists;
and `docs/map.md` if it exists. Relay its report as it returned —
findings, severities, and counts unedited.

**Codex CLI.** No subagent primitive exists here. If your own context shows
you wrote or substantially shaped this plan, say that plainly at the top of
your report — the value of this skill is a second, independent look, and a
report that quietly isn't one is worse than no report.

## What to check

Read `../../knowledge/checklists/architecture.md` — it's the standard the
plan should have been written against.

1. **Conformance.** Does the plan deliver every requirement and acceptance
   criterion in `docs/brief.md`, if one exists? Name any requirement with
   no task behind it. A plan that quietly narrows, widens, or reinterprets
   the brief is blocked; if there's no brief, judge conformance against
   whatever the plan itself states as its goal, and open the report's
   Scope with one line: `Conformance: judged against the plan's own
   stated goal — no brief found.`
2. **Executability.** Does every task name real paths that exist, or state
   clearly that it creates them? A task file that leaves a decision open —
   a missing failure path, an edge case neither owned nor excluded, a check
   that can't run as written, a References section that omits a file the
   Details plainly depend on — is a finding on that task, because the
   writer receives that file and nothing else.
3. **Write set.** Does the declared write set cover every path the tasks
   actually touch, and nothing more — and does it stay inside the brief's
   expected write set, where a brief exists? A user-visible change with no
   changelog path in the write set is a finding, when the repository keeps
   a changelog.
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
the four lenses a plan review owns from `../../knowledge/checklists/review.md`:
`conformance`, `correctness`, `tests`, `complexity`. Mark the other seven
`not-applicable` — no code exists yet.

## Closing note

```
Changed: none — read-only
Validated: not this skill's job
Open risks: <blocker count, or "none">
Suggested next skill: fix findings then re-run review-plan, or implement
  if there are zero blockers
```
