# Transport: opencode CLI Workers

How the Coordinator runs a bounded Worker as an `opencode` session. Read this
only when a role's resolved Worker value uses the `opencode:` prefix (see
`project.md`, Model mapping and Fallback chains). Exactly one role ever
resolves there — **Implementation, tests, remediation** — and only for one
model. Nothing here applies to discovery, planning, plan review, code review,
product review, the QA gate, or the commit: those stay `codex:` or `claude:`,
always. `opencode:` never appears outside Implementation's chain, not on
Technical code review's or Product review's chain, not on QA's, which must
stay independent of whichever vendor actually wrote the code.

This is narrower than the same transport on the Claude Code side of this
product, which also uses opencode for discovery and audit — those two roles
stay pure Codex here. Codex is still the host: this file only describes a
transport the Coordinator, itself a Codex session, dispatches to. Every rule
in the stage modules still holds — bounded handoffs, contract-shaped results,
a model that never reviews a subject it wrote.

## Model name and effort

`Pro` is the one role name this file defines, and it is not a model ID.
Resolve it during setup and record the resolved ID in the Working Profile as
`opencodeModels.pro`. Pass the resolved ID as `--model "google/$ID"`, never
the role name.

Resolve without a TTY, in this order:

1. `~/.config/opencode/opencode.json`, `provider.google.models` — the
   configured model catalog names what the user has already set up.
2. `opencode models google`, live, to see what the provider currently exposes.
3. If neither names a working model, ask the user during setup and record the
   answer.

As of this writing, `Pro` resolves to `antigravity-gemini-3.1-pro`.
`antigravity-gemini-3-pro` answers with a deprecation notice at exit 0 rather
than failing, so it is not eligible even though it looks configured — see the
live probe below, which is exactly what catches this. This backend has no
cheap tier and does not need one: `codex:luna` already covers mechanical work.

Effort is a per-call flag, `--variant "$EFFORT"`, not a property of the
resolved model. Which effort this role gets is decided in `project.md`; this
file only passes it through.

opencode model IDs are tied to whatever the user's Antigravity/Gemini CLI
account exposes this month, so a pinned ID here would be wrong within weeks.
If a recorded ID stops resolving, or starts answering with a deprecation
notice, re-probe at the next Run boundary and update the Working Profile; if
nothing suitable can be resolved, `opencode:pro` is never a legal candidate
for this Run and Implementation's chain starts at its next entry
(`terra@high`), identically to a repository with no opencode installed at
all — see `project.md`, "Setup-time pruning."

## Capability probe

Static, first:

`opencode --version`, then `opencode run --help`, checking that the help text
lists `--session`, `--format`, `--model`, `--variant`, and `--agent`. Then
`opencode auth list`, checking for a `google` credential. A missing flag or
credential fails the probe by name; do not guess past it.

Live, second, and not optional here. Unlike Codex, opencode has no
`--output-schema` to reject a bad request before the model runs, and a
deprecated model answers normally — exit 0, a plausible-looking `text` event —
instead of failing loudly. A static probe cannot see that. Run:

```sh
opencode run "reply with the single word: ready" \
  --model "google/$CANDIDATE_ID" \
  --variant low \
  --format json \
  </dev/null
```

and read the `text` event's content, not just the exit code. A reply that is
not the requested word — a deprecation notice, a refusal, an empty string —
fails the probe for that model ID even at exit 0. Do this once per candidate
ID during setup, not on every dispatch.

## Starting a Worker

Implementation writes, so it runs with the default, unrestricted agent — no
`--agent` restriction, unlike a read-only role:

```sh
opencode run "$PROMPT" \
  --model "google/$MODEL" \
  --variant "$EFFORT" \
  --dir "$WORKTREE" \
  --format json \
  </dev/null \
  >"$EVENTS_FILE" \
  2>"$EVENTS_FILE.stderr"
```

| Flag | Why it is there |
|------|-----------------|
| `--format json` | Emits the JSONL event stream on stdout. The session ID comes from it |
| `--variant` | This call's effort for the resolved tier. It travels per call, so an escalation raises it without changing the model |
| `--dir` | Where the Worker operates: the Run's worktree |
| `</dev/null` | Closes stdin so opencode does not wait on it |
| `2>` separate | Keeps transport failures out of the event stream. Read this file when a call fails |

There is no `--sandbox` flag on `opencode run`. The write boundary here is the
same one every implementation Worker in this product has regardless of
transport: the handoff's write set, and the Coordinator verifying every
changed path against Git afterward. Implementation was never process-sandboxed
even on Codex — `--sandbox workspace-write` bounds the filesystem, not which
paths get staged — so this transport changes nothing about how that boundary
is enforced.

## There is no host-enforced contract schema

opencode has no `--output-schema` equivalent. `build-result.schema.json`
cannot be handed to the provider to reject a malformed response before the
model runs, the way Codex does.

Instead: the prompt template must state the schema and instruct the Worker to
answer with only the JSON it describes, no prose, no fencing. After the run,
the Coordinator parses the `text` event(s) as JSON and validates against the
same contract Codex would have used. A response that is not valid JSON, or
that fails the schema, is a contract violation — a failed attempt, never an
implicit approval, identical to how Codex handles the same failure one layer
lower.

## Capturing the session

```sh
SESSION_ID=$(jq -r 'select(.sessionID != null) | .sessionID' "$EVENTS_FILE" | head -1)
```

Every event in the stream carries `sessionID`, so the first line already has
it. Persist it against the Run and role, exactly as Codex's thread ID.

Never pass `--continue`/`-c`. It continues *the last session on the machine*,
which in a repository with Parallel Runs is somebody else's work. Always
resume by explicit `--session "$SESSION_ID"`.

## Resuming

```sh
opencode run "$PROMPT" \
  --session "$SESSION_ID" \
  --model "google/$MODEL" \
  --variant "$EFFORT" \
  --format json \
  </dev/null \
  >"$EVENTS_FILE" \
  2>"$EVENTS_FILE.stderr"
```

Confirmed live: passing `--model`/`--variant` on a resumed opencode session is
accepted even when the model differs from the one that started the thread,
and the session continues coherently. Keep the model and effort stable across
a thread unless deliberately escalating, and record the escalation the same
way `implementation.md` records one.

## Exit codes

Confirmed live, and only these:

| Code | Meaning | What to do |
|------|---------|------------|
| 0 | The call completed | Validate the `text` content against the contract, and — model probe only — check it actually answered the question rather than returning a deprecation notice |
| 1 | The call failed | Read `$EVENTS_FILE.stderr`. A missing or invalid `--session` value fails here with `Session not found` on stderr; treat that exact substring as the routing signal, since opencode has no Codex-style dedicated exit code for it |

opencode does not document a distinct code for a malformed invocation the way
Codex's 64 does. Anything that is not 0 or the `Session not found` case on 1
is uncatalogued: read the stderr file, record what was seen against the
failure classification below, and update this table at the next Run boundary
once a real example exists.

## Resume prompts carry only the delta

Same rule as every other transport, and for the same reason: the thread
already has the specification, plan, and diff. A resume prompt carries the
pending findings by ID, the changed paths, the gate summary in one line, and
correction notes of one to three sentences. When the Coordinator has edited
the tree between turns, say so and point the Worker at `git status -s` and
`git diff HEAD` as authoritative.

## Failure classification

| Class | Response |
|-------|----------|
| Missing capability, unauthenticated, quota, usage cap, or a model that answers with a deprecation/unavailability notice | Immediate fallback to Implementation's next chain candidate (`terra@high`) — no retry |
| `Session not found` on resume | Not a failure: start a new thread instead of resuming |
| Network, provider, or any exit 1 not otherwise classified | One bounded retry, then fall back |
| Contract violation in the result (invalid JSON, or schema mismatch) | Failed attempt. Never an implicit approval |

Record the transition with its phase, role, error class, replacement
candidate, and time, exactly as `codex.md` and `claude-cli.md` require. Do not
retain the raw event stream as a Run artifact; do retain the session ID, the
validated result, and a concise error classification.
