# Stage: Project

Environment setup, repository facts, and the two durable memory artifacts. Loaded
by `/my-plan-install`, and automatically by the other actions when setup is
missing.

This module never asks the user something the machine can answer.

## Part 1: Working Profile

User-level, independent from any repository. Skip this part if a valid Working
Profile already exists and the mode is not `reconfigure`.

### Capability probes

Probe capabilities, not version strings alone. A version that claims support but
fails its probe is not supported.

**Required. Setup does not complete without these.**

| Capability | Probe | If missing |
|------------|-------|------------|
| Claude Code 2.1.216+ | `claude --version`, compared numerically | Give the exact upgrade command for their platform |
| Git 2.28+ | `git --version`. 2.28 is the floor because `git init -b` needs it | Give the exact install command for their platform |
| Context7 | One real documentation query that returns content | Give the exact connection steps |

Claude must expose: structured questions, `WebSearch`, `WebFetch`, model
selection, isolated agents, and the native file and shell tools. You are running
inside Claude Code, so check your own tool availability rather than shelling out.

**Optional. Report and continue.**

| Capability | Probe | If missing |
|------------|-------|------------|
| Codex CLI | `codex --version`, then `codex exec --help` and `codex exec resume --help`, checking that the help text lists `-C`, `--sandbox`, `--json`, `--output-schema`, and `-o`. Then `codex login status` for authentication | Select `claude-only`, name the missing capability, continue |
| GitHub CLI | `gh --version` and `gh auth status` | Note it. Required only when an approved action needs GitHub itself, such as creating a remote. Existing remotes use Git directly |
| Playwright | `playwright --version`, then `playwright-cli --version`. Either counts | Recommend it for browser validation. Never block on it |

Probe the flags from the help output rather than by running a real Codex turn: a
probe that costs a model call is a probe people learn to skip.

Report installed versions and whether authentication is ready. Never read, echo,
log, or store a secret value.

### Backend selection

Codex passes every probe: `hybrid`. Anything else: `claude-only`, with the reason
stated.

`claude-only` is not a degraded mode. It completes the full flow. Present it as
the default it is, not as a fallback the user should feel bad about.

### Model mapping

Use aliases and capability probes. Never pin a release-specific model ID; it will
be wrong within months.

Fable is used for discovery and for review. It does not create plans and it does
not write code.

**Claude-only**

| Role | Model | Falls back to |
|------|-------|---------------|
| Discovery | Fable | Opus, then Sonnet |
| Plan creation | Opus | Sonnet |
| Plan review | Fable | Opus |
| Implementation, tests, remediation | Sonnet | Opus |
| Code review, coverage review | Fable | Opus, then a separate Sonnet session |

**Hybrid** keeps discovery on Fable and plan creation on Opus, then uses Codex:
Sol at `xhigh` effort for plan review and technical code review, Luna for
implementation, and an independent Fable Worker for product review.

Two rules survive every fallback. The model that wrote the plan never reviews the
plan, and the session that wrote code never reviews that code. If the only
remaining option would merge either pair, the Run blocks instead.

A configured user override wins over all of this. Show the effective mapping at
setup and at the start of each Run.

A fallback may reduce capability. It never lets the writer session review its own
work. If the only remaining option would merge those identities, the Run blocks
instead.

### Command aliases

Check what already owns each bare name. Look at the skills and commands visible in
this session, plus `.claude/skills/`, `.claude/commands/`, `~/.claude/skills/`,
and `~/.claude/commands/`. A name defined in any of them wins over a plugin skill.

For each of `/my-plan-install`, `/my-plan-start`, `/my-plan-audit`:

- Free: the bare alias works. Report it.
- Owned by a personal, project, enterprise, or other plugin command: that command
  wins. Report the collision and the exact `/my-plan:*` fallback.

Never create a standalone skill, change command precedence, or overwrite a command
the user already has.

### How the read-only boundary is actually enforced

Be honest about this, because the two backends are not equally strong.

**Codex Workers** get a real sandbox. `--sandbox read-only` is enforced by the
process, and a reviewer cannot write even if its prompt were wrong.

**Claude Workers** get a narrow `tools` list plus `disallowedTools`, which removes
`Write`, `Edit`, and `NotebookEdit`. But reviewers keep `Bash`, because they need
`git diff`, `git log`, and read-only inspection to do the job at all, and `Bash`
can write. `permissionMode` is ignored for agents that come from a plugin, so the
plugin cannot close that gap itself.

So for Claude reviewers the boundary is: no write tools, an explicit instruction,
and a Coordinator that verifies every changed path against Git and the approved
write set before trusting anything. That last check is what actually catches a
violation, which is why it is not optional.

Never present the Claude read-only boundary as a sandbox. If a Run needs an
enforced one, that is a reason to prefer the hybrid backend, not a reason to
pretend.

### Autonomous sessions

Offer to reduce routine permission prompts. Default to: native `dontAsk`, narrow
tool lists per agent, read-only discovery and review agents, explicit write sets
for implementation, and Git safety instructions.

Unrestricted bypass is an advanced explicit opt-in with the host's own safety
warning. Never enable it silently or through repository configuration.

### State root

`~/.claude/plugins/data/my-plan-my-plan/`, on Windows
`%USERPROFILE%\.claude\plugins\data\my-plan-my-plan\`. Create it if it does not
exist yet; the host does not create it for you.

That is the host's per-plugin data directory, and it survives plugin updates,
which is exactly what Run state and worktrees need.

Use the literal path, not `${CLAUDE_PLUGIN_DATA}`. That variable is exported to
hook processes and MCP subprocesses, not to the session running these
instructions, so reading it here yields an empty string. Two sessions that each
substitute their own guess end up with different state roots and cannot resume
each other's Runs.

Never put state under `${CLAUDE_PLUGIN_ROOT}`. That path is the installed plugin
copy and it changes on every update, so anything written there is lost the first
time the user upgrades.

Record the resolved path in the Working Profile so later Runs read it rather than
deriving it again.

Allow an explicit override, and offer one when the default would produce long
worktree paths. Windows path limits are a real constraint on deep worktrees, not
a theoretical one.

Report the resolved path. The user should know where their Run state lives and how
to remove it.

Layout:

```text
<stateRoot>/
├── profile.json                    # Working Profile. Its presence means setup ran
├── runs/<run-id>/
│   ├── run.json
│   ├── findings.json
│   ├── artifacts/
│   ├── handoffs/<attempt-id>.json
│   └── results/<attempt-id>.json
├── repos/<repo-key>/repo.json      # run index for this repo, not the Project Profile
├── locks/<repo-key>/
└── worktrees/<repo-key>/<run-short>/
```

### Identifiers and hashes

These appear throughout the plugin and mean nothing unless they are defined once,
here. Two sessions that pick different formats cannot verify each other's work.

| Value | Format | Example |
|-------|--------|---------|
| `<run-id>` | `<YYYYMMDD>-<4 hex chars>` | `20260731-7c41` |
| `<slug>` | The goal, lowercased, non-alphanumerics to `-`, trimmed to 40 chars | `add-input-validation` |
| `<attempt-id>` | `<run-id>-<role>-<n>`, `n` counting from 1 per role | `20260731-7c41-reviewer-2` |
| `<repo-key>` | Repository basename plus 8 hex of its absolute path | `task-api-75d0b10a` |
| `<run-short>` | The run id's 4 hex characters, without the date | `7c41` |

**Every hash in this product is SHA-256, rendered as lowercase hex.** Report the
first 12 characters in documents; keep the full digest in Run state.

| Hash | Computed over |
|------|---------------|
| Artifact hash | The file's exact bytes |
| Spec hash | `spec.md`'s exact bytes, which is what approval freezes |
| Review Subject hash | The output of `git diff <baseSha>` restricted to Run-owned paths, excluding `review.md` and `delivery.md` |
| Snapshot hash, when no diff exists (audit) | `git rev-parse HEAD^{tree}` |

A reviewer must be able to recompute the hash it was handed and get the same
string. Without one stated algorithm the check `subjectHash` performs is
theatre: it compares two numbers produced by different methods and passes when
they happen to match, which is never.

### run.json

The Run manifest. Resume reads this and nothing else to work out where a Run
stopped, so its shape cannot be left to whoever writes it first.

```json
{
  "schemaVersion": 1,
  "manifestRevision": 7,
  "runId": "20260731-7c41",
  "slug": "add-input-validation",
  "goal": "add input validation to the task API",
  "mode": "repository",
  "backend": "hybrid",
  "phase": "implementation",
  "status": "active",
  "repoKey": "task-api-75d0b10a",
  "repoPath": "/abs/path/to/repo",
  "defaultBranch": "main",
  "baseSha": "ba62788...",
  "branch": "my-plan/20260731-7c41",
  "worktree": "/abs/path/to/worktree",
  "runDocsRoot": "docs/my-plan",
  "pendingApproval": null,
  "approvedSpecHash": "sha256:...",
  "planHash": "sha256:...",
  "reviewSubjectHash": null,
  "currentTaskId": "T-03",
  "completedTaskIds": ["T-01", "T-02"]
}
```

`phase` is one of `discovery`, `spec`, `planning`, `implementation`,
`validation`, `review`, `delivery`.

`status` is one of `active`, `blocked`, `done`, `done_local`,
`ready_for_deploy`. It is never absent: a Run with no status cannot be resumed or
reported on, and every Run has one from the moment it is created.

`mode` is `repository`, `workspace`, or `greenfield`. In Workspace Mode add a
`repositories` array carrying the per-repository fields.

`manifestRevision` increments on every write. Two sessions writing the same Run
detect the conflict by comparing it.

Add fields when a Run genuinely needs them, but never rename these: a Run written
by one session must be resumable by another, and a field the reader does not know
is a Run it cannot continue.

Every state write uses a temporary sibling plus atomic replacement, and increments
`manifestRevision`. Leases use atomic directory creation carrying
owner, host, nonce, creation time, and expiry. No database, daemon, heartbeat, or
global active-Run pointer.

### Resume

Persist progress after each verified capability. If the user installs a missing
prerequisite and runs setup again, continue from where it stopped. Never restart
and never re-ask an answered question.

## Part 2: Project Profile

Repository facts, verified. Run this the first time a repository is seen.

Discover, do not ask:

- Stack, language versions, frameworks, and their actual versions in the lockfile.
- Package manager, from the lockfile that exists, not from preference.
- Directory structure and real module boundaries.
- Build, test, lint, type-check, and feature-check commands, from the scripts and
  config that exist.
- Test framework and where tests live.
- Default branch, remotes, and Git identity.
- CI configuration and what it actually enforces.
- Existing `CLAUDE.md`, `AGENTS.md`, ADRs, and canonical documentation.
- Deployment configuration, if any.

Ask only what the repository cannot answer: delivery constraints, a genuinely
ambiguous validation command, or a preference between two equally valid options.

Record in the Project Skill's `project.json`, inside the repository: the profile,
its schema version, and the source hash of each file the facts came from. This is
a different file from `repos/<repo-key>/repo.json` in the state root, which only
indexes this repository's Runs and holds no project facts. Also record `architectureMemoryPath` and
`runDocsRoot`.

### Where documents go

Two destinations, and using the wrong one breaks the read-only promise.

**Before approval**, every document is a Run artifact under
`<stateRoot>/runs/<run-id>/artifacts/`. Discovery, research, the specification,
and an audit report all live there. They are outside the user's repository, so
nothing in the primary checkout changes while the user is still deciding.

**After approval**, they are materialized into the repository inside the isolated
worktree, together with every other approved change.

`runDocsRoot` defaults to `docs/my-plan/`. Each Run owns one directory under it:

```text
<runDocsRoot>/runs/<run-id>-<slug>/
├── discovery.md
├── research.md
├── spec.md
├── plan.md
├── implementation.md
├── validation.md
├── review.md
├── audit.md
└── delivery.md
```

Every rendered document is a sibling inside that directory. That is what makes the
relative `records:` links in `spec.md` resolve, and what keeps Parallel Runs from
writing over each other.

Only phases that actually ran get a document. `research.md` exists only when
research happened, `audit.md` only for an Audit Run, and everything from
`implementation.md` onward only after approval. Never render an empty document to
complete a set.

When a stage says to render a document, its destination is
`<runDocsRoot>/runs/<run-id>-<slug>/<name>.md` in the worktree, or the Run
artifacts directory if approval has not happened yet. Do not invent a third path.

An Audit Run is read-only from start to finish: its report stays in Run artifacts
and reaches the repository only if the user accepts a scope and the work proceeds.

### Where these files go

| Invocation | Where |
|------------|-------|
| `/my-plan-install` in a repository | Materialize directly. The user asked for it |
| First `/my-plan-start` or `/my-plan-audit` in an uninitialized repository | Transient profile in Run state. Materialize files in the worktree after approval |

This keeps discovery read-only and the primary checkout clean.

## Part 3: Project Skill

One hidden skill per repository, at `.claude/skills/my-plan-project/`.

```text
.claude/skills/my-plan-project/
├── SKILL.md
├── project.json
└── references/              # only when needed
    └── <topic>.md
```

Render `SKILL.md` from `${CLAUDE_PLUGIN_ROOT}/internal/templates/project-skill.md.tpl`.
It is a short navigator, not a manual.

`references/` does not exist by default. Create a file there only when stack
rules, validation, tooling, architecture, or review guidance cannot be represented
by an existing canonical repository document or the Architecture Memory. Link the
repository's own documentation instead of copying it.

Never rewrite the installed plugin to specialize a repository. Never modify
`CLAUDE.md`, `AGENTS.md`, custom skills, or canonical documentation. On upgrade,
migrate the schema idempotently; when you find an edit you do not recognize, stop
for reconciliation rather than overwriting it.

Workspace Mode creates one independent Project Skill per child repository.

## Part 4: Architecture Memory

One file per repository. Default path `docs/my-plan/SEAM.md`. Adopt an equivalent
existing document if the repository already has one, and record the resolved path
as `architectureMemoryPath`.

Build it from a complete repository inspection and existing canonical
documentation. Populate it from verified evidence. A generic template filled with
plausible-sounding architecture is worse than an empty file, because later phases
will trust it.

Contains only durable current architecture:

- Purpose, stack, structure, build toolchain.
- Architectural principles, module boundaries, important patterns.
- Data flows, cross-component contracts, configuration, security, operational
  constraints.
- Canonical build, test, and deployment commands.
- Proven non-obvious pitfalls, each with the evidence that proved it.

Never contains: feature requirements, implementation steps, code listings,
changelog prose, review findings, task status, transcripts, or raw validation
evidence. Those belong to the specification, plan, Finding Ledger, or Run
artifacts.

Existing ADRs are evidence. Read them, carry their active consequences into the
Architecture Memory, and modify nothing. This product never generates ADRs.

### Compaction

Write densely from the first version: one authoritative definition per subject,
references instead of duplicated contracts, current facts instead of history.

After creation and after every architectural update, estimate the token count.
Character count divided by four is close enough to decide this; a calibrated
estimator would make the same call.

- At or below 20,000 tokens: do nothing. Compaction below the threshold is busywork.
- Above 20,000 tokens: compact inside the current Run, before delivery. Remove
  redundancy and obsolete history, increase density, group repetitive listings,
  replace duplication with references. Then remeasure.

Compaction must preserve: overview, stack and versions, directory structure,
architectural principles, patterns and their locations, data flows, contracts,
configuration requirements, and build and deployment commands.

There is no separate maintenance Run and no public compaction command.

A bug fix updates the Architecture Memory only when it changes architecture or
corrects an architectural fact.
