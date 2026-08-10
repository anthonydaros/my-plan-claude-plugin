# AGENTS.md

Guidance for Codex when working in this repository.

## What this repository is

The source of **My Plan**, shipped as two independent, installable plugins
that carry one approved specification through discovery, planning, isolated
implementation, validation, independent review, and delivery — split into two
commands: `start` plans (docs-only, ends at a reviewed task board in
`docs/tasks/`) and `exec` executes it.

- `plugin/` is the Claude Code distribution. `CLAUDE.md` is its authoritative
  guidance — it exists locally but is gitignored, so it is not on GitHub;
  read it directly from disk before touching anything under `plugin/`.
- `codex-plugin/` is the Codex-only distribution: no Claude Code dependency,
  runtime fixed to `codex-only`, model roles named `Sol`/`Terra`/`Luna`
  instead of Claude model families. This file is its authoritative guidance.

Neither distribution depends on the other, and neither can resume a Run the
other started. They do share a body of host-neutral assets byte-for-byte —
smoke-checked, not just conventionally kept in sync:
`internal/checklists/`, `internal/contracts/*.schema.json`,
`internal/prompts/*.tpl`, `internal/templates/documents/*.tpl`, and
`internal/references/`. Edit one of these under either distribution and mirror
the edit into the other in the same change, or the parity check in
`tests/smoke-posix.sh` fails the build.

There is no code. Both plugins are **static by contract**: prose instructions,
frontmatter, JSON schemas, and templates. Nothing is compiled, bundled, or
installed. Changing behavior means editing instructions, and the only way to
verify a change is to read it and run the smoke checks.

## Commands

```sh
sh tests/smoke-posix.sh          # all static checks, both distributions, one pass
pwsh ./tests/smoke-windows.ps1   # Windows-only: paths and manifests under PowerShell
claude plugin validate ./plugin  # Claude Code manifest shape; no Codex equivalent
```

`codex plugin --help` only exposes `add`/`list`/`marketplace`/`remove` — there
is no `codex plugin validate`. `smoke-posix.sh` is what checks
`codex-plugin/.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json`
for the Codex side; the host itself is only ever exercised by actually
installing the plugin.

`smoke-posix.sh` runs every check in one pass and prints `ok`/`FAIL` per line.
There is no way to select one check; to isolate a failure, run the script and
read the labelled line. It needs `python3` (or `node`) for JSON parsing and
`python3` for the contract strict-mode check, and skips those checks silently
when neither is present.

CI runs `smoke-posix.sh` on Linux and macOS, `smoke-windows.ps1` on Windows,
and `claude plugin validate` on Linux.

## Layout: `codex-plugin/`

| Path | Role |
|------|------|
| `skills/*/SKILL.md` + `skills/*/agents/openai.yaml` | The four public commands (`install`, `start`, `audit`, `exec`). `SKILL.md` frontmatter carries only `name` and `description`; `openai.yaml` carries `allow_implicit_invocation: false` and the invocation string |
| `internal/stages/*.md` | Coordinator instructions, one per phase, loaded lazily via `<pluginRoot>` |
| `internal/prompts/*.tpl` | Worker instructions, shared with `plugin/` |
| `internal/contracts/*.schema.json` | Result schemas every Worker output must match, shared with `plugin/` |
| `internal/templates/documents/*.tpl` | Run Dossier documents, shared with `plugin/` |
| `internal/templates/project-skill-openai.yaml.tpl` | Renders the per-repository Project Skill's `agents/openai.yaml` — Codex-only, `plugin/` has no equivalent |
| `internal/codex.md` | How the Coordinator, itself a Codex session, dispatches bounded child Codex sessions as Workers |
| `internal/checklists/review.md` | The eleven review lenses, shared with `plugin/` |
| `.codex-plugin/plugin.json` | The manifest: `"skills": "./skills/"`, no `mcpServers`, no `hooks` |

`codex-plugin` installs no `agents/` directory at its root. Unlike `plugin/`,
which dispatches named Claude subagents from files, every Codex Worker is a
child Codex session the Coordinator starts and resumes itself with
`codex exec`, per `internal/codex.md`.

`skills/start/SKILL.md` and `skills/exec/SKILL.md` are the two Coordinator
entry points, on the same split as `plugin/`: `start` plans and `exec`
executes, and neither may load the other's stages.

## How the pieces connect

The Coordinator — the interactive Codex session the user is talking to —
never writes code and never gives a review verdict. It dispatches Workers as
**child Codex sessions** via `codex exec`, each given a **handoff JSON**
(`contracts/handoff.schema.json`) naming the worktree, task IDs, write set,
artifact paths, and hashes, and each returning a contract-shaped result
through `--output-schema` that the Coordinator validates before trusting it.

Never concatenate a document into a prompt. Pass the handoff path.

## Invariants the smoke tests enforce for `codex-plugin/`

Each of these is a failure the product exists to prevent, checked because a
prose edit could silently undo it.

- **The writer is never the reviewer.** Planning uses Sol and its review uses
  Terra; implementation uses Terra and its review uses Sol. `Sol` and `Terra`
  must resolve to different model IDs — setup blocks when a user's Codex
  configuration collapses them into one.
- **A fallback chain never wraps into reusing the writer.** Every role has an
  ordered list of candidate tiers for when one is offline or over quota; the
  chain compares a candidate against whatever tier is already bound to the
  *opposing* role for this Run (`run.json`'s `roleBindings`) and skips it on a
  match. When candidates run out, the Run blocks — it never silently lets one
  tier review its own work.
- **The three dispatched gates verify, they do not trust.** The commit
  Worker's claim of touching no remote ref is checked with
  `git for-each-ref refs/remotes`, not believed from its result; the secret
  scan stays the Coordinator's own, never delegated to the committer; QA runs
  in a session that did not write the code.
- **The public skills are manual-only with minimal frontmatter.** `SKILL.md`
  frontmatter is exactly `name` and `description`; the invocation policy
  lives in the sibling `agents/openai.yaml`, not in `SKILL.md`.
- **The Codex plugin stays host-neutral.** No mention of Claude, Sonnet,
  Opus, or `hybrid` anywhere under `codex-plugin/` — those are `plugin/`
  concepts, and their presence here means a Claude-side sentence leaked
  across during an edit meant to land in both.
- **The installed plugin stays static.** No `package.json`, `*.js`, `*.ts`,
  `*.py`, `*.sh`, `hooks.json`, `.mcp.json`, or `node_modules` anywhere under
  `codex-plugin/`.
- **Every `<pluginRoot>/...` reference resolves**, the same rule as
  `${CLAUDE_PLUGIN_ROOT}/...` on the Claude side. Adding a reference means
  adding the file.
- **`start` never loads `stages/implementation.md`**; `exec` must. A `start`
  that references it has silently regained the whole pipeline.
- **The push gate and the secret scan survive edits**, mirrored
  sentence-for-sentence against the Claude side, in `skills/exec/SKILL.md`,
  `skills/start/SKILL.md`, and `stages/implementation.md`.
- **Task files are never staged and never committed.** They live in
  `docs/tasks/` in the primary checkout between planning and execution, and
  execution deletes each one as its task completes.
- **`exec` never re-asks for approval.** The authority is `approvedSpecHash`;
  the `start`/`exec` boundary is a control point, not a third gate.
- **The migration path survives** for repositories initialized by the earlier
  dossier-format versions (`docs/my-plan/`, `run.json` at `schemaVersion` 1).
- **No literal `Co-Authored-By:` trailer anywhere in `codex-plugin/`.**
  Commits this plugin writes belong to the user.

Run `sh tests/smoke-posix.sh` after touching anything in `codex-plugin/` — it
checks both distributions in one pass and names the exact failing line.

## Contract schemas: strict mode

Shared with `plugin/`, so a violation here breaks `--output-schema` for both
distributions identically. It is enforced by the provider before the model
runs, and it rejects the whole request with HTTP 400. Two rules:

1. Every property needs an explicit `"type"`. `{"const": 1}` fails; write
   `{"type": "integer", "const": 1}`.
2. `"required"` must list **every** key in `"properties"`, at every nesting
   level. A field that may be absent is nullable —
   `{"type": ["string", "null"]}` — and still appears in `required`.

Run the smoke tests after touching anything in `internal/contracts/`.

## Terminology: the repository renamed itself

`docs/` and `CONTEXT.md` are gitignored local design context and still use
the project's original name — **SpecSeam**, `specseam`. The shipped plugins
are **My Plan**. `docs/specs/specseam-v1.md` remains authoritative on
*behavior* and stale on *naming*; translate the names when porting anything
from it, into either distribution. A smoke check fails the build if the
string `specseam` appears anywhere under `codex-plugin/` (and separately,
under `plugin/`).

## The two user gates

Identical across both distributions, so an edit that blurs either one is a
defect regardless of which plugin it lands in:

1. **Spec approval.** Authorizes everything up to and including *local*
   commits, across both commands: `start` spends it on the task files, `exec`
   on everything else. The approval lives in `approvedSpecHash`, not in the
   conversation — never re-ask inside that authority.
2. **The push gate.** Nothing leaves the machine without a second explicit
   approval. Not a branch, not a tag, not "just the docs". A Run that ends
   unpushed is complete, not failed.

## Writing style

The same rule the plugin instructions themselves prescribe: one authoritative
statement per fact, current state rather than history, reference by path
instead of copying. A shared asset copied instead of referenced is exactly
the kind of duplication `tests/smoke-posix.sh`'s parity check exists to catch.

Commit subjects state the point of the change in a sentence. Bodies explain in
prose what was wrong and why the fix has the shape it does. This repository's
commits carry no trailers.
