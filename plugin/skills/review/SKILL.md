---
name: review
description: Review a diff, a branch, a path, or the whole repository (--repo) against the eleven-lens checklist. Evidence-backed findings only — never style or taste. Read-only unless --fix is given. Manual only.
argument-hint: "[diff | branch | path | --repo] [--spec docs/brief.md] [--fix]"
disable-model-invocation: true
---

# My Plan: Review

Reviews changed code, or — with `--repo` and no diff to follow — the whole
repository, against the eleven lenses in
`../../knowledge/checklists/review.md`. Didn't write what it's reviewing,
and doesn't fix it unless `--fix` was given explicitly.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:review` in the user's message
instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

No argument means the working diff: `git diff HEAD` — not bare `git diff`,
which silently omits anything already staged — plus untracked files meant
for this change (`git status --porcelain` lists them; no diff shows a new
file until it's staged). A path or `--repo` narrows or widens the scope
explicitly. A branch name means its own commits, not everything the
default branch has done since the fork: `git diff <default>...<branch>`,
the three-dot merge-base form, not two dots.

## Independence

**Claude Code.** Dispatch the actual review to the `my-plan-reviewer`
agent (defined at `../../agents/my-plan-reviewer.md`) via the Task tool —
a fresh subagent with no `Write`/`Edit`/`NotebookEdit` that hasn't watched
this code get written. Give it the scope, the paths to
`docs/brief.md`/`docs/plan.md` if named or found, and `docs/map.md` if it
exists.

**Codex CLI.** No subagent primitive exists here. If your own context shows
you wrote or substantially shaped what you're about to review, say that
plainly at the top of the report instead of presenting it as independent —
or better, hand the review to the other host (Codex reviewing what Claude
wrote, or the reverse), which restores real independence instead of just
declaring its absence.

## Declared blindness

If `--spec <path>` was given, or `docs/brief.md`/`docs/plan.md` exist, read
them and check the `conformance` lens against them: does the diff stay
inside the write set, does it avoid adding behavior nobody asked for. If
none exist and none were named, don't silently skip `conformance` and
scope-drift checking — print one line: `Conformance: not evaluated — no
brief or plan supplied or found. Scope drift was not checked.` and review
the other ten lenses as normal.

## What to review

Read `../../knowledge/checklists/review.md` — every lens applies unless the
changed surface genuinely doesn't touch it (a backend-only diff has no
accessibility findings; mark it `not-applicable` with the reason, never
skip the row). Depth per stack and per concern lives in
`../../knowledge/references/`, mapped by its `README.md` — load at most
two: the repository's stack, and the concern actually in front of you.
They're depth, never authority — where a guide is stricter than the
checklist, the checklist decides.

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
accessibility, or explicit product behavior — deleting a guard isn't a
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
brief was supplied — violates it. Everything else is `major` or `minor`.
Inflating severity to force attention is a failed review, the same as
missing a real one.

## `--fix`

Only when given explicitly. Fix findings one at a time: pick the highest
severity, fix it, re-verify just that fix, move to the next. Don't batch
fixes — a batch that breaks something hides which fix broke it. Never fix
something not in the findings list under cover of "while I was in there."

**Claude Code.** The dispatched reviewer can't apply anything itself — it
holds no write tool, by design. Apply the fixes yourself, in this session,
from the findings list its report returned; never ask the reviewer to.

**Codex CLI.** You are both reviewer and fixer here; say so in the report.

## Output

A report in the shape of `../../knowledge/templates/report.md`: findings
table, lens coverage, verdict. Finding nothing is a valid result, and
better than manufacturing findings to look thorough.

## Closing note

```
Changed: <files fixed, if --fix, else "none — read-only">
Validated: not this skill's job
Open risks: <blocker count, or "none">
Suggested next skill: fix blockers (implement on each, or --fix) and
  re-run review — or validate, then commit, if there are none
```
