---
name: install
description: Guided setup, repair, reconfigure, or migrate for My Plan. Verifies capabilities, collects the Working Profile, and initializes the current repository. Manual only.
---

# My Plan: Install

Guided setup. Let `<pluginRoot>` be the absolute directory two levels above this
loaded `SKILL.md`. Read `<pluginRoot>/internal/stages/project.md` and follow it.
That module owns the capability probes, the Working Profile, the Project
Profile, the Project Skill, and the Architecture Memory.

Mode is the text after `$my-plan:install` in the user's request.

- Empty: fresh setup, or resume an interrupted one.
- `repair`: re-probe capabilities and fix what setup left broken. Do not discard
  answers the user already gave.
- `reconfigure`: keep verified facts, re-ask the preference questions.
- `migrate`: upgrade a repository initialized by an earlier version to the
  current format, per `project.md` Part 5 — state schemas, Project Skill,
  legacy dossier files, unfinished Runs. Preserve any edit you do not recognize
  by stopping for reconciliation rather than overwriting it.

Setup detects the earlier dossier format by itself — `docs/my-plan/` in the
repository, `runDocsRoot` in `project.json`, a `run.json` at `schemaVersion` 1
— and enters that migration whatever mode was invoked. Running plain install on
an already-installed repository is always safe: it verifies, repairs, and
upgrades; it never restarts and never discards answers.

## What setup must end with

- Every required capability verified: Codex CLI with the required `exec`
  features, and Git 2.28 or later.
- Every optional capability probed and reported: Context7, GitHub CLI,
  Playwright, and any documentation, indexing, or LSP tooling the session
  exposes. Optional tools speed the work up and are never depended on.
- Runtime fixed to `codex-only` and the effective Sol, Terra, and Luna model
  mapping shown.
- Sol and Terra resolve to different model IDs. A single ID cannot write and
  review the same subject.
- A Working Profile persisted at `<stateRoot>/profile.json`. Its presence is what
  every later Run checks to decide whether setup already happened, so nothing else
  serves as that signal.
- The state root path reported to the user, so they know where Run state lives.
- No earlier format left behind: a repository showing any signal from
  `project.md` Part 5 has been migrated, or has its remaining per-Run choices
  reported to the user.

When run inside a repository, setup may also materialize the Project Profile,
Project Skill, and Architecture Memory. This is the one case where those files are
written outside a worktree, because the user asked for it directly.

## Rules

- Resume, never restart. If the user fixes a missing prerequisite and runs setup
  again, continue from where it stopped.
- Report versions and authentication readiness. Never read, echo, or store a
  secret value.
- Give exact remediation for anything missing. "Install Git" is not remediation;
  the command for their platform is.
- A missing required Codex capability blocks setup with exact remediation.
- Install no runtime, package dependency, daemon, hook, or executable.
- Write no personal path, account, repository, or credential into any managed
  file.
- Preserve existing agent instructions, custom skills, and documentation.
  Manage only the paths this plugin owns; managed files are deterministic and
  idempotent.

## Autonomous sessions

Explain the child-session boundaries: discovery, planning, and review use the
read-only sandbox; implementation, the QA gate, and the commit use
workspace-write with explicit write sets. The parent session keeps its current
permission profile.

Unrestricted bypass is an advanced opt-in only. Present the host's own safety
warning, require an explicit choice, and never enable it silently or through
repository configuration.

## Reporting

End with a short status: what was verified, the `codex-only` runtime, the
effective model mapping, the state root, and the single next command to run.
