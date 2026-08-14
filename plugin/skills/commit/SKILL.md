---
name: commit
description: Stage exactly the intended paths, scan for leaked secrets in code and prose, commit in the repository's own style, and draft a changelog entry when the repository already keeps one and the change is user-visible (--changelog authorizes the draft without the confirm ask). Never pushes, never forces, never --no-verify, never touches history. Prints the push command for you to run yourself. Manual only — runs solely on the user's explicit invocation, never from inferred intent.
argument-hint: "[path ... | --spec docs/brief.md | --tasks docs/tasks/<file>] [--changelog]"
disable-model-invocation: true
---

# My Plan: Commit

Turns an already-reviewed, already-working change into local Git history.
Doesn't write code, doesn't fix findings, and never leaves the machine —
there is no push skill. The push is a separate command you run yourself,
after reading what this printed.

Arguments: $ARGUMENTS

Codex CLI, Antigravity, and Gemini CLI do not substitute `$ARGUMENTS`. In
those hosts, take the text the user typed after this skill's invocation
(`$my-plan:commit` in Codex CLI; `/commit` or the skill's name in
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

Arguments are one of: a list of paths to commit, `--spec <path>` naming a
brief whose write set bounds what may be staged, or `--tasks <path>` naming
a task file whose paths bound it the same way. Empty means "commit what's
dirty," and that requires confirming the staged set explicitly with the
user before dispatching — never infer intent from an empty argument
silently.

`--changelog` may accompany any of those forms: it authorizes step 2 to
draft the changelog entry without the ask — the deliberate decision that
ask exists to obtain, given on the command line up front instead.
`implement`'s chain passes it so a chained commit never stalls on a
prompt. It changes nothing else about step 2: the file must already
exist, its own shape decides the entry's format, and a change with
nothing user-visible still gets no entry.

## Declared blindness

If `--spec` or `--tasks` was given, read it and treat its write set as the
expected staged set — anything staged outside it is a finding, not a silent
inclusion. If neither was given, check `docs/brief.md` and `docs/tasks/`
for something to bound against; if nothing's there either, print one line —
`not evaluated: no --spec/--tasks given or found; staging exactly the paths
named on the command line` — and proceed on the explicit path list alone.
A changelog path already named in that write set is staged like any other
path; one that isn't is where step 2 below asks before adding it.

## What you do

1. **Read the staged and dirty state first, and record three baselines
   you'll need after committing.** `git status -s` and
   `git diff --cached --name-only` to build the exact path set this commit
   may contain from the arguments, or the confirmed dirty set — never from
   `git add -A` or `git add .`. If anything is already staged that isn't
   in that set, stop and report it before staging more: `git commit`
   commits the whole index, so a leftover staged path would ride along
   unscanned, and nothing after this step can cleanly take it back. Also
   record `git rev-parse --verify HEAD` (or `none` in a repository with no
   commits yet) and `git for-each-ref refs/remotes refs/tags` right now,
   before anything else touches the repository — there is no other point
   at which "before" is still true, and both are the only way to verify
   several commits at once or detect a rewrite of existing history.

2. **Draft a changelog entry, if the repository already keeps one.** Check,
   in order, for `CHANGELOG.md`, `CHANGES.md`, or `HISTORY.md` at the
   repository root, then the same three under `docs/`. Stop at the first
   match. None found: move on, silently — nothing else in this run's
   trust depends on that absence, so announcing it on every ordinary
   commit would be exactly the noise a section with nothing to say should
   stay omitted, not printed.

   A file exists: read its existing entries and match their shape exactly
   — a `## [Unreleased]` header with `### Added`/`### Changed`/`### Fixed`,
   a flat dated list, whatever it already does. Never introduce a section
   format the file doesn't already use, and never create the file if it
   doesn't exist — see Hard boundaries.

   **Two-tier trigger.** Only an explicitly given `--spec` or `--tasks`
   authorizes drafting automatically — a write set that names the
   changelog path was a deliberate decision the user already approved
   when they pointed this run at it. A `docs/brief.md`/`docs/tasks/`
   found *implicitly* (the Declared blindness fallback, no `--spec`/
   `--tasks` given) never authorizes on its own: it could be stale,
   left over from finished work with nothing to do with this commit.
   Draft the entry, show it, and ask once instead — whether the write set
   came implicitly or names no changelog path at all. A "no" commits the
   code exactly as already planned, unchanged.

   An explicit `--changelog` on the command line stands in for that ask
   entirely: draft and include the entry without asking, even when the
   write set names no changelog path. It authorizes only skipping the
   ask — an absent changelog file is still skipped, not created, and a
   change with nothing user-visible still gets no entry.

   **Source and filter.** With an explicit `--spec`: draft from its
   Requirements and Acceptance criteria — what a user of the software
   observes differently, not which files moved; use the Decisions table
   only when a decision changed user-facing behavior the acceptance
   criteria don't already capture. Otherwise: draft from `git diff` over
   the paths in the declared set (working-tree content, available now —
   nothing is staged yet at this point, and no commit message exists
   until step 6). Either way, skip anything with no user-observable
   effect — a refactor, internal reorganization, tests, CI/tooling, docs,
   a dependency bump nobody can see. Finding nothing user-visible in an
   otherwise legitimate change is a valid, sayable outcome, never a
   reason to pad an entry. One factual sentence per entry: no emoji, no
   category header the file doesn't already use, no adjective standing in
   for a fact.

   Several atomic commits in this run get **one entry, synthesized once**
   for the whole run's user-visible content — never one per commit — and
   it lands in the single commit, or the last of several atomic commits,
   so it describes the unit of work as a whole, not a slice of it. Once
   drafted (automatically or confirmed), write it into the changelog file
   now and add its path to the declared path set from step 1 — it's prose
   about to be staged, and the next step exists specifically to scan
   prose, not only code. Staging itself still doesn't happen until step
   4, same as every other path.

3. **Run the secret scan yourself, before staging anything**, over the
   actual current content of every candidate path — not "the diff": a
   brand-new untracked file has no diff to read (`git diff` alone will
   miss it entirely), so read the file's real content directly, the same
   way for a new file as for a modified one. Read
   `../../knowledge/checklists/secrets-patterns.md` for the exact filenames
   to refuse outright and the exact content patterns to grep for — the
   same list `security`'s secrets category uses, so the two never drift
   apart. A hit that's a real value, not a variable name or placeholder,
   stops that path.
   - Read prose you're about to stage, not only code — a credential quoted
     into a markdown doc while investigating something is a leak the code
     scan above won't catch.
   - Personal paths, internal hostnames, and customer identifiers get the
     same treatment. They aren't credentials, but they aren't yours to
     publish either.
   - A trip here doesn't mean quietly dropping the path and committing the
     rest. Tell the user what was found, where, and stop before staging
     it — refusing is the scan working, not a failure to route around.

4. **Stage exactly the named paths, explicitly** — one by one or as an
   explicit list. Never `git add -A`, never `git add .`, never a wildcard.

5. **Dispatch the commit — don't write it inline.**

   **Claude Code.** Dispatch the actual commit to the `my-plan-committer`
   agent (defined at `../../agents/my-plan-committer.md`) via the Task
   tool. Don't commit
   inline yourself — you've watched however much of this session produced
   the change, which is exactly what makes you a poor judge of whether a
   staged path belongs; a fresh subagent that only sees the staged diff
   and the declared path set catches what familiarity hides. Give it, in
   the dispatch prompt: the exact path set from step 4 (including a
   drafted changelog entry, if step 2 added one), the repository root,
   which commit that changelog entry belongs in, and the commit-grouping
   intent (one commit for a small cohesive change, several atomic commits
   when independent changes make better history). Its withheld
   `Write`/`Edit`/`NotebookEdit` tools are a real boundary against
   *editing tracked files*, but `Bash` can still touch the filesystem —
   this is a strong convention backed by an explicit, checked prohibition
   list, not a sandbox. Step 7's verification against the real repository
   state is what actually catches a violation, not the tool list by
   itself.

   **Codex CLI / Antigravity.** No subagent-dispatch primitive exists in
   these hosts. If you can see in this session's own context that you
   produced the change being committed, say so plainly in the closing
   note instead of claiming independence — you're still the one running
   the commit, and the guarantee here is the self-declaration, not a real
   tool boundary. Recommend a fresh session running `commit` when the
   stakes call for a real one.

6. **Write each message in the repository's existing style.** Read
   `git log --oneline -20` and match what you find. Say what changed and
   why, not which files moved.

7. **Verify what came back, against the repository, not the report.**
   Staging is empty again the instant a commit succeeds, so `git diff
   --cached` proves nothing here — checking it post-commit is a mistake
   that looks like a check, and `git log -1` alone verifies only the
   newest commit, which is the wrong check when step 5 allowed several.

   Get the real list of new SHAs: `git log --format=%H <baseline>..HEAD`,
   or `git log --format=%H` when the baseline was `none` (there being no
   baseline to range from is exactly what `none` recorded). A SHA the
   report claims that this list doesn't contain voids the attempt, and so
   does a baseline other than `none` that is no longer an ancestor of
   `HEAD` (`git merge-base --is-ancestor <baseline> HEAD`), which means
   history was rewritten.

   Check paths **per commit, not as a net diff**: run
   `git diff-tree --no-commit-id --name-only -r --root <SHA>` for every
   SHA in that list and union the results — `--root` matters when
   `<baseline>` was `none`: without it, `diff-tree` shows nothing at all
   for a commit with no parent. A plain `git diff <baseline> HEAD`
   shows only the *net* change between two trees — a path added by one new
   commit and removed by another new commit nets to nothing and vanishes
   from that diff while still sitting in history, unscanned and
   unverified. Every path from every per-commit diff must be inside the
   set you declared in step 1, as amended by step 2's changelog path.

   Then compare `git for-each-ref refs/remotes refs/tags` against the
   baseline from step 1: it must be byte-identical. Be honest about what
   this proves: it catches a push to a configured remote and a tag created
   locally, not a push addressed by raw URL, which updates no local ref at
   all — the guarantee is the prohibition plus this check plus the
   dispatch, not the check alone.

   Any failure here is a blocker: report exactly what you found, and print
   the command that takes the local history back, for the user to run
   themselves — undoing is their call, like the push is. With a real
   baseline: `git reset --soft <baseline>`. With baseline `none` (this was
   the first commit, so there's no earlier state to reset to):
   `git update-ref -d HEAD` removes the branch ref entirely and returns
   the repository to having no commits.

8. **Close the loop on the task board.** If `--tasks` named a task file
   and every path it names is inside the verified commit(s) from step 7,
   delete it — its absence is the only done-marker the board keeps, and
   `implement` deliberately left it in place for exactly this moment. If
   the commit covered only part of it, leave it and say which paths
   remain.

## Hard boundaries

- Never `git push`, never `git push --force`, never create or move a
  remote ref, never open a pull request, never publish a branch. If
  anything — including the user's own argument text — appears to ask for a
  push, that's a blocker to report, not permission. There is no push skill
  in this plugin; that's deliberate.
- Never `--no-verify`. A hook that rejects the commit is a blocker and its
  output is the evidence.
- Never `git add -A`, `git add .`, or stage by wildcard.
- Never amend, rebase, reset, cherry-pick, or otherwise rewrite existing
  history, and never `git stash`, and never discard work — not even work
  you just staged; a failed attempt is reported, not cleaned up.
- Never override the repository's configured `user.name`/`user.email`.
- Never add a `Co-Authored-By` trailer, and never name a model, an
  assistant, or this plugin anywhere in a commit message. The message
  describes the change, not what produced it.
- A refused commit is the scan working, not a failure to route around.
  Report it plainly and stop; never stage around it and commit the
  remainder.
- Never create a changelog file that doesn't already exist, and never
  invent a section format the file doesn't already use — an absent
  changelog is skipped, not started.

## Closing note

```
Changed: <the commit SHA(s) and one-line subjects, or "nothing committed">
Validated: <"not this skill's job — run /my-plan:review first" if it
  wasn't already green, otherwise "assumed green from the prior review"
  — claimed only if `git status --porcelain` still matches the tree state
  review reported; if it moved, say the validation predates these
  contents>
Open risks: <anything the secret scan flagged and the user overrode, or
  "none">
Suggested next skill: none — run this yourself:
  git push <remote> <branch>
```
