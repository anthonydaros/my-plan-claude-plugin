# AGENTS.md

Guidance for Codex when working in this repository.

## What this repository is

The source of **My Plan**, seven independent skills for Claude Code,
Codex CLI, and Antigravity/Gemini CLI — `map`, `plan`, `implement`,
`review`, `commit`, `cleanup`, `security` — each invoked manually, one at
a time, whenever the user wants.
There is no orchestration between invocations: no Coordinator, no Worker
dispatch protocol, no persistent Run state machine. Running `plan` and
then `implement` is a user decision, not a phase transition the plugin
enforces. The one sanctioned chain lives *inside* a single invocation:
`implement` builds its task and then, without further prompting, follows
`review`'s and `commit`'s own bodies by reference — an independent
review, a fix loop bounded at three rounds, a commit gated on a
blocker-free round — closing the task out in one invocation (`--solo`
stops after the build). The filesystem is the only state that survives between
invocations: `docs/map.md`, `docs/brief.md`, `docs/plan.md`, and
`docs/tasks/*.md` are ordinary, user-editable files, not a generated
dossier owned by the plugin. `plan` used to be three skills — `spec`,
`plan`, `review-plan` — merged into one interview-to-reviewed-plan
invocation; `review` used to be two — `review` and `validate` — merged so
every review carries a real execution pass, not only a reading one.

`CLAUDE.md` covers the same ground for Claude Code — it exists locally but
is gitignored, so it is not on GitHub; read it directly from disk before
touching anything under `plugin/`. This file is this repository's
authoritative guidance on GitHub.

There is no code. The plugin is **static by contract**: prose instructions,
frontmatter, and templates. Nothing is compiled, bundled, or installed.
Changing behavior means editing instructions, and the only way to verify a
change is to read it and run the smoke checks.

`plugin/` is what users install; everything else is development scaffolding.
It carries three host manifests over one shared body of skills —
`plugin/.claude-plugin/` for Claude Code, `plugin/.codex-plugin/` for
Codex CLI, and a root `plugin/plugin.json` for Antigravity. There used
to be a second, mirrored `codex-plugin/` tree; it's gone, because
maintaining near-identical trees cost more than the real differences
between the hosts were worth. Gemini CLI needs no manifest at all: each
skill folder links in directly (`gemini skills link`), and the `../../`
references resolve through the symlink into the real tree.

## Commands

```sh
sh tests/smoke-posix.sh          # all static checks, one pass
pwsh ./tests/smoke-windows.ps1   # Windows-only: paths and manifests under PowerShell
claude plugin validate ./plugin  # Claude Code manifest shape
claude plugin validate .         # marketplace manifest
```

`codex plugin --help` only exposes `add`/`list`/`marketplace`/`remove` —
there's no `codex plugin validate`, and Antigravity has no headless
validator installable in CI either. `smoke-posix.sh` is what checks
`plugin/.codex-plugin/plugin.json`, `plugin/plugin.json`, and
`.agents/plugins/marketplace.json` statically; CI additionally exercises
a real Codex CLI marketplace install and a real Gemini CLI `skills link`
ingestion against this repository — on Linux runners only, deliberately:
the macOS (10×) and Windows (2×) paid-multiplier legs produced a real
GitHub charge and were removed; `smoke-windows.ps1` remains for running
locally on a Windows machine.

`smoke-posix.sh` runs every check in one pass and prints `ok`/`FAIL` per
line. There's no way to select one check; to isolate a failure, run the
script and read the labelled line.

## Layout

| Path | Role |
|------|------|
| `plugin/skills/*/SKILL.md` | The seven public skills. Manual-only, one body read by every host |
| `plugin/skills/*/agents/openai.yaml` | Codex-only sidecar: `allow_implicit_invocation: false`, the skill's `$my-plan:<name>` invocation string, display metadata. No `model`/`tools` field — Codex has no subagent-with-model primitive |
| `plugin/agents/my-plan-reviewer.md`, `my-plan-committer.md` | Claude-only native subagents. Codex CLI has no equivalent dispatch mechanism — see "Independence" below |
| `plugin/knowledge/checklists/*.md` | The eleven-lens review checklist, the architecture/overengineering checklist, the implementation defect catalogue, cleanup's dead-code/residue/doc-drift/opt-in-refactor checklists, the shared secret-pattern list, and security's secrets/deps/code/config checklists |
| `plugin/knowledge/references/**` | 34 vendored, MIT-licensed language and cross-cutting review guides, attributed in `NOTICE.md` |
| `plugin/knowledge/templates/*.md` | Lean document shapes: `brief.md`, `plan.md`, `task.md`, `report.md` |
| `plugin/.codex-plugin/plugin.json` | The Codex manifest: `"skills": "./skills/"`, no `mcpServers`, no `hooks`. Claude Code's manifest sits beside it at `plugin/.claude-plugin/plugin.json` |
| `plugin/plugin.json` | The Antigravity manifest, at the plugin root as that host's installer requires — same field shape Google's own plugins ship; skills surface there as unprefixed `/name` slash commands |

## The shared skill body

Every `SKILL.md` is read as-is by every host — no build step, no per-host
copy. Codex CLI's and the Google hosts' SKILL.md conventions only document
`name` and `description` in frontmatter; the shared body also carries
`argument-hint` and `disable-model-invocation: true` for Claude Code's
benefit, and the others tolerate the extra keys silently (verified
empirically with a real `codex exec` run and a real `gemini skills link`
+ `list` run, not assumed). Codex's own manual-only enforcement lives in
the sidecar `agents/openai.yaml`, not in the shared frontmatter;
Antigravity and Gemini CLI have no enforcement field at all — there the
guarantee drops to declaration: every description says the skill
activates solely on explicit invocation, and every body carries a guard
telling the model to stop if the skill loaded unasked. The weakest of
the three levels, accepted deliberately, checked by the smoke tests for
presence — never presented as enforcement.

Claude Code substitutes `$ARGUMENTS` natively; the other hosts do not, so
every skill body says explicitly to take the text after the skill's
invocation (`$my-plan:<name>` in Codex, `/<name>` or the skill's name in
Antigravity/Gemini) instead — both sentences are in every skill on
purpose, since the file doesn't know which host loaded it.

No `${CLAUDE_PLUGIN_ROOT}` and no `<pluginRoot>` anywhere. Every reference
to `knowledge/` or `agents/` inside a `SKILL.md` is a path relative to that
file's own location, which resolves identically under every host. Under
Gemini CLI the sanctioned install is `gemini skills link` (a symlink;
`..` resolves physically through it into the real tree, verified) —
`gemini skills install` copies the skill folder in isolation and severs
those references, so no doc may ever recommend it.

OpenCode remains unsupported: same auto-invocation gap as the Google
hosts, with no demand that justified accepting the declared-only
manual-only level there.

## Independence, and where it's real

`plan`, `implement`, `review`, `commit`, `cleanup`, and `security` each
state two independence mechanisms. In Claude Code, dispatching to
`agents/my-plan-reviewer.md` or
`agents/my-plan-committer.md` is a real tool boundary: neither subagent
holds `Write`, `Edit`, or `NotebookEdit` — and `implement`'s chained
review and commit phases dispatch those same subagents, so the boundary
holds inside the chain too. In Codex CLI and Antigravity there is no
subagent-dispatch primitive to hang that on, so the guarantee degrades to a
self-declaration: if the session's own context shows it authored what it's
about to judge, it says so instead of claiming independence it doesn't
have. This is a real, stated asymmetry between the hosts, not an
oversight — don't try to paper over it by inventing a fake dispatch
mechanism. It's the default outcome for `plan` and for `implement`'s
chain now, not an edge case, since each runs authoring and judging phases
in one invocation.

## Guarantees worth keeping without a state machine

An earlier version of this plugin enforced these through a Run manifest, a
handoff contract, and a Coordinator that verified every Worker's claim.
None of that exists anymore. What survives, checked by `tests/smoke-posix.sh`
where it can be:

- Reviewers and the committer hold no file-editing tool.
- The secret scan lives in one place, `knowledge/checklists/secrets-patterns.md`
  — `.env`/`*.pem`/`AKIA`/`ghp_`/`sk-` patterns, plus reading staged
  *prose*, not only code — and both `commit` and `security` read that
  single file rather than carrying their own copy.
- No push skill exists. `commit` never pushes and prints the exact
  `git push` command instead — dropping automation here made the guarantee
  stronger, not weaker, since a skill that doesn't exist can't drift into
  pushing.
- Declared blindness: `review` and `commit` say plainly when no brief or
  task file was supplied or found, instead of silently skipping
  conformance and scope-drift checking.
- A closing note — `Changed / Validated / Open risks / Suggested next
  skill` — on every mutating or evaluative skill, printed, never
  persisted.
- Public skills are manual-only in every host, at three levels: enforced
  by frontmatter in Claude Code and by the sidecar in Codex CLI, declared
  by description plus an in-body guard in Antigravity and Gemini CLI,
  which have no enforcement field.
- The installed plugin stays static: no `package.json`, `*.js`, `*.ts`,
  `*.py`, `*.sh`, `hooks.json`, `.mcp.json`, or `node_modules` anywhere
  under `plugin/`.
- No literal `Co-Authored-By:` trailer anywhere in `plugin/`, and no
  `specseam`.
- Cleanup deletes nothing it hasn't first reported: removal happens only
  under an explicit `--fix`, one evidence-confirmed item at a time with
  revert on a broken validation, and structural reorganization is
  report-only in every mode.
- Security never remediates: no `--fix` exists for it at all, in any
  category — every finding is evidence handed to a human, to `plan`, or
  to a package manager's own upgrade command, run by the user.
- `review` never trusts a reading impression over a real result: its
  execution pass always runs first, in isolation, and `--fix` may only
  re-verify an execution-backed finding by re-running the same command,
  never by re-reading the change.
- `commit` never invents a changelog: it drafts an entry only when the
  repository already keeps one, matching that file's own format, never
  creating the file or a new section shape. `--changelog` authorizes
  drafting without the confirm ask — `implement`'s chain passes it — and
  changes nothing else about when an entry exists.
- `implement`'s chain is bounded, gated, and single-task: the chained
  commit happens only on a review round with no `blocker` findings and
  commits that round's tree exactly as it was reviewed (a green round's
  majors and minors become open risks, never quiet post-review fixes —
  fixes happen only while a round is red, so every fix precedes a fresh
  full round), the loop stops after three review rounds and hands a
  still-red result to the user instead of committing, a blocker whose
  correction lies outside the task's write set stops the chain red
  immediately, and the chain never starts the next task. Each chained
  phase follows the sibling skill's own body by reference, so neither
  procedure exists twice to drift.

What's genuinely weaker than the orchestrated version: there's no
mechanical cross-file check that whatever wrote a change is a different
model from whatever reviews it — in Claude Code that rides on the
subagent dispatch boundary (including inside `implement`'s chain), and in
Codex and Antigravity it rests entirely on the honest self-declaration,
which the chain makes `implement`'s default outcome, same as `plan`. On
the Google hosts the manual-only guarantee itself is also declaration,
not enforcement — the host may hand a skill to the model unasked, and
the guard in the body is what tells it to stop.
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
