# My Plan

**Eight sharp, independent skills for the whole arc of a change — no
orchestration, no state machine, no runtime installed in your repository.**

`map` · `spec` · `plan` · `review-plan` · `implement` · `review` · `validate` · `commit`

Each skill is invoked by hand, does one job, prints a closing note, and
stops. Nothing chains automatically. The filesystem is the only state
between them — `docs/map.md`, `docs/brief.md`, `docs/plan.md`, and
`docs/tasks/*.md` are ordinary files: commit them, edit them, delete them.
Run any one skill alone, or work through the whole arc when the change
deserves it.

---

## Install

### Claude Code

```bash
/plugin marketplace add anthonydaros/my-plan-claude-plugin
/plugin install my-plan@my-plan
```

### Codex CLI

```bash
codex plugin marketplace add anthonydaros/my-plan-claude-plugin
codex plugin add my-plan@my-plan-codex
```

Start a new session after installing or updating so the skills reload. One
plugin tree serves both hosts — every skill body is read verbatim by each;
only the two manifests differ.

---

## The eight skills

| Skill | What it does |
|---|---|
| `map` | Writes `docs/map.md` — stack, exact validation commands, module boundaries, proven pitfalls. The planning, review, and validation skills read it first when it exists. |
| `spec` | Turns a rough goal into `docs/brief.md`: decision-complete, testable acceptance criteria, a bounded round of one-at-a-time questions. |
| `plan` | Turns the brief into `docs/plan.md` plus one file per task under `docs/tasks/` — each sized for a writer who sees only that file. |
| `review-plan` | Attacks the plan before any code exists: missing coverage, impossible steps, unsafe scope, overengineering. Run it in a fresh session. |
| `implement` | Builds exactly one task. Leaves the task file for `commit` to delete once the work is actually in history. |
| `review` | Reviews a diff, a branch, a path, or the whole repository (`--repo`) against an eleven-lens checklist. Evidence-backed findings only. |
| `validate` | Re-runs the repository's real validation commands itself and reports real exit codes — never trusts a claimed green. |
| `commit` | Stages exactly the intended paths, scans code *and prose* for secrets, commits in your repository's own style. Prints the push command; never runs it. |

Invoke with `/my-plan:<skill>` in Claude Code or `$my-plan:<skill>` in
Codex CLI — for example `/my-plan:spec "add dark mode"` or
`$my-plan:review --repo`.

**[Full skills guide](plugin/README.md)** — what each skill reads and
writes, usage examples, and a worked walkthrough from goal to pushed
commit.

### Composing them

The natural order is:

```
map → spec → plan → review-plan → implement (per task) → review → validate → commit
```

Every closing note suggests the next step, but nothing enforces the order —
you decide when to run each one, and you can run any of them alone. A
one-line fix might be `implement` then `commit`; a real feature might walk
the whole chain.

---

## Why no orchestration

An earlier version of this plugin was a single automatic pipeline: two
commands, a persistent Run manifest, a Coordinator dispatching narrow
Worker subagents through a JSON handoff contract, isolated Git worktrees,
hash-chained approvals. It worked, but it was a lot of machinery standing
between a user and the thing they actually wanted to happen — and every
piece of that machinery was something to understand, trust, and debug
before the plugin did anything useful.

This version keeps the parts that were actually guarantees — an
independent reviewer, a secret-scanned commit, a real validation run — and
throws out everything that only existed to carry state between phases you
could just... run yourself, in order, whenever you decide.

## What it will never do

- **Push.** There is no push skill. `commit` prints
  `git push <remote> <branch>` and stops; you run it.
- `git add -A`, `--force`, `--no-verify`, or rewrite history.
- Commit a credential. Every candidate path is content-scanned before
  staging — including brand-new untracked files and markdown prose, not
  just tracked-file diffs.
- Sign your commits. No `Co-Authored-By`, no model name, anywhere. History
  belongs to you.
- Review its own work silently. In Claude Code, `review`, `review-plan`,
  `validate`, and `commit` dispatch fresh, read-only subagents. In Codex
  CLI, which has no subagent primitive, the skill says plainly when it
  authored what it's judging instead of pretending independence it
  doesn't have.

## Requirements

| Host | Required |
|------|----------|
| Claude Code | Claude Code with plugin support, Git 2.28+ |
| Codex CLI | Codex CLI with `exec`, Git 2.28+ |

Nothing else. No MCP server, no LSP, no hook, no other CLI is a
dependency — only Git and the host itself.

## Uninstall

```bash
/plugin uninstall my-plan@my-plan          # Claude Code
codex plugin remove my-plan@my-plan-codex  # Codex CLI
```

---

## License

MIT. Third-party review guides under `plugin/knowledge/references/` are
vendored from [awesome-skills/code-review-skill](https://github.com/awesome-skills/code-review-skill)
under their own MIT license — see `plugin/knowledge/references/NOTICE.md`.
