# Runtime: Codex-only Workers

How the Coordinator runs bounded Workers as child Codex sessions. Every stage
rule still holds: path-only handoffs, contract-shaped results, process-enforced
read-only review, and a model that never reviews a subject it wrote.

## Model aliases and effort

`Sol`, `Terra`, and `Luna` are durable role aliases, not model IDs. Resolve their
current model IDs during setup and store the mapping in the Working Profile.
Never pass an alias to `codex exec`.

Resolve without an interactive picker:

1. Read the user's active `model` from Codex configuration.
2. Read any explicit profile overlays that name models for the three aliases.
3. Ask the user for only the missing mappings, recommending models available in
   their current Codex installation.

Sol and Terra must resolve to different IDs. Planning uses Sol and its review
uses Terra; implementation uses Terra and its review uses Sol. Different effort
levels of one model are not independent. Luna may resolve to Terra when no cheap
tier is configured because Luna never supplies the opposing review boundary.

Pass effort per call with `-c model_reasoning_effort="$EFFORT"`. `high` is the
default. Raise Terra to `xhigh`, then `max`, before declaring an implementation
task beyond it; never move that task to Sol, because Sol owns code review.

Do not pin release-specific model IDs in plugin instructions. When a recorded ID
stops resolving, reconfigure at the next Run boundary. A missing independent
mapping blocks the Run before planning or implementation.

## Capability probe

Setup requires all of these Codex CLI surfaces: `exec`, `exec resume`, `-C`,
`--json`, `--output-schema`, `-o`, and both `read-only` and `workspace-write`
sandboxes. Probe flags from help output without spending a model call. Also run
`codex login status` without reading or storing credentials.

A missing surface or authentication blocks setup with exact remediation. Record
`runtime: "codex-only"`; there is no alternate runtime selection.

## Prepare a Worker

Render the role prompt from `<pluginRoot>/internal/prompts/` by replacing only
`{{handoffPath}}` with the absolute handoff path. The prompt may contain
instructions, never the contents of a specification, plan, task, diff, or other
Run document.

Copy every artifact a sandboxed Worker needs into `<worktree>/.my-plan/`, list
each copy and hash in the handoff, and add `.my-plan/` to the worktree's local
Git exclude. This includes a reviewer checklist and a planner template when the
role needs them. A handoff never names a path the Worker cannot read.

Select the result schema by role:

| Role or mode | Prompt | Schema | Sandbox |
|--------------|--------|--------|---------|
| discovery | `challenge.tpl` | `challenge-result.schema.json` | `read-only` |
| plan creation | `plan-write.tpl` | `plan-result.schema.json` | `workspace-write` |
| plan review | `plan-check.tpl` | `review-result.schema.json` | `read-only` |
| implementation | `build.tpl` | `build-result.schema.json` | `workspace-write` |
| audit or code review | `change-check.tpl` | `review-result.schema.json` | `read-only` |
| qa | `qa.tpl` | `review-result.schema.json` | `workspace-write` |
| commit | `commit.tpl` | `commit-result.schema.json` | `workspace-write` |

The plan Worker writes exactly the `plan.md` path in its handoff and returns the
path plus a one-line summary. The Coordinator validates the file, its hash, and
its write boundary directly. Every JSON-returning role uses provider-enforced
structured output.

## Start a Worker

For a JSON-returning read-only role:

```sh
codex exec \
  --json \
  --skip-git-repo-check \
  --sandbox read-only \
  --color never \
  -C "$WORKTREE" \
  -c model="$MODEL" \
  -c model_reasoning_effort="$EFFORT" \
  --output-schema "$SCHEMA" \
  -o "$RESULT_FILE" \
  "$PROMPT" \
  </dev/null \
  >"$EVENTS_FILE" \
  2>"$EVENTS_FILE.stderr"
```

Planning and implementation use the same form with
`--sandbox workspace-write`. Every Worker uses `--output-schema`; the planning
result reports the path and hash of its file for the Coordinator to recompute.

The sandbox is the role boundary, not a prompt convention. Never run discovery or
review with workspace-write, even when a reviewer asks to apply a fix.

`qa` is the one review mode that cannot hold that boundary, because running a test
suite writes: build output, caches, coverage files. It gets workspace-write for
that reason and no other. Nothing else about it relaxes — it returns
`review-result` like any reviewer, it never edits a source file, and it never
stages or commits. What covers it instead of the sandbox is the Coordinator's
check of changed paths against the approved write set, which runs against Git and
does not depend on what the Worker reports. Grant it to `qa` and to nothing else
wearing a review label.

`commit` gets workspace-write because writing history is the job. It is bounded by
the write set in its handoff and by the Coordinator recomputing the staged set,
the resulting SHAs, and `refs/remotes` afterwards. A Worker in this mode never
pushes; the push is the user's separate decision.

## Capture and resume the exact thread

Read the first `thread.started` event from the JSONL stream and persist its
`thread_id` against the Run, role, task, and attempt. Never resume a last or most
recent session.

```sh
THREAD_ID=$(jq -r 'select(.type == "thread.started") | .thread_id' "$EVENTS_FILE" | head -1)
```

Resume only that thread:

```sh
codex exec resume "$THREAD_ID" \
  --json \
  --skip-git-repo-check \
  -c model="$MODEL" \
  -c model_reasoning_effort="$EFFORT" \
  --output-schema "$SCHEMA" \
  -o "$RESULT_FILE" \
  "$PROMPT" \
  </dev/null \
  >"$EVENTS_FILE" \
  2>"$EVENTS_FILE.stderr"
```

`resume` inherits the original sandbox and does not accept a replacement. Start
a new thread whenever the role or sandbox changes.

A resume prompt carries only the pending finding IDs, changed paths, one-line
gate status, and concise correction notes. If the Coordinator changed the tree,
tell the Worker to resync from `git status -s` and `git diff HEAD`.

## Validate before trusting

`--output-schema` rejects invalid strict schemas before the model runs. Every
property therefore has an explicit `type`, and every key in `properties` appears
in `required` at every nesting level. Nullable fields remain required.

After exit zero, parse and validate the result again, recompute all claimed
hashes and changed paths from disk, and compare them with the handoff. A valid
JSON object with false evidence is still a failed attempt. A text sentinel never
approves a phase.

## Failures

| Class | Response |
|-------|----------|
| Network, provider, internal, rate limit | One bounded retry, then mark the Run blocked |
| Missing CLI surface, unauthenticated, quota, usage cap, credits, unavailable model | Mark the Run blocked immediately |
| Invalid contract or evidence mismatch | Failed attempt; diagnose before retrying |
| Exit 2 on start or resume | Route to the complementary call; it is a thread-state signal |
| Exit 64 | Fix the malformed invocation; never retry it unchanged |

Before blocking, persist the phase, task, worktree, thread IDs, model, error
class, and concise diagnostics. Preserve the approved spec hash, plan, diff,
findings, and validation evidence. A later invocation resumes without discovery
or renewed approval. Never keep raw event streams as Run artifacts.
