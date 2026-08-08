# Capability: the code graph

How a Run reads a repository structurally instead of exhaustively. Read this when
setup provisions the capability, and when a stage says to consult the graph.

[code-review-graph](https://github.com/tirth8205/code-review-graph) parses a
checkout with Tree-sitter and stores functions, classes, imports, calls, and test
edges in a local SQLite index. Asking it which callers a file has costs a query;
finding out by reading costs the files. That difference is the whole reason this
capability exists.

It is an index, not a reader, not a reviewer, and not a record of what changed.
**The graph never decides a verdict, a write set, a hash, or a gate.** Those come
from `git diff`, the approved specification, and the user. A stage that consults
the graph is deciding where to look; it still reaches its conclusion by reading
the code the graph pointed at.

Optional throughout. A Run without it runs every phase, every gate, and every
check exactly as written elsewhere, and costs more.

## The index lives outside the repository

`<stateRoot>/graphs/<repo-key>/`, resolved per `project.md`'s State root and
`<repo-key>` definitions.

Not `.code-review-graph/` in the checkout, which is where the tool puts it by
default. Discovery is read-only against the user's repository, and an index built
during discovery would be a directory this product created in a checkout the user
has not approved anything in. It would also arrive untracked, which is exactly
what `git add -N` makes visible when a Review Subject is hashed.

Pass `--data-dir` on every CLI call, and set `CRG_DATA_DIR` in the MCP server's
environment, because `serve` has no such flag. Both point at the same path.

## Provisioning

Setup offers this; it never installs it silently.

**Three layers, three separate probes, and only the third is per-repository.**
Getting this wrong is the obvious failure: the executable and the MCP entry are
machine-wide and shared by every repository, so a probe that only asks "does this
repository have a graph?" answers no in every new repository and reinstalls what
is already there. **Probe each layer before touching it, and skip every layer
that already holds.**

| Layer | Scope | Probe | Already satisfied |
|-------|-------|-------|-------------------|
| 1. Executable | The machine | `command -v code-review-graph`, then `code-review-graph --version` | Install nothing. Record the resolved path and version |
| 2. MCP entry | The user's host config | The `code-review-graph` server entry exists, and carries `CRG_DATA_DIR` and `CRG_TOOLS` | Leave it alone. It is the user's file |
| 3. Graph index | One repository | `code-review-graph status --json --data-dir <stateRoot>/graphs/<repo-key>` reports a populated graph | Nothing to build. Freshness, below, takes over |

Layers 1 and 2 are recorded in the Working Profile, which is user-level. A second
repository reads them from there and starts at layer 3, which is the only one
that was ever about this repository.

An install that has nothing to do says so and stops. "code-review-graph 0.9.2 is
already installed and configured; building the index for this repository" is the
expected output of the second `$my-plan:install` a user ever runs, and printing
it is how they know nothing was duplicated.

**Offer**, only for the layers that are actually missing. Name those layers,
where the index will live, and that the repository itself is not written to. Then
wait. A decline is recorded as `codeGraph: "declined"` in the Working Profile and
never asked again for that repository; re-offering a declined capability every
Run is how a helpful default becomes nagging.

### Layer 1: the executable

Only when `command -v code-review-graph` finds nothing. In this order, taking the
first tool that exists:

```sh
uv tool install code-review-graph      # isolated, and uv is already probed
pipx install code-review-graph         # isolated
pip install --user code-review-graph   # last resort, never a bare pip install
```

A bare `pip install` writes into whatever interpreter happens to be on `PATH`.
That is the user's Python environment, not this product's, and breaking it costs
them more than this capability is worth.

Found but too old to carry the flags this file uses is an upgrade, not an
install, and it is the user's call: name the version, name what is missing, and
give the exact upgrade command for the tool that owns it.

### Layer 2: the MCP entry

Read the host config first and branch on what is there. Three cases, and only the
first writes a new entry:

- **No `code-review-graph` entry.** Write one, shaped as below.
- **An entry carrying both `CRG_DATA_DIR` and `CRG_TOOLS`.** Nothing to do. Do
  not rewrite it, do not normalize it, and do not re-run `install` over it. It
  may hold transport choices the user made, and this product did not put them
  there.
- **An entry missing one of the two.** That is a correction to those keys, never
  a reinstall: show the user the exact keys you would add, take an answer, and
  add only those. Every other field in that entry stays byte-for-byte. A decline
  leaves the capability at `absent` rather than half-configured — an entry
  without `CRG_TOOLS` exposes the graph's write tools to every Worker, which is
  worse than no graph.

To write a new entry:

```sh
code-review-graph install --platform codex \
  --no-instructions --no-skills --no-hooks --dry-run   # show this first
```

Then the same command without `--dry-run`. Those three flags are mandatory, not
tidiness. Left off, `install` injects graph instructions into the repository's
`AGENTS.md`, generates platform-native skills, and installs hooks
— and `project.md` says this product never modifies `AGENTS.md`, its equivalents,
custom skills, or canonical documentation. A setup step that breaks the
repository's own rule to configure an optional capability is not a trade worth
making. Writing the entry by hand is equally correct, and is the only option in
the missing-keys case above, where `install` would overwrite what it should
amend.

Either way the result carries both variables below, and the user sees the file
before it is written: that file is their configuration, not this Run's.

```json
"code-review-graph": {
  "type": "stdio",
  "command": "code-review-graph",
  "args": ["serve"],
  "env": {
    "CRG_DATA_DIR": "<stateRoot>/graphs",
    "CRG_TOOLS": "get_minimal_context_tool,get_review_context_tool,get_impact_radius_tool,detect_changes_tool,get_affected_flows_tool,get_architecture_overview_tool,list_communities_tool,get_community_tool,list_flows_tool,get_flow_tool,get_hub_nodes_tool,get_bridge_nodes_tool,get_knowledge_gaps_tool,get_suggested_questions_tool,get_surprising_connections_tool,find_large_functions_tool,semantic_search_nodes_tool,query_graph_tool,traverse_graph_tool,list_graph_stats_tool"
  }
}
```

`CRG_TOOLS` is not a convenience. A Worker here has no per-agent tool list, so
the transport is the only thing standing between it and `apply_refactor_tool`.
Every name absent from that list is unreachable for every Worker.

It also pays for itself before a single query runs. The server exposes thirty
tools whose descriptions cost several thousand tokens in every turn that can see
them; the list above drops the ten this product never uses. A capability adopted
to spend fewer tokens should not start by spending them on tools nobody calls.

### Layer 3: the index for this repository

The only layer that runs per repository, and the only one a second
`$my-plan:install` in a new repository normally reaches. Build it once, when the
layer 3 probe found no populated graph:

```sh
code-review-graph build --data-dir <stateRoot>/graphs/<repo-key> --repo <repoPath>
```

`<repo-key>` already carries 8 hex of the repository's absolute path, so two
repositories cannot land on the same index and a full build never overwrites
another repository's work.

An index that already exists is not rebuilt here. Freshness, below, is what keeps
it current, and it is an incremental `update` against a base — a full rebuild
every setup would throw away the incremental history for no gain.

Report how long it took and how many nodes it produced. A build that fails is a
capability that stays absent; it is never a blocked setup.

## Freshness

A graph belongs to the checkout it was built from. After approval the Run works
in an isolated worktree, and an index built from the primary checkout cannot see
what the implementer just wrote — it would answer confidently and be wrong, which
is worse than answering not at all.

So the Coordinator rebuilds against the worktree before trusting it: on entering
each phase that consults the graph — discovery, planning, review — run

```sh
code-review-graph update --data-dir <stateRoot>/graphs/<repo-key> --repo <worktree> --base <baseSha>
```

and only then mark the graph `fresh`. Before approval there is no worktree and
`--repo` is the primary checkout, which is safe because the index is written
outside it.

Anything else is `stale`: the update failed, the index names a different
checkout, or the phase never ran one. Workers are told which, through the
handoff's `codeGraph` field, and only `fresh` authorizes a query. `stale` and
`absent` are not failures to report as errors; they are the reason a Run read
more files than it might have, and saying so is more useful than hiding it.

## What each role may use

Every Worker here is a Codex session, so there is no per-agent tool list to
enforce this. `CRG_TOOLS` bounds what exists at all, and the role prompt bounds
what a Worker reaches for inside that.

| Role | Reads the graph for |
|------|---------------------|
| Discovery | Locating the surface a goal touches before reading it: minimal context, semantic search, traversal, communities, flows, hubs, bridges |
| Planner | `get_impact_radius_tool` and `get_affected_flows_tool` over the proposed write set |
| Implementer | Callers and callees of the code a task changes, and nothing wider |
| Reviewers | Change impact, affected flows, untested hotspots, surprising coupling |
| Committer | Nothing. It runs Git and scans for secrets; it has no reason to read a codebase |

A reviewer runs under `--sandbox read-only`, which stops it writing files. It
does not stop an MCP server from writing on its behalf, which is why the write
tools below are removed from the transport rather than trusted to the sandbox.

## Never granted to a Worker

| Tool | Why |
|------|-----|
| `apply_refactor_tool` | Edits source. A second write path the Coordinator does not check against the approved write set, and one the read-only sandbox does not cover |
| `refactor_tool` | Previews the above. Nothing in review needs it, and the pair invites the mistake |
| `generate_wiki_tool`, `get_wiki_page_tool` | Writes and reads a second architecture record. The Architecture Memory is the one this product keeps, and two records of one fact drift |
| `build_or_update_graph_tool`, `run_postprocess_tool`, `embed_graph_tool` | Write the index. Freshness is the Coordinator's, above, so that a read-only Worker stays read-only |
| `list_repos_tool`, `cross_repo_search_tool` | Reach other repositories. A Worker confined to one worktree does not get to read outside it |

## Embeddings stay local

Semantic search defaults to a local model and needs no network. A cloud
embedding provider sends source-derived text to a third party, which is the
thing `discovery-spec.md` already forbids for research queries, and the same
answer applies here. **Never enable a cloud embedding provider without asking
the user first**, and never set `CRG_ACCEPT_CLOUD_EMBEDDINGS` on their behalf.

Local embeddings are an ordinary optional extra and need no approval.

## When it disagrees with the code

The graph is a parse of a checkout at a moment. It can be stale, it can miss a
dynamic call it cannot see statically, and it can name a test edge that no longer
proves anything.

Where the graph and the code disagree, the code is right. Report the
disagreement if it matters — a caller the graph knows about and the diff does not
touch is worth a look — but never turn a graph answer into a finding without
opening the file. A finding this product cannot tie to a path and a line range
is not a finding, and that rule does not soften because an index produced it.
