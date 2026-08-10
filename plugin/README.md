# My Plan — skills guide

Eight independent skills. Each does one job, reads and writes plain files
under `docs/`, and stops. Nothing chains automatically — you decide what to
run and when. This guide covers every skill in detail: what it does, how to
invoke it, what it reads and writes, and a worked example.

For install instructions, see the [repository README](../README.md).

## Invocation

| Host | Syntax | Example |
|---|---|---|
| Claude Code | `/my-plan:<skill> <args>` | `/my-plan:spec "add CSV export to the reports page"` |
| Codex CLI | `$my-plan:<skill> <args>` | `$my-plan:spec "add CSV export to the reports page"` |

Every skill is manual only — typing the command is the only way to start
one; no skill invokes another or invokes itself automatically. Both hosts
read the exact same skill body; only the invocation prefix differs.

## Conventions every skill follows

Three things repeat across all eight skills, explained once here instead of
in every section below:

- **Declared blindness.** `review`, `validate`, and `commit` accept an
  optional `--spec docs/brief.md` (`commit` also `--tasks`) to bound what
  they check against. When neither is given or found, the skill doesn't
  silently skip that checking — it prints one line saying so, such as
  `Conformance: not evaluated — no brief or plan supplied or found.`
- **Independence.** `review-plan`, `review`, `validate`, and `commit` each
  do something a fresh, uninvolved reviewer would do better than the
  session that just wrote the thing. In Claude Code, they dispatch a real
  subagent (`agents/my-plan-reviewer.md` or `agents/my-plan-committer.md`)
  that holds no file-editing tool and hasn't seen the work happen. Codex
  CLI has no subagent mechanism, so the skill instead says plainly when its
  own context shows it authored what it's about to judge, rather than
  claiming an independence it doesn't have.
- **Closing note.** Every skill that changes or evaluates something ends
  with the same four lines, printed to the conversation and never saved to
  a file:
  ```
  Changed: <what actually changed>
  Validated: <what was actually run, or "not this skill's job">
  Open risks: <anything left open, or "none">
  Suggested next skill: <what to run next, or "none">
  ```
  This is advice, not a queue — you can ignore it and run whatever you want
  next.

## Recommended order

```
map → spec → plan → review-plan → implement (per task) → review → validate → commit
```

None of this is enforced. Run one skill in isolation for a small fix
(`implement` then `commit`), or walk the whole chain for a real feature.
Every closing note suggests the next step in this order, but nothing stops
you from skipping around.

---

## `map`

**Writes or refreshes `docs/map.md`** — a durable, committed repository
navigator: stack, exact validation commands, module boundaries, non-obvious
conventions, proven pitfalls. It's the one document the other skills check
for first, so a bare `review` or `implement` invocation isn't reasoning from
nothing.

`docs/map.md` is an ordinary file. `map` writes it directly but never
commits it — read the diff, edit it by hand, delete a stale section,
revert it. You keep the last word.

**Usage:**

```
/my-plan:map                # write it the first time, or re-verify all of it
/my-plan:map refresh        # same as empty — explicit re-verification
/my-plan:map auth           # narrow to one area; other sections are left alone
```

**Reads:** package manifests and lockfiles, CI configuration, existing
canonical docs, test configuration, `git log` for recurring-pitfall
patterns.

**Writes:** `docs/map.md` only.

**Example.** In a Django + React repository with no `docs/map.md` yet:

```
/my-plan:map
```

produces something like:

```markdown
# reports-service: Map

## Stack
Python 3.12 / Django 5, React 18 + Vite. Package manager: uv (Python), pnpm (JS).

## Validation
`uv run pytest` — backend tests, CI: .github/workflows/ci.yml:12
`pnpm test` — frontend unit tests, package.json:"scripts"."test"
`pnpm build` — must pass before any frontend PR merges

## Module boundaries
`reports/exporters/` never imports from `reports/views/` — exporters are
called by views, not the reverse. Breaking this created a circular import
twice (see git log on reports/exporters/csv.py).

## Conventions that aren't obvious from the code
All money fields are integer cents, never floats — see reports/models.py:41.

## Pitfalls
`reports/tasks.py` runs in Celery with no request context — code moved from
a view into a task has broken on missing `request.user` three times.
```

Run `/my-plan:map refresh` later when the stack or conventions have moved
on; it treats the existing file as a claim to verify, not a draft to
overwrite, and preserves anything you hand-edited into it.

---

## `spec`

**Turns a rough goal into `docs/brief.md`** — a decision-complete brief with
numbered requirements, non-goals, testable acceptance criteria, risks, and
an expected write set. Gets there by asking only the questions the
repository genuinely can't answer itself, one at a time, capped at roughly
ten questions total.

**Usage:**

```
/my-plan:spec "add CSV export to the reports page"
```

**Reads:** `docs/map.md` if it exists (and does a lighter version of that
same investigation itself if it doesn't); the web, only when the repository
can't settle a business or domain question.

**Writes:** `docs/brief.md` only.

**Example session:**

```
> /my-plan:spec "add CSV export to the reports page"

Read docs/map.md. Reports page is reports/views.py:ReportListView, renders
a paginated table server-side.

Q1 [Scope]: Export the current filtered/sorted view, or always all rows?
  a) Current view (respects filters, sort, search) — recommended: matches
     user's mental model of "export what I'm looking at"
  b) Always all rows, ignoring filters
  → current view

Q2 [Row limit]: Cap the export size?
  a) No cap — recommended: reports rarely exceed a few thousand rows here
  b) Cap at N rows with a warning
  → no cap

[... a few more rounds ...]

Nothing left to ask. Decisions made without asking: date columns export in
ISO 8601, not the UI's localized format (reversible, standard practice).

Changed: docs/brief.md written
Validated: not this skill's job
Open risks: none
Suggested next skill: plan
```

The brief now has testable acceptance criteria like *"Given a filtered
report view, when the user clicks Export CSV, then the downloaded file
contains exactly the filtered rows in ISO 8601 date format."* — precise
enough for `validate` to later find the test that would fail if it broke.

---

## `plan`

**Turns the brief into `docs/plan.md` plus one file per task** under
`docs/tasks/`, each sized for a writer who sees only that one file — a
handful of files, one idea, verifiable alone, complete without hidden
context.

**Usage:**

```
/my-plan:plan                       # plans from docs/brief.md
/my-plan:plan docs/briefs/csv.md    # plans from a specific brief
/my-plan:plan "just add a /health endpoint"   # plans without a brief, for small work
```

**Reads:** the brief (the argument path, or `docs/brief.md`), `docs/map.md`
if it exists, `knowledge/checklists/architecture.md` for the five questions
any new layer or abstraction must answer.

**Writes:** `docs/plan.md` and `docs/tasks/01-*.md`, `docs/tasks/02-*.md`,
etc. — zero-padded by dependency order, so a bare `ls docs/tasks/` reads in
build order.

**Example output** (abridged):

```
docs/plan.md          — Approach, write set, execution order
docs/tasks/01-csv-serializer.md    — new reports/exporters/csv.py, no deps
docs/tasks/02-export-endpoint.md   — new view + URL route, depends on 01
docs/tasks/03-export-button.md     — frontend button + fetch call, depends on 02
docs/tasks/04-export-tests.md      — integration test, depends on 02, 03
```

Each task file names exact paths, the failure path (empty report, export
mid-request), and the check that proves it done — a writer opening only
`03-export-button.md` has everything it needs.

```
Changed: docs/plan.md and 4 files under docs/tasks/ written
Validated: not this skill's job
Open risks: none
Suggested next skill: review-plan — in Claude Code the dispatch already
  gives you a fresh reviewer; in Codex, open a fresh session first
```

---

## `review-plan`

**Adversarially reviews `docs/plan.md`** and its task files before any code
exists: missing acceptance coverage, impossible steps, unsafe scope, weak
sequencing, weak tests, overengineering. A separate skill from `plan` on
purpose — the plan's reviewer should not be its author.

**Usage:**

```
/my-plan:review-plan                  # reviews docs/plan.md
/my-plan:review-plan docs/other.md    # reviews a specific plan
```

**Reads:** the plan, every task file it lists, the brief it was planned
against, `docs/map.md`, `knowledge/checklists/architecture.md`.

**Writes:** nothing — read-only.

**Example:**

```
> /my-plan:review-plan

Report: docs/plan.md

Findings:
docs/tasks/02-export-endpoint.md:—  major  executability  No failure path
  stated for a report with zero matching rows. Add: "empty result exports
  a header-only CSV, not a 404."
docs/tasks/04-export-tests.md:—  minor  tests  References section omits
  reports/tests/factories.py, which 03's test will need to build fixture
  reports.

Lens coverage: conformance passed, correctness passed (1 finding above),
tests passed (1 finding above), complexity passed.

2 findings: 0 blocker, 1 major, 1 minor.

Changed: none — read-only
Validated: not this skill's job
Open risks: 1 major
Suggested next skill: fix findings then re-run review-plan, or implement
  if there are zero blockers
```

Fix the findings (by hand, or re-running `plan` with the gaps in mind), then
re-run `review-plan` until it comes back clean.

---

## `implement`

**Builds exactly one task**, completely, and stops. Doesn't review its own
work — that's `review`'s job — and doesn't touch anything outside the
task's declared paths.

**Usage:**

```
/my-plan:implement docs/tasks/01-csv-serializer.md
/my-plan:implement "fix the typo in the export button label"   # no task board needed
```

**Reads:** only the named task file (never the plan or the other tasks —
that's deliberate, so it can't accidentally lean on context a real writer
wouldn't have), `docs/map.md`, `knowledge/checklists/implementation.md` for
the parts the task's surface actually touches.

**Writes:** whatever the task's write set names. Never stages or commits —
that's a separate skill, run separately.

**Example:**

```
> /my-plan:implement docs/tasks/01-csv-serializer.md

Wrote reports/exporters/csv.py: to_csv(queryset) using csv.writer, ISO 8601
dates. Added tests/exporters/test_csv.py: empty queryset, single row,
special characters requiring quoting.

Ran: uv run pytest tests/exporters/test_csv.py — 4 passed

Changed: reports/exporters/csv.py, tests/exporters/test_csv.py (new files,
  verified against git status --porcelain)
Validated: uv run pytest tests/exporters/test_csv.py — 4 passed (sanity
  check only, not a substitute for /my-plan:validate)
Open risks: none
Suggested next skill: review, then validate, then
  commit --tasks docs/tasks/01-csv-serializer.md — or the next task under
  docs/tasks/, if more remain
```

The task file is left in place on purpose — `commit --tasks` is what
deletes it, once the work is actually in history. "Implemented but never
committed" isn't done yet.

---

## `review`

**Reviews a diff, a branch, a path, or the whole repository** (`--repo`)
against the eleven-lens checklist (conformance, correctness, security,
maintainability, tests, performance, behavior, design, accessibility, ux,
complexity). Evidence-backed findings only — a claim without a path and a
line range, or a command's real output, isn't reportable.

**Usage:**

```
/my-plan:review                          # the working diff (git diff HEAD + untracked)
/my-plan:review feature/csv-export        # a branch, against its merge-base
/my-plan:review reports/exporters/        # a path
/my-plan:review --repo                    # the whole repository, no diff to follow
/my-plan:review --spec docs/brief.md      # check conformance against a specific brief
/my-plan:review --fix                     # fix findings after reporting them
```

**Reads:** `knowledge/checklists/review.md` always; `docs/map.md` if it
exists; up to two guides from `knowledge/references/` (the repository's
stack, plus whichever cross-cutting concern applies); in `--repo` mode,
also `knowledge/checklists/architecture.md` and `implementation.md`.

**Writes:** nothing, unless `--fix` was given — then exactly the findings
it just reported, one at a time, re-verifying each before the next.

**Example:**

```
> /my-plan:review

Report: working diff (4 files)

Findings:
reports/exporters/csv.py:18  minor  maintainability  Magic number 8192 for
  the chunk size. Name it CSV_CHUNK_SIZE.

Lens coverage: conformance not-applicable (no brief supplied or found),
correctness passed, security passed, maintainability passed (1 finding),
tests passed, performance passed, behavior passed, design not-applicable
(no UI surface in this diff), accessibility not-applicable, ux passed,
complexity passed.

1 finding: 0 blocker, 0 major, 1 minor, 0 note.

Changed: none — read-only
Validated: not this skill's job
Open risks: none
Suggested next skill: validate, then commit
```

Passing `--spec docs/brief.md` here would also evaluate the `conformance`
lens against the brief's requirements instead of marking it not-applicable.

---

## `validate`

**Independently executes the repository's real validation commands** and
reports the real exit codes — never trusts a report of "tests pass" from
whoever just wrote the code. Also checks that the brief's acceptance
criteria are actually exercised by a real command, not just that some
suite is green.

**Usage:**

```
/my-plan:validate                     # finds commands from docs/map.md, CI, or package scripts
/my-plan:validate --spec docs/brief.md
```

**Reads:** `docs/map.md`'s Validation section first, then CI configuration,
then package scripts, in that order; the brief's acceptance criteria if one
is named or found.

**Writes:** nothing tracked — it explicitly checks that it left the tree
the way it found it, and reports if a command wrote to a tracked file
anyway.

**Example:**

```
> /my-plan:validate

Ran: uv run pytest — 142 passed, 0 failed
Ran: pnpm test — 38 passed, 0 failed
Ran: pnpm build — exit 0

Acceptance criteria checked:
"Filtered export contains exactly the filtered rows" — exercised by
  tests/exporters/test_csv.py::test_respects_filters — passed.

Changed: none — read-only
Validated: uv run pytest (exit 0), pnpm test (exit 0), pnpm build (exit 0)
Tree: clean — nothing left dirty
Open risks: none
Suggested next skill: commit, if everything's green
```

A command that passed once and failed on a repeat run is reported as a
flakiness finding, not silently retried until it's green.

---

## `commit`

**Stages exactly the intended paths, scans for leaked secrets in code and
prose, commits in the repository's own message style.** Never pushes,
never forces, never `--no-verify`, never rewrites history. There is no push
skill — this is the one that gets you to the edge of "leaves the machine,"
and stops there.

**Usage:**

```
/my-plan:commit reports/exporters/csv.py reports/views.py
/my-plan:commit --spec docs/brief.md              # bound by the brief's write set
/my-plan:commit --tasks docs/tasks/01-csv-serializer.md   # bound by one task, deletes it once verified
/my-plan:commit                                   # commit what's dirty — asks first
```

**Reads:** the actual current content of every candidate path — including
brand-new untracked files, and prose (a credential pasted into a markdown
note is a leak the code-only scan misses).

**Writes:** the commit(s). Deletes the named task file once its work is
verified inside the new commit(s), if `--tasks` was given.

**Example:**

```
> /my-plan:commit --tasks docs/tasks/01-csv-serializer.md

Staged: reports/exporters/csv.py, tests/exporters/test_csv.py
Secret scan: clean
Committed: a1b2c3d "Add CSV export serializer for reports"
Verified: git diff-tree confirms exactly those 2 paths in the new commit;
  refs/remotes and refs/tags unchanged
Deleted: docs/tasks/01-csv-serializer.md (work now in history)

Changed: a1b2c3d "Add CSV export serializer for reports"
Validated: assumed green from the prior validate — tree unchanged since
Open risks: none
Suggested next skill: none — run this yourself:
  git push origin feature/csv-export
```

If the secret scan or the post-commit verification ever finds something
wrong, `commit` stops and reports it — it never quietly drops a path and
commits the rest, and it never repairs a bad commit itself. It tells you
the exact command to undo it yourself.

---

## A full walkthrough

Adding CSV export end to end, from nothing to pushed:

```
/my-plan:map                                          # once per repo, or when it drifts
/my-plan:spec "add CSV export to the reports page"    # → docs/brief.md
/my-plan:plan                                          # → docs/plan.md + docs/tasks/*.md
/my-plan:review-plan                                   # fix findings, re-run until clean
/my-plan:implement docs/tasks/01-csv-serializer.md     # repeat per task
/my-plan:implement docs/tasks/02-export-endpoint.md
/my-plan:implement docs/tasks/03-export-button.md
/my-plan:implement docs/tasks/04-export-tests.md
/my-plan:review                                        # against the working diff
/my-plan:validate --spec docs/brief.md
/my-plan:commit --spec docs/brief.md                   # one commit or several, your call
git push origin feature/csv-export                     # your call, always
```

A one-line fix doesn't need most of this: `/my-plan:implement "fix the typo
in the export button label"` then `/my-plan:review`, `/my-plan:validate`,
`/my-plan:commit` is a complete, safe path on its own.
