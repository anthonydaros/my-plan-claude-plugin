---
name: implement
description: Build one task from docs/tasks/, or a plain request when there's no task board, with the implementation defect catalogue loaded and a declared write set — then chain the rest of that task's arc in the same invocation, an independent review, a fix loop until it comes back green, and the secret-scanned commit that closes the task out. --solo stops after the build. Manual only — runs solely on the user's explicit invocation, never from inferred intent.
argument-hint: "<task file path, or a plain request> [--solo]"
disable-model-invocation: true
---

# My Plan: Implement

Builds one task, completely — then, in the same invocation, carries it the
rest of the way: an independent review, a fix loop that runs until the
review comes back green, and the commit. One task in, one commit out,
nothing to shepherd in between. The build phase still never judges its own
work: the chained review is a fresh dispatch in Claude Code and an honest
self-declaration in Codex CLI and Antigravity, exactly as `review` itself
defines — see Independence below.

Arguments: $ARGUMENTS

Codex CLI, Antigravity, and Gemini CLI do not substitute `$ARGUMENTS`. In
those hosts, take the text the user typed after this skill's invocation
(`$my-plan:implement` in Codex CLI; `/implement` or the skill's name in
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
lexically, which points outside the plugin. The same rule covers the
`../review/SKILL.md` and `../commit/SKILL.md` references below: sibling
skills, one directory up.

`--solo` stops the invocation after the build phase — the chain section
below is skipped and the closing note prints its `--solo` lines — for
when you want the review in a genuinely separate session, or the tree is
mid-experiment and not ready to become history.

## Declared blindness

If the argument names a file under `docs/tasks/`, read only that file — not
`docs/plan.md`, not the other task files. That's deliberate: the task file
is supposed to carry everything you need, and reading the rest costs you
context you need for the work that's actually yours. If the task file is
genuinely missing something, that's worth saying plainly rather than going
and reading around it.

If the argument is a plain request instead — no task board exists, or this
change doesn't warrant one — say so, and hold yourself to the same
standard: name the exact paths you're about to touch and the check that
proves it done, before you start, the same way a task file would.

Read `docs/map.md` if it exists, for boundaries and conventions. Read
`../../knowledge/checklists/implementation.md`, but only the parts your
task's surface actually touches — a task that adds a string constant has no
transaction story.

## Boundaries

- Modify only the paths the task (or your own stated scope, if there's no
  task) names. A path you need that's outside it is a blocker to report,
  not a reason to widen scope quietly.
- Implement only the task in front of you. Don't start the next one, don't
  finish what an earlier task left undone, don't improve code you happen to
  read along the way — work nobody assigned is work nobody reviewed.
- Don't reopen a decision the brief or plan already settled. Ambiguity you
  can't resolve from what you were given is a blocker, not something to
  decide silently.
- Never `git add -A`, and never stage or commit anything during the build
  or the fix loop. History gets written only by the chain's commit phase,
  and only through `../commit/SKILL.md`'s own steps — never inline.
- Never write a secret into any file this change will hand to the commit
  phase — a brand-new file isn't tracked yet, and "untracked right now" is
  exactly how a secret reaches the staged set later.

## How to work

1. Record `git status --porcelain` before touching anything — your
   closing note's Changed list is the delta against this, not everything
   already dirty. Then read the current state of the files you're about
   to touch — someone may have changed the tree since the task was
   written. If those paths already carry an earlier, uncommitted attempt
   at this same task, say so and fold that delta into this invocation's
   scope — the chained review must see the task's whole uncommitted
   change, and baselining over the earlier attempt would hide it.
2. Follow the repository's existing conventions, helpers, and installed
   dependencies. Reuse before you add; a new abstraction or dependency
   needs a reason the existing code can't serve.
3. Write the smallest change that satisfies the task. No speculative
   configuration, no interface with one implementation, no scaffolding for
   work nobody asked for.
4. Add the smallest meaningful automated test when the new behavior is
   non-trivial. Auth, deletion, persistence, payment, cost, and external
   contract paths require a behavioral check; trivial code doesn't.
5. If you're fixing a reported defect rather than building new behavior,
   prove the test before you prove the fix: write the check, run it, watch
   it **fail** against the current code, then fix it and watch it pass. A
   test written after the fix, that never failed, proves the code does
   what the code does — nothing more.
6. Run whatever validation the task names (or the commands in
   `docs/map.md`) as a gate before you call this done. Leave the tree
   buildable. This is a sanity check, not the real validation — that's
   the chained review's job, dispatched next.

## Before you call it done

`../../knowledge/checklists/implementation.md` covers what compiling and
passing tests doesn't: N+1 queries, a missing transaction, a read-check-write
race, authorization checked per session instead of per resource, an error
swallowed into `null`, a migration that can't deploy separately, a call to
an API that doesn't exist in the installed version. Those come back as
review findings if skipped, and every one is cheaper to avoid than to loop
on.

No mock, hardcoded value, `TODO`, or silent fallback left as the answer. No
dead code or second implementation kept alongside the first. No `any`,
cast, or disabled lint rule added to quiet the compiler.

If you were given a task file under `docs/tasks/`, leave it in place after
the build — deleting it is the commit phase's job, once the work is
actually verified in history. Its absence is the only progress tracking
that exists, and "implemented but never committed" isn't done.

## The chain

The build is done and sane. Everything from here runs without asking —
that's the point — but nothing here is new behavior: each phase follows
the sibling skill's own body to the letter, so there is exactly one
authoritative statement of how a review or a commit works, and it isn't
this file. Under `--solo`, skip this whole section and print the closing
note.

**1. Review.** Follow `../review/SKILL.md` as written — its command
resolution, its Independence section, its execution-then-reading order,
its severity discipline — bound to this task: the reading scope is the
paths changed since your step-1 baseline; the conformance target is the
task file (or the scope you declared upfront, when there is none); the
claimed result to verify is your own step-6 sanity check.

**2. The gate, and the loop.** Commit only on a review round that comes
back with no `blocker` findings — and commit that round's tree exactly
as it was reviewed: a blocker-free round is never followed by more
edits, so what lands in history is what the green round actually saw.
Its `major` and `minor` findings go to the closing note as open risks,
never into a quiet post-review fix.

A round with blockers sends you back to the build: fix them in this
session under `review`'s own `--fix` discipline — one at a time, an
execution-backed finding re-verified only by re-running the exact command
that produced it — then dispatch a fresh, full review round, handing it
the previous round's report and your fix claims as the claimed results to
check. While a round is red you may also fix its `major`s whose
correction lies inside the task's write set — the fresh round re-reviews
everything anyway. A `blocker` whose correction lies outside the task's
write set is not yours to fix: stop the chain red right there and report
it — work outside the write set is work nobody assigned, chain or no
chain, and Boundaries already calls such a path a blocker to report. A
`major` outside the write set is an open risk in the closing note; a
`minor` is reported, never chased.

Three review rounds is the bound. Still red on the third: stop, print the
report and the closing note, and don't commit — a loop that hasn't
converged by then isn't converging, the findings are telling you
something is wrong with the task rather than the code, and that's the
user's call, not the chain's.

A repository with no validation commands at all meets this logic on
round one: `review` calls "there were no tests to run" a `blocker`, and
standing up a validation story is almost never inside one task's write
set — so expect the chain to stop red immediately and hand you the
decision, exactly as designed. `--solo` plus a manual `commit` is the
honest path in such a repository until it has something to run.

**3. Commit.** Follow `../commit/SKILL.md` as written, as if invoked as
`commit --tasks <the task file> --changelog` — or, when there is no task
file, with the explicit list of changed paths plus `--changelog`. Its
steps already cover everything the chain needs: the secret scan before
staging, exact-path staging, the fresh-committer dispatch, post-commit
verification against the repository, the changelog entry drafted without
asking (that's what `--changelog` authorizes — commit's own step 2), and
deleting the task file once its work is verified in history. The push
command it prints stays the user's to run, same as always — a stopped
chain, a refused commit, or a secret-scan hit is reported exactly as
`commit` itself reports it, never routed around.

The chain covers exactly the one task it was invoked on, and it
never starts the next task — the closing note names it, the user decides.

## Independence

**Claude Code.** The chained phases dispatch the same fresh subagents the
standalone skills define: `review`'s two passes go to `my-plan-reviewer`,
which holds no file-editing tool and did not watch this session build the
change — that dispatch boundary is what keeps the chained review a real
review. The fixes between rounds happen here, in this session, from the
findings the reviewer returned — never by the reviewer. The commit goes
to `my-plan-committer`, per `../commit/SKILL.md`'s own dispatch step.

**Codex CLI / Antigravity.** No subagent primitive exists in these hosts,
so every phase of the chain runs in this one context — the session that
built the change is the one reviewing and committing it. Say that plainly
at the top of each review report and in the commit's closing note,
exactly as `review` and `commit` each instruct for these hosts. Chaining
doesn't change the declaration; it makes it the default outcome for this
skill, the same way it already is for `plan`.

## Closing note

One note for the whole invocation, printed at the end whatever path it
took:

```
Changed: <paths actually touched — build plus loop fixes, verified against
  git status --porcelain compared with the step-1 baseline — and the
  commit SHA(s) with one-line subjects; or "built, not committed" plus
  the reason, when --solo was given, the chain stopped red, or the
  commit phase refused (a refusal is the scan or the verification
  working — report it exactly as commit itself does)>
Validated: <each review round: every command run and its real exit code —
  and how many rounds it took. Under --solo: the step-6 sanity checks
  and their results, marked as no substitute for a real review>
Open risks: <majors and minors accepted into the commit, the blockers
  that stopped a red chain, or "none">
Suggested next skill: implement <next remaining file under docs/tasks/>,
  or none when the board is empty or absent — either way the chain
  never starts it; the board and the push are yours. Under --solo:
  review, then commit --tasks <this task file>. On a chain that stopped
  red: fix what stopped it and re-run implement on this task — a re-run
  folds the earlier uncommitted attempt into its scope — or go manual
  with review --fix and commit --tasks.
```
