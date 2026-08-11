# AGENTS.md

Guidance for Codex when working in this repository.

## What this repository is

The source of **My Plan**, nine independent Claude Code / Codex CLI skills —
`map`, `spec`, `plan`, `review-plan`, `implement`, `review`, `validate`,
`commit`, `cleanup` — each invoked manually, one at a time, whenever the
user wants.
There is no orchestration between them: no Coordinator, no Worker dispatch
protocol, no persistent Run state machine. Running `spec` and then `plan`
is a user decision, not a phase transition the plugin enforces. The
filesystem is the only state that survives between invocations: `docs/map.md`,
`docs/brief.md`, `docs/plan.md`, and `docs/tasks/*.md` are ordinary,
user-editable files, not a generated dossier owned by the plugin.

`CLAUDE.md` covers the same ground for Claude Code — it exists locally but
is gitignored, so it is not on GitHub; read it directly from disk before
touching anything under `plugin/`. This file is this repository's
authoritative guidance on GitHub.

There is no code. The plugin is **static by contract**: prose instructions,
frontmatter, and templates. Nothing is compiled, bundled, or installed.
Changing behavior means editing instructions, and the only way to verify a
change is to read it and run the smoke checks.

`plugin/` is what users install; everything else is development scaffolding.
It carries both host manifests over one shared body of skills — there used
to be a second, mirrored `codex-plugin/` tree; it's gone, folded into
`plugin/.codex-plugin/` alongside Claude's `plugin/.claude-plugin/`, because
maintaining two 90%-identical trees cost more than the one real difference
between the hosts was worth.

## Commands

```sh
sh tests/smoke-posix.sh          # all static checks, one pass
pwsh ./tests/smoke-windows.ps1   # Windows-only: paths and manifests under PowerShell
claude plugin validate ./plugin  # Claude Code manifest shape
claude plugin validate .         # marketplace manifest
```

`codex plugin --help` only exposes `add`/`list`/`marketplace`/`remove` —
there's no `codex plugin validate`. `smoke-posix.sh` is what checks
`plugin/.codex-plugin/plugin.json` and `.agents/plugins/marketplace.json`
statically; CI additionally exercises a real Codex CLI marketplace install
against this repository.

`smoke-posix.sh` runs every check in one pass and prints `ok`/`FAIL` per
line. There's no way to select one check; to isolate a failure, run the
script and read the labelled line.

## Layout

| Path | Role |
|------|------|
| `plugin/skills/*/SKILL.md` | The nine public skills. Manual-only, one body read by both hosts |
| `plugin/skills/*/agents/openai.yaml` | Codex-only sidecar: `allow_implicit_invocation: false`, the skill's `$my-plan:<name>` invocation string, display metadata. No `model`/`tools` field — Codex has no subagent-with-model primitive |
| `plugin/agents/my-plan-reviewer.md`, `my-plan-committer.md` | Claude-only native subagents. Codex CLI has no equivalent dispatch mechanism — see "Independence" below |
| `plugin/knowledge/checklists/*.md` | The eleven-lens review checklist, the architecture/overengineering checklist, the implementation defect catalogue, and cleanup's dead-code/residue/doc-drift/opt-in-refactor checklists |
| `plugin/knowledge/references/**` | 34 vendored, MIT-licensed language and cross-cutting review guides, attributed in `NOTICE.md` |
| `plugin/knowledge/templates/*.md` | Lean document shapes: `brief.md`, `plan.md`, `task.md`, `report.md` |
| `plugin/.codex-plugin/plugin.json` | The Codex manifest: `"skills": "./skills/"`, no `mcpServers`, no `hooks`. Claude Code's manifest sits beside it at `plugin/.claude-plugin/plugin.json` |

## The shared skill body

Every `SKILL.md` is read as-is by both hosts — no build step, no per-host
copy. Codex CLI's own SKILL.md convention only documents `name` and
`description` in frontmatter; the shared body also carries `argument-hint`
and `disable-model-invocation: true` for Claude Code's benefit, and Codex
tolerates the extra keys silently (verified empirically with a real
`codex exec` run, not assumed). Codex's own manual-only enforcement lives
in the sidecar `agents/openai.yaml`, not in the shared frontmatter.

Claude Code substitutes `$ARGUMENTS` natively; Codex CLI does not, so every
skill body says explicitly to take the text after `$my-plan:<name>` in the
user's message instead — both sentences are in every skill on purpose,
since the file doesn't know which host loaded it.

No `${CLAUDE_PLUGIN_ROOT}` and no `<pluginRoot>` anywhere. Every reference
to `knowledge/` or `agents/` inside a `SKILL.md` is a path relative to that
file's own location, which resolves identically under either host.

## Independence, and where it's real

`review`, `review-plan`, `validate`, `commit`, and `cleanup` each state two
independence mechanisms. In Claude Code, dispatching to
`agents/my-plan-reviewer.md` or
`agents/my-plan-committer.md` is a real tool boundary: neither subagent
holds `Write`, `Edit`, or `NotebookEdit`. In Codex CLI there is no
subagent-dispatch primitive to hang that on, so the guarantee degrades to a
self-declaration: if the session's own context shows it authored what it's
about to judge, it says so instead of claiming independence it doesn't
have. This is a real, stated asymmetry between the two hosts, not an
oversight — don't try to paper over it by inventing a fake Codex dispatch
mechanism.

## Guarantees worth keeping without a state machine

An earlier version of this plugin enforced these through a Run manifest, a
handoff contract, and a Coordinator that verified every Worker's claim.
None of that exists anymore. What survives, checked by `tests/smoke-posix.sh`
where it can be:

- Reviewers and the committer hold no file-editing tool.
- The secret scan in `skills/commit/SKILL.md` — `.env`/`*.pem`/`AKIA`/
  `ghp_`/`sk-` patterns, plus reading staged *prose*, not only code.
- No push skill exists. `commit` never pushes and prints the exact
  `git push` command instead — dropping automation here made the guarantee
  stronger, not weaker, since a skill that doesn't exist can't drift into
  pushing.
- Declared blindness: `review`, `validate`, and `commit` say plainly when
  no brief or task file was supplied or found, instead of silently
  skipping conformance and scope-drift checking.
- A closing note — `Changed / Validated / Open risks / Suggested next
  skill` — on every mutating or evaluative skill, printed, never
  persisted.
- Public skills are manual-only in both manifests.
- The installed plugin stays static: no `package.json`, `*.js`, `*.ts`,
  `*.py`, `*.sh`, `hooks.json`, `.mcp.json`, or `node_modules` anywhere
  under `plugin/`.
- No literal `Co-Authored-By:` trailer anywhere in `plugin/`, and no
  `specseam`.
- Cleanup deletes nothing it hasn't first reported: removal happens only
  under an explicit `--fix`, one evidence-confirmed item at a time with
  revert on a broken validation, and structural reorganization is
  report-only in every mode.

What's genuinely weaker than the orchestrated version: there's no
mechanical cross-file check that whatever wrote a change is a different
model from whatever reviews it — that now depends on the user actually
running `review` in a fresh session, or on Codex's honest self-declaration.
There's also no tracked ownership of task files: nothing prevents an
abandoned plan from leaving orphaned files under `docs/tasks/` if the user
walks away mid-plan.

## Terminology: the repository renamed itself

`docs/` and `CONTEXT.md` are gitignored local design context and still use
the project's original name — **SpecSeam**, `specseam`. The shipped plugin
is **My Plan**. `docs/specs/specseam-v1.md` and
`docs/tasks/specseam-v1-implementation.md` describe the earlier,
orchestrated version of this product and are historical, not authoritative,
for anything past the skill inventory above. A smoke check fails the build
if the string `specseam` appears anywhere under `plugin/`.

## Writing style

The same rule the plugin instructions themselves prescribe: one
authoritative statement per fact, current state rather than history,
reference by path instead of copying.

Commit subjects state the point of the change in a sentence. Bodies explain
in prose what was wrong and why the fix has the shape it does. This
repository's commits carry no trailers.
