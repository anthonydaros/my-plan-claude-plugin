---
name: review
description: Review a diff, a branch, a path, or the whole repository (--repo) against the eleven-lens checklist, and independently execute the repository's real validation commands — never trusts a claimed result. Every finding says whether it's executed or read. Read-only unless --fix is given. Manual only — runs solely on the user's explicit invocation, never from inferred intent.
argument-hint: "[diff | branch | path | --repo] [--spec docs/brief.md] [--fix]"
disable-model-invocation: true
---

# My Plan: Review

Reviews changed code, or — with `--repo` and no diff to follow — the whole
repository, against the eleven lenses in
`../../knowledge/checklists/review.md`, and independently runs the
repository's real validation commands itself — because "the tests pass,"
reported by whoever just wrote the code, is a claim, not a check. Didn't
write what it's reviewing, and doesn't fix anything unless `--fix` was
given explicitly.

Arguments: $ARGUMENTS

Codex CLI, Antigravity, and Gemini CLI do not substitute `$ARGUMENTS`. In
those hosts, take the text the user typed after this skill's invocation
(`$my-plan:review` in Codex CLI; `/review` or the skill's name in
Antigravity and Gemini CLI) as your argument string.

Manual-only is enforced by frontmatter in Claude Code and by this skill's
sidecar in Codex CLI. Antigravity and Gemini CLI have no equivalent switch
and may hand this file to the model unasked — if this skill loaded without
the user explicitly invoking it, by slash command or by name, stop: say
which skill loaded and that it runs only on explicit invocation, and do
nothing else.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — the host told you that file's
location when it loaded this skill; use it. Under a symlink install
(`gemini skills link`), pass such paths to the filesystem as written or
resolve the symlink first (`realpath`) — never simplify the `../../` away
lexically, which points outside the plugin.

No argument means the working diff: `git diff HEAD` — not bare `git diff`,
which silently omits anything already staged — plus untracked files meant
for this change (`git status --porcelain` lists them; no diff shows a new
file until it's staged). A path or `--repo` narrows or widens the scope
explicitly. A branch name means its own commits, not everything the
default branch has done since the fork: `git diff <default>...<branch>`,
the three-dot merge-base form, not two dots.

**The scope argument narrows the reading pass only.** The execution pass
below always runs the repository's full resolved set of validation
commands, regardless of scope — a one-file diff can break a test the diff
never touches, and narrowing execution to "just what the diff touches"
would silently reopen the gap this skill exists to close. `--repo` is the
one scope where reading and execution already coincide by nature.

## Independence

**Claude Code.** Dispatch both passes to the `my-plan-reviewer` agent
(defined at `../../agents/my-plan-reviewer.md`) via the Task tool, in one
dispatch — a fresh subagent with no `Write`/`Edit`/`NotebookEdit` that
hasn't watched this code get written or its tests run. Give it: the scope,
the resolved validation commands (or where to resolve them — see Declared
blindness), the paths to `docs/brief.md`/`docs/plan.md` if named or
found, and `docs/map.md` if it exists.

**Codex CLI / Antigravity.** No subagent primitive exists in these hosts.
If your own context shows you wrote or substantially shaped what you're
about to review, say that plainly at the top of the report instead of
presenting either pass as independent — or better, hand the review to
another host (Codex or Antigravity reviewing what Claude wrote, or the
reverse), which restores real independence instead of just declaring its
absence.

## Declared blindness

Two separate gaps, both worth stating plainly rather than silently
skipping:

**Command discovery.** Resolve the validation commands before dispatching,
in this order: `docs/map.md`'s Validation section, then the repository's
CI configuration, then its package scripts. If none of these settle it,
ask rather than guess — running the wrong command and reporting green is
worse than asking. A subagent can't ask the user mid-dispatch, so this
resolution happens in this session, before the Task call.

**Conformance.** Locate the brief before dispatching — `--spec <path>` if
given, else `docs/brief.md`/`docs/plan.md` if they exist — and name what
you found, or didn't, in the dispatch prompt. The actual `conformance`
judgment (does the diff stay inside the write set, does it avoid adding
behavior nobody asked for) and the acceptance-criteria check both belong
to phase 1 below, inside the dispatch — performing either one here, in
this session, before the Task call, is exactly the pre-execution reading
impression this skill exists to avoid. If nothing was found or named, the
dispatched phase doesn't silently skip either check — it prints one line:
`Conformance: not evaluated — no brief or plan supplied or found. Scope
drift and acceptance criteria were not checked.` and reviews the other
ten lenses as normal.

## What this checks

Two passes, in this order, every invocation — never trust a reading
impression over a real result, and never let one substitute for the
other.

**1. Execution, first, in isolation.** Run every resolved validation
command, one at a time, and record its real exit code. A command not run
doesn't appear in the report. A failing command doesn't become a pass
because the rest of the suite is green.

If a claimed result exists (a closing note from `implement`, a comment, a
prior report), compare what actually ran against it. A disagreement is the
finding, whichever way it points: a command claimed green that fails here
is a `blocker`. A claimed result that can't be reproduced running the same
command is a `blocker` — an unreproducible green is not a green.

Check that every acceptance criterion in the brief is actually exercised —
find the command or test that would fail if it were violated. A criterion
nothing exercises is a `conformance` finding at `major`, or `blocker` when
it covers auth, deletion, persistence, payment, cost, or an external
contract. "The suite passes" is not evidence a specific criterion is met.

**Flakiness is a finding, not a retry.** If a command fails and then
passes on a second identical run, don't report the pass alone. Report both
runs and open a `tests` finding: a check that decides differently on
identical input can't prove anything about this change, and whatever runs
after this is about to trust it anyway.

**Leave the tree the way you found it.** Record `git status --porcelain`
before the first command. Build output, caches, and coverage files a
command leaves behind are expected, not a finding — unless a command wrote
somewhere surprising. But never run a command in a mode that rewrites
tracked files: no snapshot-update flag, no `--fix`, no formatter in write
mode, no codegen that edits sources. This is about the *validation
command's* own write-mode, never about `--fix` below, which is this
skill's own, separate, explicitly-requested act. If the repository's own
script rewrites files by design, or the after-run `git status --porcelain`
differs from the before-run on any tracked file, report the exact paths.

**2. Reading, second, all eleven lenses.** Read
`../../knowledge/checklists/review.md` — every lens applies unless the
changed surface genuinely doesn't touch it (a backend-only diff has no
accessibility findings; mark it `not-applicable` with the reason, never
skip the row). Depth per stack and per concern lives in
`../../knowledge/references/`, mapped by its `README.md` — load at most
two: the repository's stack, and the concern actually in front of you.
They're depth, never authority — where a guide is stricter than the
checklist, the checklist decides.

Where a reading-based judgment touches code the execution pass already has
a real result for — a `tests`, `correctness`, or `conformance` finding —
**cite that result, never rederive or contradict it silently.** "This
reads like it should pass" against a command that failed twice is itself
worth surfacing as its own finding, not quietly resolved in the reading
impression's favor.

**`--repo` mode** (what an earlier version of this plugin called `audit`):
no diff to follow, so two more checklists earn their keep.
`../../knowledge/checklists/architecture.md` turns a "this feels
over-built" impression into a finding naming the simpler structure.
`../../knowledge/checklists/implementation.md` is the catalogue of defects
that survive code that already ships — N+1, a missing transaction,
authorization checked per session instead of per resource, an error
swallowed into `null`. Read `docs/map.md` first if it exists, so you
understand the architecture before judging it — a review that judges
before it understands produces noise.

The complexity lens stops at the first answer: does this code need to
exist at all; does the repository already have a helper, type, or pattern
for it; does the standard library or platform do it; does an
already-installed dependency do it. Name the concrete smaller replacement.
This lens never removes required validation, error handling, security,
accessibility, or explicit product behavior. Deleting a guard isn't a
simplification.

## Not priorities — do not report these

Style and taste. Formatting, naming preference, "I would have written it
differently." Theoretical edge cases the system can't actually receive.
Hypotheticals — "what if someone later..." isn't a defect in this diff.
Documentation drift a supplied brief already authorized. Work a supplied
brief's non-goals deliberately excluded. The minimum check — one small
behavioral test is the floor, never ask for it to be removed or grown into
a suite nobody requested.

## Severity

A `blocker` is wrong, unsafe, loses data, breaks a contract, or — when a
brief was supplied — violates it, whether the evidence behind it is
executed or read. Everything else is `major` or `minor`. Inflating
severity to force attention is a failed review, the same as missing a
real one.

## `--fix`

Only when given explicitly. Fix findings one at a time: pick the highest
severity, fix it, re-verify just that fix, move to the next. Don't batch
fixes — a batch that breaks something hides which fix broke it. Never fix
something not in the findings list under cover of "while I was in there."

**Re-verifying an execution-backed finding means re-running the exact
command that produced it and citing its new real exit code — never
re-reading the change and asserting it should pass now.** That's not
optional: a "fix" whose only proof is a second reading is exactly the
unverified claim this skill exists to catch, relocated one step later in
the same invocation.

Three things stay forbidden, `--fix` or not: passing a validation command
its own write/fix mode to make a finding disappear (a snapshot-update
flag, a formatter in write mode); "fixing" a failing test by loosening,
skipping, or deleting the assertion — or by reshaping its setup,
fixtures, mocks, or input data so the assertion passes vacuously, which
has the same effect by a different route — instead of correcting the
defect it exposed; and editing the command's own definition (its config,
a test-runner script entry, a coverage threshold, what it discovers or
excludes), since that changes what the re-run actually proves, not just
whether it passes. A fix corrects what the command found wrong, never the
command's ability to find it or what it checks.

The re-run that verifies an execution-backed fix is not independent — the
same session that just wrote the fix is the one running it. Mark it as
such in the report; a fix genuinely worth trusting without that caveat
gets a fresh `/my-plan:review` run afterward, the same as any other
change.

**Claude Code.** The dispatched reviewer can't apply anything itself — it
holds no write tool, by design. Apply the fixes yourself, in this session,
from the findings list its report returned; never ask the reviewer to.

**Codex CLI / Antigravity.** You are both reviewer and fixer here; say so
in the report.

## Output

A report in the shape of `../../knowledge/templates/report.md`, with two
additions. Every finding row names how it was established:

```
<path>:<line>  <severity>  <executed|read>  <lens>  <what is wrong>. <the minimal correction>.
```

Each finding row gets exactly one of `executed` or `read`, never both —
the combined `executed + read` form belongs only to the lens-coverage
table below, which summarizes a whole lens, not one finding.

For an `executed` finding, `<path>:<line>` becomes `` `<command>` (exit
N) `` — the command in backticks, its real exit code in parentheses, not
a source location — a finding whose evidence is a summary of output
nobody kept isn't reportable. "There were no tests to run" is a
`blocker`, not a reason to mark `tests` not-applicable.

Lens coverage carries every one of the eleven lenses, genuinely evaluated
— never a blanket "not-applicable" for lenses this invocation didn't
happen to touch by design, the way a narrower skill once could. Add an
`Evidence` column: `executed + read` for `tests`/`correctness`/
`conformance`, `read` for the other eight, `not-applicable` with a reason
where the changed surface genuinely doesn't touch a lens, or `not
evaluated` for `conformance` specifically when Declared blindness found
no brief or plan to check against.

Finding nothing is a valid result, and better than manufacturing findings
to look thorough.

## Closing note

```
Changed: <files fixed under --fix, plus any unexpected tracked-file drift
  a validation command caused — git status --porcelain before vs after>
Validated: <every command run, with its real exit code>
Tree: <git status --porcelain at completion — so commit can tell whether
  it's committing the tree that was actually validated>
Open risks: <blocker count, or "none">
Suggested next skill: commit, if everything's green — or fix blockers
  (implement on each, or --fix) and re-run review
```
