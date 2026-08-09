# Stage: Project

Environment setup, repository facts, the Project Skill, and the per-Run
Architecture Memory. Loaded
by `$my-plan:install`, and automatically by the other actions when setup is
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
| Codex CLI | `codex --version`, `codex exec --help`, `codex exec resume --help`, and `codex login status`; verify every flag named in `internal/codex.md` | Give the exact installation, upgrade, or login command for the platform |
| Git 2.28+ | `git --version`. 2.28 is the floor because `git init -b` needs it | Give the exact install command for their platform |

The parent session must expose structured user questions and native file and
shell tools. Discovery also needs a web research capability. Check the current
session rather than assuming a feature from the CLI version.

**Optional. Report and continue.**

| Capability | Probe | If missing |
|------------|-------|------------|
| Context7 | One real documentation query that returns content | Research falls back to web search |
| GitHub CLI | `gh --version` and `gh auth status` | Note it. Required only when an approved action needs GitHub itself, such as creating a remote. Existing remotes use Git directly |
| Playwright | `playwright --version`, then `playwright-cli --version`. Either counts | Recommend it for browser validation. Never block on it |

**Auxiliary tools are probed, used, and never required.** Record whatever this
session actually exposes — documentation MCPs such as Context7, code-navigation
or indexing MCPs such as Serena, LSP servers, the host's own search — and use
what passed wherever it beats raw reading: discovery, research, planning, and
review all navigate faster with an index than with grep. A missing tool changes
nothing but speed, and no phase may depend on one the Working Profile did not
verify.

Probe the flags from the help output rather than by running a real Codex turn: a
probe that costs a model call is a probe people learn to skip.

Report installed versions and whether authentication is ready. Never read, echo,
log, or store a secret value.

### Runtime

The only runtime is `codex-only`. Record it in `profile.json` and every
`run.json`. A failed required probe leaves setup incomplete with the exact reason;
it never selects another host or silently weakens a boundary.

### Model mapping

Use aliases and role names, and capability probes to resolve them. Never pin a
release-specific model ID; it will be wrong within months.

Two properties decide which tier holds which role. **Width** is how much a
Worker can hold at once, and it is what discovery, a whole-repository audit, and
a large diff need. **Depth** is how hard it reasons about a single tangled thing,
and it is what a plan, a product judgement, and a concurrency bug need. The tiers
are Luna, Terra, and Sol.

Every Worker also carries a reasoning effort. `high` is the working default
everywhere. `xhigh` and `max` are escalations spent on one hard problem, not a
setting to leave on.

| Role | Runs at | Escalation |
|------|---------|------------|
| Discovery | Two Terra Workers over disjoint partitions, `high` | More Terra partitions; `xhigh` for one hard question |
| Findings review | Sol, `xhigh` | Nothing above it; falls to Luna only where no partition ran on it |
| Plan creation | Sol, `high` | Sol `xhigh`, then `max` for a critical irreversible plan |
| Plan review | Terra, `high` | A fresh Terra session at `xhigh`; never Sol, which wrote the plan |
| Implementation, tests, remediation | Terra, `high` | Terra `xhigh`, then `max`; never Sol, which reviews the code |
| Technical code review | Sol, `high` | A fresh Sol session at `xhigh` |
| Product review | Sol, `high`, in a session that saw no implementation | A fresh Sol session at `xhigh` |
| QA gate | Sol, `high`, in a session of its own | A fresh Sol session at `xhigh` |
| Audit, where no Worker wrote the subject | Terra, `high` | More Terra partitions, then Terra `xhigh` |
| Commit | Terra, `high` | Nothing above it: it writes no code and reviews nothing |

Luna at `high` replaces Terra for implementation when the plan leaves nothing to
decide: a rename, a CRUD endpoint, a repeated test, a type fix. Luna at `medium`
only when the change is mechanical outright. A task that needs a judgement call
is not a Luna task, and downgrading one to save tokens buys another review round.

### Fallback chains

Escalation answers a hard subject. This answers an unavailable one. Every role has
an ordered list of candidates, so a tier that is offline, out of quota, past a
usage cap, or withdrawn moves the role along instead of ending the Run.

| Role | 1 | 2 | 3 |
|------|---|---|---|
| Discovery | `terra@high` | `luna@high` | `sol@high` |
| Findings review | `sol@xhigh` | `luna@high` | — |
| Plan creation | `sol@high` | `terra@high` | `luna@high` |
| Plan review | `terra@high` | `luna@high` | `sol@high` |
| Implementation | `terra@high` | `luna@high` | `sol@high` |
| Technical code review | `sol@high` | `luna@high` | `terra@high` |
| Product review | `sol@high` | `luna@high` | `terra@high` |
| QA gate | `sol@high` | `luna@high` | `terra@high` |
| Audit | `terra@high` | `sol@high` | `luna@high` |
| Commit | `terra@high` | `luna@high` | `sol@high` |

**A chain is a list of candidates, not a list of instructions.** With three tiers
and ten roles, the writer's tier is always somewhere on the reviewer's chain. A
chain walked blindly therefore ends with one tier on both sides of a review, and
the check that was supposed to catch the defect becomes the model agreeing with
itself. Before taking a candidate, compare it against the tier already bound to
the opposing role in this Run. If they match, skip it and take the next. That
tier lives in `run.json`'s `roleBindings`, and after a session rotation it is the
only place it exists — a rule that depends on remembering what this session
dispatched is not a rule a resumed Run can keep.

**A chain ends. It never wraps.** Three tiers is a short ladder, and after the
skip rule some roles have one real alternate. When the candidates run out, the Run
is `BLOCKED` and names the role and the reason. A Run that stops honestly costs a
re-run; one that quietly reviews its own work costs whatever shipped.

**Effort is not a chain step.** Sol at `high` failing on quota does not become Sol
at `xhigh`: same account, same limit, same failure one second later. Raising
effort is a response to a hard subject and never to an unreachable tier. That is
why this table moves sideways between tiers while the Escalation column above
moves up within one.

**Advancing is sticky and recorded.** Once a role moves along its chain it stays
there for the Run. Record phase, role, error class, the candidate that failed, the
one that took over, and the time, in `implementation.md`. A later Run starts from
the top again.

What advances a chain, and what does not:

| Signal | Response |
|--------|----------|
| Offline, unauthenticated, quota, usage cap, credits exhausted, tier withdrawn or answering with an unavailability notice | Advance immediately. No retry: the next attempt fails the same way |
| Network or provider error, transport failure | One bounded retry, then advance |
| Contract violation, invalid JSON, schema mismatch | A failed attempt against the same candidate, not a reason to advance. Never an implicit approval |
| The Worker did the work and returned a bad result | Not a fallback at all. That is remediation, and it stays with the role that owns it |

That last row is the one worth stating: a model returning nonsense is not a model
being unavailable, and treating it as one hides a quality problem behind an
infrastructure story while quietly demoting the role.

Two role names that resolve to the same model ID are one model, not two. If a
user's configuration collapses Terra and Sol that way, setup may complete its
read-only inventory but `$my-plan:start` blocks before planning. Record the
collision beside the resolved IDs and ask for a distinct mapping.

Escalation is not the only move up. Discovery and technical review can also be
split across parallel Workers that each own one area or one lens; `discovery-spec.md`
and `review.md` say when that beats a single deeper Worker.

A configured user override wins over all of this. Show the effective mapping at
setup and at the start of each Run.

The model that wrote the plan does not review the plan, and the model that wrote
code does not review that code. If an unavailable model or exhausted quota leaves
only one side of either pair, persist the Run and block.

### Read-only boundary

Discovery, plan creation, plan review, code review, and audit always start with
`--sandbox read-only`. The process boundary prevents writes even when a prompt
is wrong; the planner returns the plan as content and the Coordinator writes
the files. Implementation, the QA gate, and the commit use
`--sandbox workspace-write` inside the worktree execution created, bounded by
the handoff write set and verified against Git by the Coordinator.

### Autonomous sessions

Explain the fixed child-session sandboxes and keep the parent session's current
permission profile. Never broaden it merely to reduce routine prompts.

Unrestricted bypass is an advanced explicit opt-in with the host's own safety
warning. Never enable it silently or through repository configuration.

### State root

`~/.codex/plugins/data/my-plan-my-plan/`, on Windows
`%USERPROFILE%\.codex\plugins\data\my-plan-my-plan\`. Create it if it does not
exist yet; the host does not create it for you.

That is the host's per-plugin data directory, and it survives plugin updates,
which is exactly what Run state and worktrees need.

Use the literal path. Hook-only environment variables are not guaranteed in the
session running these instructions; two sessions that substitute guesses can end
up with different state roots and cannot resume each other's Runs.

Never put state under `<pluginRoot>`. That path is the installed plugin
copy and it changes on every update, so anything written there is lost the first
time the user upgrades.

Record the resolved path in the Working Profile so later Runs read it rather than
deriving it again.

Allow an explicit override, and offer one when the default would produce long
worktree paths. Windows path limits are a real constraint on deep worktrees, not
a theoretical one.

A state root you cannot create or write is a blocked setup, not a decision
point. Stop and report the exact denied path and the permission that would
unblock it. Never substitute a location of your own: an override is the user's
to give, and two sessions that each improvise a fallback end up with different
roots and cannot resume each other's Runs.

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
| Plan hash | `plan.md`'s exact bytes, then every task file's exact bytes in ascending filename order, one SHA-256 over the concatenation. The plan and its task files are one subject; `taskFiles` additionally records each file's own hash so an edit is located per file |
| Review Subject hash | The output of `git diff <baseSha>` restricted to the approved write set |
| Delivered subject hash | `git diff <integrationBase> <finalSha>` under the same restriction: the committed form of the Review Subject, recorded at completion. The integration base is `<baseSha>` until a rebase moves it; after one it is the SHA the branch was replayed onto, because a diff from the original base would hash upstream work the Run never wrote |
| Snapshot hash, when no diff exists (audit) | `git rev-parse HEAD^{tree}` |

`git diff` does not see untracked files. Before computing any Review Subject
hash, run `git add -N` over every Run-owned path; a hash computed while part of
the subject is untracked covers less than it claims, verifies cleanly in the
moment, and can never be reproduced once the files are staged. The working-tree
form is index-dependent either way, which is why completion also records the
delivered form: it is the one a reader can still recompute after the worktree is
gone. Recompute means byte-identical, and `git diff` output depends on reader
configuration — `diff.noprefix`, `diff.algorithm`, rename detection, external
drivers — so both the computation and any later verification use the pinned
invocation below, never a bare `git diff`.

Compute them. Never write a hash you did not run a command to get.

```sh
# a file
shasum -a 256 <path> | cut -c1-64          # macOS and Linux
sha256sum <path> | cut -c1-64              # Linux, if shasum is absent
# a diff — pinned so any session, any gitconfig, recomputes identical bytes
git -c diff.noprefix=false -c diff.mnemonicPrefix=false -c diff.algorithm=myers \
  diff --no-color --no-ext-diff --no-textconv --no-renames \
  <baseSha> [<finalSha>] -- <paths> | shasum -a 256 | cut -c1-64
# a tree, when no diff exists
git rev-parse HEAD^{tree}
```

On Windows: `(Get-FileHash <path> -Algorithm SHA256).Hash.ToLower()`.

This matters more than it looks. Every artifact carries a hash, nothing in the
flow forces you to compute one, and inventing a plausible hex string is the path
of least resistance under time pressure. A fabricated hash passes every check in
this product, because the only thing that verifies it is a comparison against
another value from the same source. Then approval binds to nothing.

A reviewer must be able to recompute the hash it was handed and get the same
string. If you cannot run the command, say so and stop; do not supply a
placeholder.

### findings.json

The Finding Ledger. Every finding from every review round in this Run, keyed by
task plus finding id so parallel tasks cannot collide.

```json
{
  "schemaVersion": 1,
  "findings": [
    {
      "key": "T-02/unvalidated-order-id",
      "taskId": "T-02",
      "id": "unvalidated-order-id",
      "severity": "blocker",
      "lens": "correctness",
      "title": "markPaid throws on an unknown id",
      "evidence": "src/orders.js:18 reads o.status on an undefined order",
      "correction": "Return undefined for an unknown id and let the caller decide",
      "disposition": "resolved",
      "reason": null,
      "openedAt": "20260731-a617-reviewer-2",
      "closedAt": "20260731-a617-reviewer-3"
    }
  ]
}
```

`disposition` is `open`, `resolved`, `not-reproducible`, `accepted`, or
`blocked-by-owner`. `reason` is required for the last three and for any finding
the writer pushed back on, so a disagreement stays visible instead of vanishing.

Carry `title`, `evidence`, and `correction` across from the review result
verbatim. A ledger entry that keeps only an id and a severity is unreadable
weeks later, and `review.md` is rendered from this file: whatever is missing here
is missing from the record the user reads.

### run.json

The Run manifest. Resume reads this and nothing else to work out where a Run
stopped, so its shape cannot be left to whoever writes it first.

```json
{
  "schemaVersion": 2,
  "manifestRevision": 7,
  "runId": "20260731-7c41",
  "slug": "add-input-validation",
  "goal": "add input validation to the task API",
  "mode": "repository",
  "runtime": "codex-only",
  "phase": "implementation",
  "status": "active",
  "repoKey": "task-api-75d0b10a",
  "repoPath": "/abs/path/to/repo",
  "defaultBranch": "main",
  "baseSha": "ba62788...",
  "branch": "my-plan/20260731-7c41",
  "worktree": "/abs/path/to/worktree",
  "tasksDir": "docs/tasks",
  "taskFiles": [
    { "path": "docs/tasks/T-03-validate-order-id.md", "sha256": "9f2c..." }
  ],
  "pendingApproval": null,
  "approvedSpecHash": "sha256:...",
  "planHash": "sha256:...",
  "reviewSubjectHash": null,
  "currentTaskId": "T-03",
  "completedTaskIds": ["T-01", "T-02"],
  "roleBindings": {
    "implementation": {
      "candidate": "luna@high",
      "position": 2,
      "since": "2026-07-31T14:02:11Z",
      "reason": "terra@high classified as usage cap"
    },
    "technicalCodeReview": {
      "candidate": "sol@high",
      "position": 1,
      "since": "2026-07-31T13:40:02Z",
      "reason": "first choice"
    }
  }
}
```

`phase` is one of `discovery`, `spec`, `planning`, `planned`, `implementation`,
`validation`, `review`, `delivery`. `planned` is the boundary between the two
commands: `$my-plan:start` ends there, and `$my-plan:exec` begins there.

`status` is one of `active`, `blocked`, `cancelled`, `done`, `done_local`,
`ready_for_deploy`. It is never absent: a Run with no status cannot be resumed or
reported on, and every Run has one from the moment it is created.

`cancelled` is the terminal state for a Run the user decides never to execute.
Either command, asked to cancel, sets it, deletes the Run's task files from the
repository's task directory, and purges the Run's state directory, leaving only
the entry this writes to `repos/<repo-key>/repo.json`. A Run that execution has
already entered gets its worktree and branch removed first, under
`implementation.md`'s removal protocol — from the main checkout, never forcing
past a dirty status; a dirty worktree blocks the cancellation instead of
deleting unassessed work. Without a terminal state an abandoned plan reappears
in every future selection, forever.

`baseSha`, `branch`, and `worktree` are null until `$my-plan:exec` creates the
worktree. A `planned` Run has no branch and no worktree anywhere; a resumed
session must not treat those nulls as corruption. Once execution creates the
worktree it writes all three in the same manifest update, immediately, before
anything else happens — a crash between creation and that write is otherwise
indistinguishable from a Run that never entered execution.

`tasksDir` is where the Run's task files live in the repository, `docs/tasks`
unless the user overrode it. `taskFiles` records the path and content SHA-256 of
every task file this Run owns there. It is what detects a user edit between
planning and execution, per file, and it shrinks as execution deletes completed
tasks.

`mode` is `repository`, `workspace`, or `greenfield`. In Workspace Mode add a
`repositories` array carrying the per-repository fields.

`schemaVersion` 2 is the current form. A `run.json` still at 1 is the earlier
dossier format: neither command resumes it until the migration in Part 5
upgrades it.

`manifestRevision` increments on every write. Two sessions writing the same Run
detect the conflict by comparing it.

`roleBindings` records which candidate each role is actually running on, and it
is not bookkeeping. Two things depend on it and neither survives without it.

Chain advances are sticky for the Run. `implementation.md` narrates them, but a
rendered document is not resumable state, and resume reads this manifest and
nothing else. Without `roleBindings`, a Run resumed after falling back restarts
every role at candidate one and walks straight back into the quota wall that
moved it.

The second reason is the one that matters. The skip rule compares a candidate
against the tier already bound to the opposing role in this Run — that tier is
exactly what `roleBindings` holds. A session that cannot read it cannot apply the
rule, so a resumed Run would be free to hand the reviewer the tier that wrote the
code, silently, having passed every check. With three tiers the collision is not
a remote possibility; it is what happens by default once a chain has moved.

Write the binding when a role first resolves, not only when it falls back:
`position: 1` is a binding too, and a resumed session needs the writer's tier
whether or not anything failed. Bindings never reset mid-Run. A new Run starts
empty and resolves from the top of each chain.

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
- Existing agent instruction files, ADRs, and canonical documentation.
- Deployment configuration, if any.

Ask only what the repository cannot answer: delivery constraints, a genuinely
ambiguous validation command, or a preference between two equally valid options.

Record in the Project Skill's `project.json`, inside the repository: the profile,
its schema version, and the source hash of each file the facts came from. This is
a different file from `repos/<repo-key>/repo.json` in the state root, which only
indexes this repository's Runs and holds no project facts. Also record `tasksDir`
when the user overrides the default `docs/tasks/`.

### Where documents go

Three destinations, each with a different lifetime, and using the wrong one
breaks a promise.

**Working documents live in Run state and die with the Run.** Discovery,
research, the specification, the plan, the Architecture Memory, an audit report,
and every evidence record — implementation, validation, review, delivery — are
rendered under `<stateRoot>/runs/<run-id>/artifacts/`. They are outside the
user's repository, so nothing in the checkout changes while the user is
deciding, and they are volatile: completion or cancellation purges the whole
directory. The permanent record of what a Run did is the changelog entry it
shipped, not its paperwork. Every rendered document is a sibling inside that
one directory — that is what makes the relative `records:` links in `spec.md`
resolve, and what keeps Parallel Runs from writing over each other.

**Task files live in the repository and die one by one.** After spec approval,
planning writes one file per task under `<tasksDir>` — `docs/tasks/` by default
— in the primary checkout, the one place this product writes outside a
worktree. They are working state made visible: the user can read and edit them
between planning and execution, execution deletes each one as its task
completes, and they are never staged and never committed.

The repository-side structure is host-neutral and identical across both
distributions of My Plan: the same task directory, the same task file format,
the same changelog. Either host — or a human — reads the same board. Run state
stays with the host that planned the Run, because the approval and its hashes
live there, so a board is executed by the host that planned it.

**The changelog lives in the repository and stays.** Written inside the
worktree during delivery, part of the Review Subject, committed with the work.
`docs/CHANGELOG.md` when the repository has no changelog convention of its own;
an existing convention wins.

When a stage says to render a document, its destination is
`<stateRoot>/runs/<run-id>/artifacts/<name>.md`. Do not invent another path.

Only phases that actually ran get a document. `research.md` exists only when
research happened, `audit.md` only for an Audit Run, and everything from
`implementation.md` onward only during execution. Never render an empty
document to complete a set.

An Audit Run is read-only from start to finish: its report stays in Run
artifacts and reaches the repository only if the user accepts a scope and the
work proceeds through planning and execution.

### Where these files go

| Invocation | Where |
|------------|-------|
| `$my-plan:install` in a repository | Materialize directly. The user asked for it |
| First `$my-plan:start` or `$my-plan:audit` in an uninitialized repository | Transient profile in Run state, for this Run's own use. Nothing is materialized into the repository; `$my-plan:install` is how project files come to exist |

This keeps discovery read-only, the primary checkout clean, and project files a
decision the user makes rather than a side effect of running a Run.

## Part 3: Project Skill

One hidden skill per repository, at `.agents/skills/my-plan-project/`.

```text
.agents/skills/my-plan-project/
├── SKILL.md
├── agents/openai.yaml
├── project.json
└── references/              # only when needed
    └── <topic>.md
```

Render `SKILL.md` from `<pluginRoot>/internal/templates/project-skill.md.tpl`.
Render `agents/openai.yaml` from
`<pluginRoot>/internal/templates/project-skill-openai.yaml.tpl`. The policy keeps
the repository skill path-only rather than implicitly injecting it into every
turn. `SKILL.md` is a short navigator, not a manual.

`references/` does not exist by default. Create a file there only when stack
rules, validation, tooling, architecture, or review guidance cannot be represented
by an existing canonical repository document or the Architecture Memory. Link the
repository's own documentation instead of copying it.

Never rewrite the installed plugin to specialize a repository. Never modify
existing agent instructions, custom skills, or canonical documentation. On
upgrade, migrate the schema idempotently; when you find an edit you do not
recognize, stop for reconciliation rather than overwriting it.

Workspace Mode creates one independent Project Skill per child repository.

## Part 4: Architecture Memory

One document per Run, at `<stateRoot>/runs/<run-id>/artifacts/architecture.md`.
It is volatile: discovery builds it, every later phase of the same Run reads it,
and completion purges it with the rest of the Run's artifacts. The next Run's
discovery builds its own from the repository as it stands then. The repository
itself is the memory; this document is one Run's verified reading of it, kept
exactly as long as the Run needs it.

Build it from a complete repository inspection and existing canonical
documentation — an `ARCHITECTURE.md` or equivalent the repository already
maintains is evidence to read, never a file to adopt or modify. Populate it from
verified evidence. A generic template filled with plausible-sounding
architecture is worse than an empty file, because later phases of this Run will
trust it.

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

Write densely from the first version: one authoritative definition per subject,
references instead of duplicated contracts, current facts instead of history.
If it grows past roughly 20,000 tokens — character count divided by four is
close enough — compact it before planning reads it: remove redundancy, increase
density, replace duplication with references. A memory nobody can afford to
load serves nobody, and this document has no later Run to be compacted for.

## Part 5: Migration from the dossier format

Earlier versions of this plugin committed a Run Dossier under `docs/my-plan/`,
kept a persistent Architecture Memory at `docs/my-plan/SEAM.md`, ran one
command from goal to push, and wrote `run.json` at `schemaVersion` 1 with
`runDocsRoot` and no task files. This section upgrades all of it. It runs when
`$my-plan:install migrate` is invoked, and setup enters it by itself when any signal below
is present, whatever mode was asked for — an installed repository is never left
half-migrated in silence, and re-running install on an installed repository is
always safe: it verifies, repairs, and upgrades; it never restarts.

Signals of the earlier format:

| Signal | Where |
|--------|-------|
| `docs/my-plan/` exists | the repository |
| `project.json` records `runDocsRoot` or `architectureMemoryPath` | Project Skill |
| A `run.json` at `schemaVersion` 1, or carrying `runDocsRoot` | state root |
| A Project Skill pointing at a persistent Architecture Memory | Project Skill |

What migration does, in order:

1. **Upgrade the plugin-owned state.** Rewrite every `run.json` to
   `schemaVersion` 2: drop `runDocsRoot`, add `tasksDir` and an empty
   `taskFiles`, keep every other field. Re-render the Project Skill from the
   current templates and drop `runDocsRoot` and `architectureMemoryPath` from
   `project.json` — preserving any edit you do not recognize by stopping for
   reconciliation, never by overwriting. Re-probe capabilities: Context7 is no
   longer required, and the auxiliary-tool inventory is new. These files are
   the plugin's own; no confirmation is needed.

2. **Offer, never seize, the legacy repository files.** `docs/my-plan/` — the
   dossiers and `SEAM.md` — is tracked history the new format no longer reads
   or maintains. List what is there and ask once: delete from the working
   tree, or keep. Deletion is a working-tree edit the user commits themselves;
   migration never commits, never pushes, and never rewrites history. While a
   legacy `SEAM.md` remains, discovery reads it as evidence like any other
   repository document, so keeping it breaks nothing — it is simply no longer
   written to.

3. **Triage unfinished Runs, one by one.** For every `run.json` with status
   `active` or `blocked`:
   - Pre-approval phases (`discovery`, `spec`): the schema upgrade above is
     enough, and `$my-plan:start` resumes them normally.
   - Post-approval phases: the old approval froze a write set that includes
     dossier paths the new format forbids, so the Run cannot be re-bound
     silently. Present three options and take the user's choice per Run.
     **Convert**: revise the specification only by removing the paperwork
     entries from its write set, take one ordinary approval of that revision —
     a revision is exactly what re-approval exists for — re-plan the remaining
     work into task files, and keep the branch, the worktree, and every
     commit, so execution resumes where the work stopped. **Cancel**: the
     `cancelled` path, worktree removal protocol included. **Leave blocked**:
     nothing is touched and the Run waits.

4. **Report.** What was upgraded, what was deleted or kept, and each Run's
   disposition. Migration is idempotent and resumable: run it again and it
   finds nothing left to do, or continues where it stopped.
