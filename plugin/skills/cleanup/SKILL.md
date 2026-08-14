---
name: cleanup
description: Sweep the whole repository, or a path, for dead code, unused dependencies, build residue, and drift between meta-docs and reality — using the stack's own tooling where one exists. Report-only unless --fix is given, and even then never for a structural finding. Manual only — runs solely on the user's explicit invocation, never from inferred intent.
argument-hint: "[path] [--fix] [--simplify <path>] [--rename <old> <new>] [--extract <file>:<lines>]"
disable-model-invocation: true
---

# My Plan: Cleanup

Sweeps the repository for residue that accumulates over time rather than
arriving in any one diff: files and exports nothing calls anymore,
dependencies nothing imports (or declares that it should), documentation
and configuration that drifted from what the repository actually does,
and structure that no longer matches
`../../knowledge/checklists/architecture.md`. Didn't write any of it, and
doesn't reorganize anything itself — `--fix` removes what's safe to
remove, one item at a time; a structural finding is a handoff to `plan`,
never a patch this skill applies.

`review --repo` already carries a delete/reuse/stdlib/native/yagni/shrink
taxonomy under its `complexity` lens, but that lens only fires on code
someone is already looking at for other reasons — a diff, a file an audit
happened to open. `cleanup` starts from the opposite direction: the
stack's own dead-code and dependency tooling, which surfaces candidates
nobody was looking at, narrowed by a grep-verification pass `review`'s
lens has no room for. It also owns two categories `review.md` doesn't
check at all — meta-doc drift and structural mismatches at whole-repository
scope, independent of any diff. The two are complementary: `cleanup` finds
what nobody was looking at; `review --repo` judges what's already in front
of someone. A third skill, `security`, asks a related but different
question about the same dependency list — not whether it's still used,
but whether it's vulnerable; a dependency that's both unused and
vulnerable is this skill's removal, not `security`'s upgrade.

Arguments: $ARGUMENTS

Codex CLI, Antigravity, and Gemini CLI do not substitute `$ARGUMENTS`. In
those hosts, take the text the user typed after this skill's invocation
(`$my-plan:cleanup` in Codex CLI; `/cleanup` or the skill's name in
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

No argument means the whole repository; a path narrows the sweep to that
subtree. Unlike `review`, there is no diff-shaped default — an
argument-less invocation is never `git diff HEAD`, because what's
accumulated over time isn't shaped by what's currently staged. `--simplify`,
`--rename`, and `--extract` are a different kind of work entirely (active,
behavior-preserving transformation of code someone names, not evidence-based
removal of what nobody's using) — each runs only when given explicitly,
never as part of a default sweep; see `../../knowledge/checklists/cleanup-refactor.md`.

## Independence

**Claude Code.** Dispatch the find phase to the `my-plan-reviewer` agent
(`../../agents/my-plan-reviewer.md`) via the Task tool — read-only by its
own tool list, so it can name every candidate without being tempted to
remove one as it goes. Give it: the scope, `docs/map.md` if it exists (so
it can tell a framework entry point from an orphan before it runs
anything), and which of `../../knowledge/checklists/cleanup-code.md`,
`cleanup-residue.md`, `cleanup-docs.md`, or `cleanup-refactor.md` apply to
this invocation. Its
existing boundary already permits running a project's commands in check
mode; the same boundary covers running a dead-code/dependency tool in its
default analysis mode, since none of them write anything without an
explicit fix flag — tell it explicitly, in the dispatch, never to pass
one.

**Codex CLI / Antigravity.** No subagent primitive exists in these hosts.
If your own context shows you already touched the code you're about to
scan, say that plainly at the top of the report instead of presenting it
as independent — or hand the sweep to another host, which restores real
independence instead of just declaring its absence.

## Declared blindness

This skill's honesty gap isn't "no brief was supplied" — there's nothing
to check conformance against here. It's tool coverage and repository
context.

If a stack's primary tool from `../../knowledge/checklists/cleanup-code.md`
isn't installed and can't be fetched, print one line per affected stack:
`Tool coverage: not evaluated for <stack> — no dead-code/dependency tool
available; findings in that stack are manual-grep reasoning only, capped
at medium confidence.` Still sweep that stack — just say plainly what
backs each finding in it.

If `docs/map.md` doesn't exist, print: `Entry-point context: not
evaluated — docs/map.md not found; framework/routing/plugin-registry
exclusions applied from generic heuristics only, not confirmed against
this repository's own conventions.` Still run the sweep — the absence of
a map lowers the confidence ceiling, it doesn't cancel the pass.

## What you do

1. **Read `../../knowledge/checklists/cleanup.md` first** — the golden
   rules, the safety net, confidence/severity, and the never-without-
   approval list apply to everything below.
2. Confirm the safety net: a clean-enough working tree and a green
   build/test baseline (discovered the way `review` discovers it —
   `docs/map.md`, then CI config, then package scripts) before anything
   that could remove or change a file. No green baseline means
   report-only, whatever else was asked.
3. Read `docs/map.md` if it exists, for module boundaries and entry
   points, before judging anything as dead.
4. For a default sweep: read `cleanup-code.md`, `cleanup-residue.md`, and
   `cleanup-docs.md`, and work each category — detect the stack(s)
   actually present, run the tool if available, grep-verify every
   candidate, classify confidence, note severity.
5. For a whole-repository sweep (the argument-less default), also read
   `../../knowledge/checklists/architecture.md` and report structural
   mismatches — report only, per `cleanup.md`.
6. For `--simplify`/`--rename`/`--extract`, read `cleanup-refactor.md`
   instead of the default-sweep files, and follow its procedure for that
   one operation only. A refactor flag pre-empts the rest of the
   invocation: no default sweep runs alongside it, and `--fix` given with
   it adds nothing — the flag itself is the opt-in.
7. Report, in the shape below.

## `--fix`

Only when given explicitly, after the find-phase report exists — never
combined into one pass. What it may touch, by category, is fixed in
`../../knowledge/checklists/cleanup.md` and not renegotiated per
invocation: dead code / unused dependencies / build residue / orphan
files, yes, one item at a time with revert-on-failure; meta-doc drift,
yes, text-only; structural mismatches, never.

**Claude Code.** The dispatched reviewer can't apply anything itself — it
holds no write tool, by design. Apply the fixes yourself, in this
session, from the findings list its report returned; never ask it to.

**Codex CLI / Antigravity.** You are both finder and fixer here; say so
in the report.

## Output

A report in the shape of `../../knowledge/templates/report.md`: Scope,
Repository understanding (whole-repository sweeps only), Findings, Not
worth doing, Verdict, carried over unchanged. "Lens
coverage" becomes **Category coverage** — one row per category in scope
(`dead-code`, `unused-deps`, `residue`, `doc-drift`, `structure`), each
`passed` / `found N` / `not-applicable` with a reason. Each finding row
carries confidence alongside severity:

```
<path>:<line>  <severity>  <confidence>  <category>  <what's wrong>. <the minimal correction>.
```

Finding nothing is a valid result, and better than manufacturing findings
to look thorough.

## Closing note

```
Changed: <files fixed, if --fix, else "none — read-only">
Validated: <build/test command re-run per fix, if --fix, else "not this skill's job">
Open risks: <count of unfixed high-confidence findings, or "none">
Suggested next skill: plan, for any structural finding — or review, then
  commit, for anything --fix touched
```
