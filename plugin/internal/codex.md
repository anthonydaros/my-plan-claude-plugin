# Backend: Codex CLI

How to run a Worker on Codex. Read this only when the selected backend is
`hybrid`. In `claude-only` mode nothing here applies.

Every rule in the stage modules still holds: bounded handoffs, contract-shaped
results, read-only reviewers, and a writer that never reviews its own work. This
file only describes the transport.

## Capability probe

Hybrid is selected only when every one of these works: `exec`, `exec resume`,
`-C`, the read-only sandbox, the workspace-write sandbox, JSON events, and
`--output-schema`. A missing capability means `claude-only`, reported by name.

## Starting a Worker

Read-only roles (discovery, plan review, code review, audit):

```sh
codex exec \
  --json \
  --skip-git-repo-check \
  --sandbox read-only \
  --color never \
  -C "$WORKTREE" \
  -c model="$MODEL" \
  -c model_reasoning_effort=xhigh \
  --output-schema "$SCHEMA" \
  -o "$RESULT_FILE" \
  "$PROMPT" \
  </dev/null \
  >"$EVENTS_FILE" \
  2>"$EVENTS_FILE.stderr"
```

The implementation role is identical except `--sandbox workspace-write`.

| Flag | Why it is there |
|------|-----------------|
| `--json` | Emits the JSONL event stream on stdout. The thread ID comes from it |
| `--sandbox` | The tool boundary for the role. Read-only for every reviewer |
| `-C` | The Run's worktree. Never the primary checkout |
| `--output-schema` | Host-enforced structured output, pointed at the role's contract in `contracts/` |
| `-o` | Writes the Worker's final message to a file: the result to validate |
| `</dev/null` | Closes stdin so Codex does not wait on it |
| `2>` separate | Keeps transport failures out of the event stream. Read this file when a call fails |

The sandbox is not a suggestion the prompt can override. It is the reason a
reviewer cannot write even if its prompt were wrong.

## The schemas must stay strict-mode clean

`--output-schema` is enforced by the provider, not by Codex, and it rejects the
request with HTTP 400 before the model ever runs. Two rules, both verified against
the live API:

1. **Every property needs an explicit `type`.** A bare `{"const": 1}` fails with
   `schema must have a 'type' key`. Write `{"type": "integer", "const": 1}`.
2. **`required` must list every key in `properties`, at every nesting level.**
   There is no such thing as an optional field here. A field that may be absent is
   declared nullable, `{"type": ["string", "null"]}`, and still appears in
   `required`.

Adding a property to a contract without adding it to `required` breaks the hybrid
backend for that role, and it breaks at request time with no partial result. The
smoke tests check both rules; run them after touching any file in `contracts/`.

## Capturing the thread

```sh
THREAD_ID=$(jq -r 'select(.type == "thread.started") | .thread_id' "$EVENTS_FILE" | head -1)
```

Persist it against the Run and role. Resume only that exact thread.

Never resume "the last session". A `--last`-style resume picks up whatever ran
most recently, which in a repository with Parallel Runs is somebody else's work.

## Resuming

```sh
codex exec resume "$THREAD_ID" \
  --json \
  --skip-git-repo-check \
  -c model="$MODEL" \
  -c model_reasoning_effort=xhigh \
  --output-schema "$SCHEMA" \
  -o "$RESULT_FILE" \
  "$PROMPT" \
  </dev/null \
  >"$EVENTS_FILE" \
  2>"$EVENTS_FILE.stderr"
```

`resume` does not accept `--sandbox` or `--color`. It inherits the sandbox of the
session that started the thread. Passing them is an error, and assuming a resumed
implementation thread can be downgraded to read-only is wrong: start a new thread
for a different tool boundary.

## Exit codes

| Code | Meaning | What to do |
|------|---------|------------|
| 0 | Success | Validate the result file against the contract |
| 1 | Codex failed | Classify: transient, or terminal |
| 2 | Thread already exists on start, or missing on resume | Route to the other call. This is normal, not an error |
| 64 | Usage error | A malformed invocation. Fix the call; do not retry it unchanged |

Exit code 2 is the routing signal between start and resume. Treating it as a
failure makes every second attempt look broken.

## Resume prompts carry only the delta

Never resend the specification, plan, diff, or closed findings. The thread already
has them.

A resume prompt carries: the pending findings by ID, the changed paths, the gate
summary in one line, and correction notes of one to three sentences.

Correction notes are binding for the rest of the thread. State that: a convention
recorded in the notes is not a suggestion, and a corrected pattern must not
reappear.

When the Coordinator has edited the tree between turns, the resume prompt says so
and tells the Worker to resync from `git status -s` and `git diff HEAD`, treating
the current tree as authoritative. Without that, the Worker reverts changes it
did not make.

## Failure classification

| Class | Response |
|-------|----------|
| Missing, unauthenticated, quota, usage cap, credits, explicit provider limit | Immediate `claude-only` fallback, no retry |
| Network, provider, internal, rate limit | One bounded retry, then fall back |
| Contract violation in the result | Failed attempt. Never an implicit approval |

Record the transition with its phase, role, error class, replacement model, and
time. Keep the specification, plan, worktree, diff, findings, and validation
evidence. Do not repeat discovery or ask for approval again.

Store the thread ID, the validated result, a concise error classification, and any
diagnostic worth keeping. Do not retain the raw event stream as a Run artifact.
