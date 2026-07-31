---
name: install
description: Guided setup, repair, reconfigure, or migrate for My Plan. Verifies capabilities, collects the Working Profile, and initializes the current repository. Manual only.
argument-hint: "[repair|reconfigure|migrate]"
disable-model-invocation: true
---

# My Plan: Install

Guided setup. Read `${CLAUDE_PLUGIN_ROOT}/internal/stages/project.md` and follow
it. That module owns the capability probes, the Working Profile, the Project
Profile, the Project Skill, and the Architecture Memory.

Mode: $ARGUMENTS

- Empty: fresh setup, or resume an interrupted one.
- `repair`: re-probe capabilities and fix what setup left broken. Do not discard
  answers the user already gave.
- `reconfigure`: keep verified facts, re-ask the preference questions.
- `migrate`: move managed files to the current schema. Preserve any edit you do
  not recognize by stopping for reconciliation rather than overwriting it.

## What setup must end with

- Every required capability verified: Claude Code 2.1.216 or later, Git, Context7.
- Every optional capability probed and reported: Codex CLI, GitHub CLI, Playwright.
- A backend selected: `hybrid` if Codex passes every probe, otherwise
  `claude-only` with the missing capability named.
- The effective model mapping shown.
- The command aliases verified, with any collision reported alongside its
  `/my-plan:*` fallback.
- A Working Profile persisted at `<stateRoot>/profile.json`. Its presence is what
  every later Run checks to decide whether setup already happened, so nothing else
  serves as that signal.
- The state root path reported to the user, so they know where Run state lives.

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
- Missing Codex is not a failure. Report it, select `claude-only`, and continue.
- Install no runtime, package dependency, daemon, hook, or executable.
- Write no personal path, account, repository, or credential into any managed
  file.
- Preserve `CLAUDE.md`, `AGENTS.md`, custom skills, and existing documentation.
  Managed files are deterministic and idempotent.

## Autonomous sessions

Offer to reduce routine permission prompts without broadening access: native
`dontAsk`, narrow tool lists per agent, read-only discovery and review agents, and
explicit write sets for implementation.

Unrestricted bypass is an advanced opt-in only. Present the host's own safety
warning, require an explicit choice, and never enable it silently or through
repository configuration.

## Reporting

End with a short status: what was verified, what backend was selected, the
effective model mapping, the state root, any collision fallback, and the single
next command to run.
