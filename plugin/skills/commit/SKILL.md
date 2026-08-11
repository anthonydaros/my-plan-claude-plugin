---
name: commit
description: Stage exactly the intended paths, scan for leaked secrets in code and prose, commit in the repository's own style. Never pushes, never forces, never --no-verify, never touches history. Prints the push command for you to run yourself. Manual only.
argument-hint: "[path ... | --spec docs/brief.md | --tasks docs/tasks/<file>]"
disable-model-invocation: true
---

# My Plan: Commit

Turns an already-reviewed, already-working change into local Git history.
Doesn't write code, doesn't fix findings, and never leaves the machine —
there is no push skill. The push is a separate command you run yourself,
after reading what this printed.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:commit` in the user's message
instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

Arguments are one of: a list of paths to commit, `--spec <path>` naming a
brief whose write set bounds what may be staged, or `--tasks <path>` naming
a task file whose paths bound it the same way. Empty means "commit what's
dirty," and that requires confirming the staged set explicitly with the
user before dispatching — never infer intent from an empty argument
silently.

## Declared blindness

If `--spec` or `--tasks` was given, read it and treat its write set as the
expected staged set — anything staged outside it is a finding, not a silent
inclusion. If neither was given, check `docs/brief.md` and `docs/tasks/`
for something to bound against; if nothing's there either, print one line —
`not evaluated: no --spec/--tasks given or found; staging exactly the paths
named on the command line` — and proceed on the explicit path list alone.

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

2. **Run the secret scan yourself, before staging anything**, over the
   actual current content of every candidate path — not "the diff": a
   brand-new untracked file has no diff to read (`git diff` alone will
   miss it entirely), so read the file's real content directly, the same
   way for a new file as for a modified one:
   - Refuse these paths outright, whatever their content: `.env` and
     `.env.*` other than `.env.example`, `*.pem`, `*.key`, `*.p12`,
     `*.pfx`, `id_rsa` and other private keys, `*.keystore`, `.npmrc` and
     `.pypirc` with credentials, `credentials.json`,
     `service-account*.json`, `*.tfstate`, `.aws/`, `.ssh/`,
     `.kube/config`, any local database dump.
   - Grep the content for assigned secrets: `password`, `passwd`,
     `secret`, `token`, `api[_-]?key`, `private[_-]?key`, `authorization`,
     `bearer `, `BEGIN .* PRIVATE KEY`, plus provider prefixes `sk-`,
     `sk_live_`, `sk_test_` (the `-` in `sk-` never matches the Stripe
     underscore form), `ghp_`, `gho_`, `github_pat_`, `ghs_`, `ghu_`,
     `glpat-`, `npm_`, `AKIA`, `AIza`, `xox[baprs]-`, and `eyJ` opening a
     long dotted token (a JWT). A hit that's a real value, not a variable
     name or placeholder, stops that path. If `gitleaks` or `trufflehog`
     is installed, run it over the candidate paths too and treat its
     findings as findings — a maintained scanner outranks this list; the
     list is the floor, not the ceiling.
   - Read prose you're about to stage, not only code — a credential quoted
     into a markdown doc while investigating something is a leak the code
     scan above won't catch.
   - Personal paths, internal hostnames, and customer identifiers get the
     same treatment. They aren't credentials, but they aren't yours to
     publish either.
   - A trip here doesn't mean quietly dropping the path and committing the
     rest. Tell the user what was found, where, and stop before staging
     it — refusing is the scan working, not a failure to route around.

3. **Stage exactly the named paths, explicitly** — one by one or as an
   explicit list. Never `git add -A`, never `git add .`, never a wildcard.

4. **Dispatch the commit — don't write it inline.**

   **Claude Code.** Dispatch the actual commit to the `my-plan-committer`
   agent (defined at `../../agents/my-plan-committer.md`) via the Task
   tool. Don't commit
   inline yourself — you've watched however much of this session produced
   the change, which is exactly what makes you a poor judge of whether a
   staged path belongs; a fresh subagent that only sees the staged diff
   and the declared path set catches what familiarity hides. Give it, in
   the dispatch prompt: the exact path set from step 3, the repository
   root, and the commit-grouping intent (one commit for a small cohesive
   change, several atomic commits when independent changes make better
   history). Its withheld `Write`/`Edit`/`NotebookEdit` tools are a real
   boundary against *editing tracked files*, but `Bash` can still touch
   the filesystem — this is a strong convention backed by an explicit,
   checked prohibition list, not a sandbox. Step 6's verification against
   the real repository state is what actually catches a violation, not the
   tool list by itself.

   **Codex CLI.** No subagent-dispatch primitive exists here. If you can
   see in this session's own context that you produced the change being
   committed, say so plainly in the closing note instead of claiming
   independence — you're still the one running the commit, and the
   guarantee here is the self-declaration, not a real tool boundary.
   Recommend a fresh `$my-plan:commit` session when the stakes call for a
   real one.

5. **Write each message in the repository's existing style.** Read
   `git log --oneline -20` and match what you find. Say what changed and
   why, not which files moved.

6. **Verify what came back, against the repository, not the report.**
   Staging is empty again the instant a commit succeeds, so `git diff
   --cached` proves nothing here — checking it post-commit is a mistake
   that looks like a check, and `git log -1` alone verifies only the
   newest commit, which is the wrong check when step 4 allowed several.

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
   set you declared in step 1/3.

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

7. **Close the loop on the task board.** If `--tasks` named a task file
   and every path it names is inside the verified commit(s) from step 6,
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

## Closing note

```
Changed: <the commit SHA(s) and one-line subjects, or "nothing committed">
Validated: <"not this skill's job — run /my-plan:validate first" if it
  wasn't already green, otherwise "assumed green from the prior validate"
  — claimed only if `git status --porcelain` still matches the tree state
  validate reported; if it moved, say the validation predates these
  contents>
Open risks: <anything the secret scan flagged and the user overrode, or
  "none">
Suggested next skill: none — run this yourself:
  git push <remote> <branch>
```
