# Transport: Claude Code CLI Workers

How the Coordinator runs a bounded Worker as a headless `claude` session. Read
this only when a role's resolved Worker value uses the `claude:` prefix (see
`project.md`, Model mapping and Fallback chains). Exactly two roles ever
resolve there — **Technical code review** and **Product review** — and only to
`opus`. Nothing here applies to discovery, planning, plan review,
implementation, the QA gate, or the commit: those stay `codex:` or
`opencode:`, always. `claude:` never appears outside those two roles' chains,
not as a fourth candidate anywhere else, not as a last resort for discovery,
planning, QA, or the commit.

Codex is still the host: this file only describes a transport the Coordinator,
itself a Codex session, dispatches to. Every rule in the stage modules still
holds — bounded handoffs, contract-shaped results, a model that never reviews
a subject it wrote. Where this transport's boundary is weaker than Codex's,
below, it says so rather than implying parity.

## Model and effort

`opus` is a stable CLI alias, not a Working Profile resolution. Unlike
Sol/Terra/Luna or opencode's `Pro`, there is no ID to resolve or record: pass
`--model opus` literally. Effort is a per-call flag, `--effort "$EFFORT"`,
accepting the same vocabulary as everywhere else in this product — `low`,
`medium`, `high`, `xhigh`, `max`. `high` is the working default; escalate to a
fresh `xhigh` session on a hard verdict, never by re-running the same one.

## Capability probe

Static, first: `claude --version`, then `claude -p --help`, checking that the
help text lists `--output-format`, `--json-schema`, `--model`, `--effort`,
`--resume`, and `--tools`. A missing flag fails the probe by name.

Then `claude auth status --json` for authentication readiness. Read only
whether it reports ready; never read, echo, log, or store the raw output or
any credential value.

Passing this probe does not by itself add a candidate anywhere except the two
named roles' chains — see `project.md`, "Setup-time pruning." When the probe
fails or the CLI is absent, `claude:opus` is never a legal candidate for this
Run, and both roles' chains simply start at their next entry (`sol@high`),
identically to a repository with no Claude CLI installed at all.

## Starting a Worker

`claude -p` has no `-C`/cwd-scoping flag — it operates on whatever directory
it is launched from. Launch it from the subject directory explicitly:

```sh
(
  cd "$WORKTREE" &&
  claude -p "$PROMPT" \
    --output-format json \
    --json-schema "$SCHEMA" \
    --model opus \
    --effort "$EFFORT" \
    --tools "Read,Grep,Glob,Bash" \
    </dev/null \
    >"$RESULT_FILE" \
    2>"$RESULT_FILE.stderr"
)
```

For a review dispatched before a worktree exists (there is no such case for
these two roles today — both always run against a worktree — but if that ever
changes, `cd` into the primary checkout instead).

`$SCHEMA` is the role's contract from `contracts/*.schema.json` **with
`$schema` and `$id` stripped**. Confirmed live: `--json-schema` rejects a
schema carrying `"$schema": "https://json-schema.org/draft/2020-12/schema"`
with `Error: --json-schema is not a valid JSON Schema: no schema with key or
ref "..."` — this repo's contract files carry that key for editor tooling, and
Codex's `--output-schema` tolerates it, but `claude -p` does not. Strip both
keys when rendering `$SCHEMA` for this transport only; the stripped copy is
otherwise byte-identical to the contract file. Confirmed live against the real
`review-result.schema.json` — nested arrays, enums, and nullable fields all
came back correctly typed once both keys were removed.

There is no separate `-o` flag: the result is already in the single JSON
object `claude -p` writes to stdout. Parse `.structured_output` directly.

| Flag | Why it is there |
|------|-----------------|
| `--output-format json` | A single JSON object on stdout, not an event stream — no `thread.started`-style parsing needed |
| `--json-schema` | Provider-enforced structured output, analogous to Codex's `--output-schema`. Point it at the stripped contract |
| `--model opus` | The only model this transport ever names |
| `--effort` | This call's effort. Travels per call, so an escalation raises it without changing the model |
| `--tools "Read,Grep,Glob,Bash"` | The tool boundary — see below, this is not a sandbox |
| `</dev/null` | Closes stdin so `claude` does not wait on it |
| `2>` separate | Keeps transport failures out of the result file. Read this file when a call fails |

### This is not a sandbox

There is no `--sandbox` flag on `claude` at all. `--tools` is a host-enforced
tool allowlist, the same category as opencode's `--permissions`: `Bash` stays
on the list because a reviewer needs `git log` and `git diff` to do the job,
and `Bash` can write regardless of what the tool list says. So a Claude
Worker's boundary is exactly as strong as an opencode Worker's, not as strong
as a Codex Worker's `--sandbox read-only` process boundary.

What actually covers the gap is the same thing that covers every dispatched
gate in this product: the Coordinator's own check of changed paths against
Git and the approved write set, run after the Worker returns, independent of
what the Worker reports. Never present a Claude Worker as sandboxed.

## Capturing and resuming the session

The JSON envelope already carries `.session_id` as a top-level field — no
event-stream parsing needed, simpler than either other transport:

```sh
SESSION_ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['session_id'])" "$RESULT_FILE")
```

Persist it against the Run, role, task, and attempt. Never resume "the last
session" (`-c`/`--continue`) — that continues the most recent session on the
machine, which in a repository with Parallel Runs is somebody else's work.
Always resume by explicit `--resume "$SESSION_ID"`.

```sh
(
  cd "$WORKTREE" &&
  claude -p "$PROMPT" \
    --resume "$SESSION_ID" \
    --output-format json \
    --json-schema "$SCHEMA" \
    --model opus \
    --effort "$EFFORT" \
    --tools "Read,Grep,Glob,Bash" \
    </dev/null \
    >"$RESULT_FILE" \
    2>"$RESULT_FILE.stderr"
)
```

Confirmed live: resuming with `--model`/`--effort` repeated is accepted and
the session continues coherently, recalling prior turns. Keep both stable
across a thread unless deliberately escalating.

A resume prompt carries only the pending finding IDs, changed paths, one-line
gate status, and concise correction notes — never the specification, plan, or
diff again; the session already has them. If the Coordinator changed the tree
between turns, say so and point the Worker at `git status -s` and
`git diff HEAD` as authoritative.

## Exit codes and failures

Confirmed live, both cases below; anything else is uncatalogued — read
`$RESULT_FILE.stderr` and update this table at the next Run boundary once a
real example exists, rather than assuming a case that has not been observed.

| Observed | stdout | Meaning | Response |
|----------|--------|---------|----------|
| Exit 0 | Valid JSON, `"is_error":false` | Success | Parse `.structured_output`, validate against the contract |
| Exit 1, valid JSON on stdout | `"is_error":true`, `.api_error_status`, `.terminal_reason` set | A live API failure (confirmed live: an unresolvable `--model` returns `api_error_status: 404`) | Classify by `.api_error_status`: 404-class is an unavailable model, treat as a missing capability; a 401/403-class is an authentication failure; a 429-class is quota or rate limit. All three advance the chain immediately, no retry |
| Exit 1, no JSON on stdout, error text on stderr | — | A malformed invocation (confirmed live: a schema `--json-schema` cannot parse) | Fix the call; never retry it unchanged, the same class as Codex's exit 64 |

| Class | Response |
|-------|----------|
| Missing capability, unauthenticated, quota, usage cap, or an unresolvable model (`api_error_status` in the 4xx range, `is_error:true`) | Immediate fallback to the role's next chain candidate — no retry |
| Malformed invocation (no JSON on stdout) | Fix the call; not a fallback trigger until the call itself is valid |
| Network, provider, or any other exit 1 not otherwise classified | One bounded retry, then fall back |
| Contract violation in `.structured_output` (fails the schema after parsing, or `.structured_output` absent when `is_error:false`) | Failed attempt. Never an implicit approval |

Record the transition with its phase, role, error class, replacement
candidate, and time, exactly as `codex.md` and `opencode.md` require. Do not
retain the raw stdout/stderr files as a Run artifact; do retain the session
ID, the validated result, and a concise error classification.
