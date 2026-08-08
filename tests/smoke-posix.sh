#!/bin/sh
# Static checks for the My Plan plugin. Development only; never installed.
# Fails on anything that would break plugin loading or violate the frozen spec.
#
# Deliberately not `set -e`. Every check here runs a command and hands its status
# to check(), which counts the failure and keeps going; under `set -e` the shell
# exits on that same failing command instead, so the first broken invariant aborts
# the run before check() is ever reached. That produced the worst possible output:
# exit 1 with no FAIL line and a tail of passing checks, which reads as success.
# The failure count at the end is what decides the exit status.
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN="$ROOT/plugin"
CODEX_PLUGIN="$ROOT/codex-plugin"
fails=0

fail() { printf 'FAIL %s\n' "$1"; fails=$((fails + 1)); }
pass() { printf 'ok   %s\n' "$1"; }

check() {
  if [ "$1" = "0" ]; then pass "$2"; else fail "$2"; fi
}

has() {
  # has <file> <pattern> -- fixed-string match anywhere in file
  grep -qF -- "$2" "$1" 2>/dev/null
}

frontmatter() {
  # frontmatter <file> -- everything between the first two --- lines
  awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1' "$1"
}

echo "== manifests"

for m in \
  "$ROOT/.claude-plugin/marketplace.json" \
  "$PLUGIN/.claude-plugin/plugin.json" \
  "$ROOT/.agents/plugins/marketplace.json" \
  "$CODEX_PLUGIN/.codex-plugin/plugin.json"; do
  if [ ! -f "$m" ]; then fail "missing $m"; continue; fi
  # Any of these parsers is fine; the plugin ships none of them.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$m" >/dev/null 2>&1
    check $? "valid JSON: ${m#"$ROOT"/}"
  elif command -v node >/dev/null 2>&1; then
    node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$m" >/dev/null 2>&1
    check $? "valid JSON: ${m#"$ROOT"/}"
  else
    printf 'skip no JSON parser available for %s\n' "${m#"$ROOT"/}"
  fi
done

has "$PLUGIN/.claude-plugin/plugin.json" '"name": "my-plan"'
check $? "plugin name is my-plan"

has "$ROOT/.claude-plugin/marketplace.json" '"source": "./plugin"'
check $? "marketplace publishes ./plugin"

has "$CODEX_PLUGIN/.codex-plugin/plugin.json" '"name": "my-plan"'
check $? "Codex plugin name is my-plan"

has "$CODEX_PLUGIN/.codex-plugin/plugin.json" '"version": "0.1.0"'
check $? "Codex plugin version is 0.1.0"

has "$CODEX_PLUGIN/.codex-plugin/plugin.json" '"skills": "./skills/"'
check $? "Codex manifest publishes only its skill root"

if grep -Eq '"(mcpServers|hooks)"[[:space:]]*:' "$CODEX_PLUGIN/.codex-plugin/plugin.json"; then
  fail "Codex manifest must not declare MCP servers or hooks"
else
  pass "Codex manifest has no MCP servers or hooks"
fi

has "$ROOT/.agents/plugins/marketplace.json" '"name": "my-plan-codex"'
check $? "Codex marketplace name is my-plan-codex"

has "$ROOT/.agents/plugins/marketplace.json" '"path": "./codex-plugin"'
check $? "Codex marketplace publishes ./codex-plugin"

has "$ROOT/.agents/plugins/marketplace.json" '"installation": "AVAILABLE"'
check $? "Codex marketplace installation policy is AVAILABLE"

has "$ROOT/.agents/plugins/marketplace.json" '"authentication": "ON_INSTALL"'
check $? "Codex marketplace authentication policy is ON_INSTALL"

has "$ROOT/.agents/plugins/marketplace.json" '"category": "Development"'
check $? "Codex marketplace category is Development"

echo "== public skills"

for s in install start audit; do
  f="$PLUGIN/skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then fail "missing $f"; continue; fi

  frontmatter "$f" | grep -q "^name: $s\$"
  check $? "$s declares name: $s"

  frontmatter "$f" | grep -q "^description: ."
  check $? "$s has a description"

  frontmatter "$f" | grep -q "^disable-model-invocation: true\$"
  check $? "$s is manual only"

  has "$f" '$ARGUMENTS'
  check $? "$s consumes \$ARGUMENTS"
done

echo "== Codex public skills"

for s in install start audit; do
  f="$CODEX_PLUGIN/skills/$s/SKILL.md"
  meta="$CODEX_PLUGIN/skills/$s/agents/openai.yaml"
  if [ ! -f "$f" ]; then fail "missing Codex skill $s"; continue; fi
  if [ ! -f "$meta" ]; then fail "missing Codex skill metadata $s"; continue; fi

  frontmatter "$f" | grep -q "^name: $s\$"
  check $? "Codex $s declares name: $s"

  frontmatter "$f" | grep -q "^description: ."
  check $? "Codex $s has a description"

  [ "$(frontmatter "$f" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')" = "2" ]
  check $? "Codex $s frontmatter contains only name and description"

  has "$meta" 'allow_implicit_invocation: false'
  check $? "Codex $s is manual only"

  has "$meta" "\$my-plan:$s"
  check $? "Codex $s metadata names its invocation"
done

echo "== agents"

# Filename and frontmatter name must agree: the host lists agents by filename,
# so a mismatch makes the agent unaddressable by the name its prompt claims.
for a in discovery planner implementer reviewer reviewer-deep committer; do
  f="$PLUGIN/agents/my-plan-$a.md"
  if [ ! -f "$f" ]; then fail "missing $f"; continue; fi

  frontmatter "$f" | grep -q "^name: my-plan-$a\$"
  check $? "agent $a name matches its filename"

  frontmatter "$f" | grep -q "^tools: \["
  check $? "agent $a declares a bounded tool list"

  # Effort is not overridable per dispatch, so whatever the file declares is what
  # runs. An unrecognized value is dropped by the host and the Worker silently
  # falls back to the session's effort.
  frontmatter "$f" | grep -qE "^effort: (low|medium|high|xhigh|max)\$"
  check $? "agent $a declares a valid effort"
done

# The writer/reviewer boundary is the one invariant a prompt edit could silently
# break, so it gets its own check rather than trusting review. The reviewer
# reviews both plans and code, so it is the one that must never gain a write tool.
for a in discovery reviewer reviewer-deep; do
  if frontmatter "$PLUGIN/agents/my-plan-$a.md" | grep -qE '^tools: \[.*(Write|Edit|NotebookEdit)'; then
    fail "agent $a must stay read-only"
  else
    pass "agent $a is read-only"
  fi
done

for a in implementer planner; do
  frontmatter "$PLUGIN/agents/my-plan-$a.md" | grep -q "Write"
  check $? "$a can write"
done

# The committer writes history, not files. It needs Bash to run Git and nothing
# that edits a tracked file: a committer that can edit can fix what the secret
# scan just refused, which is the one thing refusing must not become negotiable.
if frontmatter "$PLUGIN/agents/my-plan-committer.md" | grep -qE '^tools: \[.*(Write|Edit|NotebookEdit)'; then
  fail "committer must not be able to edit files"
else
  pass "committer edits no files"
fi

# Plan author and plan reviewer must not be the same model, and neither must the
# code author and the code reviewer. Same-model review is the failure this whole
# product exists to prevent. Two reviewer agents exist because two Claude families
# cannot cover both pairs from one file: the plan reviewer must differ from Opus,
# and the claude-only code reviewer must differ from Sonnet.
author=$(frontmatter "$PLUGIN/agents/my-plan-planner.md" | grep '^model:' | cut -d' ' -f2)
critic=$(frontmatter "$PLUGIN/agents/my-plan-reviewer.md" | grep '^model:' | cut -d' ' -f2)
coder=$(frontmatter "$PLUGIN/agents/my-plan-implementer.md" | grep '^model:' | cut -d' ' -f2)
deep=$(frontmatter "$PLUGIN/agents/my-plan-reviewer-deep.md" | grep '^model:' | cut -d' ' -f2)
[ "$author" != "$critic" ]
check $? "plan author ($author) differs from its reviewer ($critic)"
[ "$coder" != "$deep" ]
check $? "code author ($coder) differs from its reviewer ($deep)"
[ "$critic" != "$deep" ]
check $? "the two reviewers are different models ($critic, $deep)"

# The two reviewers differ in model and in nothing else. A tool granted to one and
# not the other makes the review boundary depend on which one got dispatched.
r_tools=$(frontmatter "$PLUGIN/agents/my-plan-reviewer.md" | grep '^tools:')
d_tools=$(frontmatter "$PLUGIN/agents/my-plan-reviewer-deep.md" | grep '^tools:')
[ "$r_tools" = "$d_tools" ]
check $? "both reviewers declare the same tool list"

echo "== internal assets"

for f in \
  internal/stages/project.md \
  internal/stages/discovery-spec.md \
  internal/stages/planning.md \
  internal/stages/implementation.md \
  internal/stages/review.md \
  internal/prompts/challenge.tpl \
  internal/prompts/plan-check.tpl \
  internal/prompts/build.tpl \
  internal/prompts/change-check.tpl \
  internal/prompts/qa.tpl \
  internal/prompts/commit.tpl \
  internal/contracts/handoff.schema.json \
  internal/contracts/challenge-result.schema.json \
  internal/contracts/review-result.schema.json \
  internal/contracts/build-result.schema.json \
  internal/contracts/commit-result.schema.json \
  internal/checklists/review.md \
  internal/checklists/architecture.md \
  internal/checklists/implementation.md \
  internal/references/README.md \
  internal/references/NOTICE.md \
  internal/templates/project-skill.md.tpl; do
  [ -f "$PLUGIN/$f" ]
  check $? "exists: $f"
done

for d in discovery research spec plan implementation validation review audit delivery; do
  [ -f "$PLUGIN/internal/templates/documents/$d.md.tpl" ]
  check $? "exists: documents/$d.md.tpl"
done

for f in \
  internal/codex.md \
  internal/stages/project.md \
  internal/stages/discovery-spec.md \
  internal/stages/planning.md \
  internal/stages/implementation.md \
  internal/stages/review.md \
  internal/prompts/challenge.tpl \
  internal/prompts/plan-write.tpl \
  internal/prompts/plan-check.tpl \
  internal/prompts/build.tpl \
  internal/prompts/change-check.tpl \
  internal/prompts/qa.tpl \
  internal/prompts/commit.tpl \
  internal/contracts/handoff.schema.json \
  internal/contracts/challenge-result.schema.json \
  internal/contracts/plan-result.schema.json \
  internal/contracts/review-result.schema.json \
  internal/contracts/build-result.schema.json \
  internal/contracts/commit-result.schema.json \
  internal/checklists/review.md \
  internal/checklists/architecture.md \
  internal/checklists/implementation.md \
  internal/references/README.md \
  internal/references/NOTICE.md \
  internal/templates/project-skill.md.tpl \
  internal/templates/project-skill-openai.yaml.tpl; do
  [ -f "$CODEX_PLUGIN/$f" ]
  check $? "exists in Codex plugin: $f"
done

for d in discovery research spec plan implementation validation review audit delivery; do
  [ -f "$CODEX_PLUGIN/internal/templates/documents/$d.md.tpl" ]
  check $? "exists in Codex plugin: documents/$d.md.tpl"
done

echo "== push is gated, commits are scanned"

# Two invariants a prompt edit could quietly undo, both of which leak or publish
# something the user did not agree to.
grep -rq "push gate" "$PLUGIN/skills/start/SKILL.md"
check $? "the push gate is stated to the Coordinator"

grep -rq "## The push gate" "$PLUGIN/internal/stages/implementation.md"
check $? "delivery stops at the push gate"

# The approval of the spec must not read as authorizing the push. The same claim
# has appeared twice in different words, so two guards. The grep below is a broad
# tripwire against the known ", and push." list shape — it may false-positive on
# an innocuous future sentence, which is the acceptable cost of a tripwire. The
# positive check after it is the real guarantee: the section must say the push is
# not covered.
if grep -q "remediation, commit, fast-forward integration, and push" "$PLUGIN/skills/start/SKILL.md"; then
  fail "spec approval still claims to authorize push"
else
  pass "spec approval stops at local commits"
fi

if grep -qE ', and push\.' "$PLUGIN/internal/stages/discovery-spec.md"; then
  fail "approval section claims to authorize push (discovery-spec)"
else
  pass "discovery-spec approval stops at local commits"
fi

grep -q "It never authorizes the push" "$PLUGIN/internal/stages/discovery-spec.md"
check $? "discovery-spec states the push is not covered by approval"

grep -rq "Before every commit: check what you are about to publish" "$PLUGIN/internal/stages/implementation.md"
check $? "staged sets are scanned before commit"

# Fixed-string search: these are literal patterns in the doc, not regexes to run.
for pattern in 'PRIVATE KEY' 'AKIA' 'api[_-]?key' '.env' 'bearer '; do
  grep -qF -- "$pattern" "$PLUGIN/internal/stages/implementation.md"
  check $? "secret scan names $pattern"
done

grep -q "## The push gate" "$CODEX_PLUGIN/internal/stages/implementation.md"
check $? "Codex delivery stops at the push gate"

grep -q "It never authorizes the push" "$CODEX_PLUGIN/internal/stages/discovery-spec.md"
check $? "Codex spec approval stops at local commits"

grep -q "Before every commit: check what you are about to publish" "$CODEX_PLUGIN/internal/stages/implementation.md"
check $? "Codex staged sets are scanned before commit"

for pattern in 'PRIVATE KEY' 'AKIA' 'api[_-]?key' '.env' 'bearer '; do
  grep -qF -- "$pattern" "$CODEX_PLUGIN/internal/stages/implementation.md"
  check $? "Codex secret scan names $pattern"
done

grep -q -- '--sandbox read-only' "$CODEX_PLUGIN/internal/codex.md"
check $? "Codex reviewers use a read-only sandbox"

grep -q -- '--sandbox workspace-write' "$CODEX_PLUGIN/internal/codex.md"
check $? "Codex writers use a workspace-write sandbox"

grep -q -- '--output-schema' "$CODEX_PLUGIN/internal/codex.md"
check $? "Codex Worker results use provider-enforced schemas"

grep -q 'Sol and Terra must resolve to different IDs' "$CODEX_PLUGIN/internal/codex.md"
check $? "Codex writer and reviewer models must differ"

grep -q 'implementation uses Terra and its review uses Sol' "$CODEX_PLUGIN/internal/codex.md"
check $? "Codex implementation and code review use opposing models"

grep -q 'Planning uses Sol and its review' "$CODEX_PLUGIN/internal/codex.md"
check $? "Codex planning and plan review use opposing models"

echo "== Codex lifecycle contract"

has "$CODEX_PLUGIN/internal/stages/project.md" 'Record it in `profile.json` and every'
check $? "codex-only runtime is recorded in profiles and Runs"

has "$CODEX_PLUGIN/internal/stages/project.md" '~/.codex/plugins/data/my-plan-my-plan/'
check $? "Codex state uses its own POSIX root"

has "$CODEX_PLUGIN/internal/stages/project.md" '%USERPROFILE%\.codex\plugins\data\my-plan-my-plan\'
check $? "Codex state uses its own Windows root"

has "$CODEX_PLUGIN/internal/stages/project.md" '.agents/skills/my-plan-project/'
check $? "Codex setup owns only the .agents Project Skill"

[ ! -e "$CODEX_PLUGIN/agents" ]
check $? "Codex plugin installs no global agents"

has "$CODEX_PLUGIN/skills/start/SKILL.md" 'Everything before approval is read-only against the user'
check $? "pre-approval repository state is read-only"

has "$CODEX_PLUGIN/skills/start/SKILL.md" "All mutation happens in the Run's isolated"
check $? "approved mutation stays in the isolated worktree"

has "$CODEX_PLUGIN/internal/codex.md" 'One bounded retry, then mark the Run blocked'
check $? "transient Worker failure gets one retry"

has "$CODEX_PLUGIN/internal/codex.md" 'quota, usage cap, credits, unavailable model'
check $? "quota and model failures block without fallback"

has "$CODEX_PLUGIN/internal/codex.md" 'Never resume a last or most'
check $? "Worker continuation requires an exact thread"

has "$CODEX_PLUGIN/skills/audit/SKILL.md" 'Read-only until findings are accepted'
check $? "audit remains read-only until accepted findings become a spec"

has "$CODEX_PLUGIN/internal/stages/project.md" 'docs/my-plan/SEAM.md'
check $? "both distributions share the Architecture Memory path"

echo "== the three dispatched gates keep their boundaries"

# Each gate moved work the Coordinator used to do inline into a Worker whose
# report the Coordinator must not simply believe. What makes that safe is a
# specific verification on the Coordinator's side, and each one is a sentence a
# later edit could drop without anything else noticing.

for p in "$PLUGIN" "$CODEX_PLUGIN"; do
  label=$([ "$p" = "$PLUGIN" ] && echo plugin || echo Codex)

  # Dispatching the commit is the change that could quietly hand a Worker the
  # push. This is the check that proves it did not, rather than trusting the
  # contract field that claims it.
  grep -q "git for-each-ref refs/remotes" "$p/internal/stages/implementation.md"
  check $? "$label: the committer's remote refs are verified, not trusted"

  grep -q "The commit is dispatched, not typed here" "$p/internal/stages/implementation.md"
  check $? "$label: the commit runs in a session that did not watch the Run"

  # The secret scan stays the Coordinator's. A committer that owned it would be a
  # Worker grading its own refusal.
  grep -q "Run the scan above yourself" "$p/internal/stages/implementation.md"
  check $? "$label: the secret scan did not move into the committer"

  grep -qF -- 'status: "refused"' "$p/internal/stages/implementation.md"
  check $? "$label: a refused commit is surfaced, not worked around"

  # QA exists to run what the writer only reported running. If it ever shares a
  # session or a model with the writer, it proves nothing.
  grep -q "## The QA gate" "$p/internal/stages/review.md"
  check $? "$label: the QA gate is a dispatched Worker"

  grep -q "did not write the code" "$p/internal/stages/review.md"
  check $? "$label: QA never runs on the model that wrote the code"

  grep -q "## 6. Findings review" "$p/internal/stages/discovery-spec.md"
  check $? "$label: the discovery synthesis is reviewed before it becomes a spec"

  # A fallback chain walked blindly puts the writer's model on the reviewer's
  # role, which is the exact defect this product exists to prevent. The skip rule
  # and the refusal to wrap are what keep availability from eroding independence.
  grep -q "### Fallback chains" "$p/internal/stages/project.md"
  check $? "$label: every role has an ordered fallback chain"

  grep -q "A chain ends. It never wraps." "$p/internal/stages/project.md"
  check $? "$label: an exhausted chain blocks instead of reusing the writer"

  grep -q "Effort is not a chain step" "$p/internal/stages/project.md"
  check $? "$label: an unavailable model is not answered by raising effort"

  # The skip rule compares against the identity bound to the opposing role. That
  # identity lives in run.json and nowhere else, so a resumed Run without it is
  # free to hand the reviewer the model that wrote the code.
  grep -qF -- '"roleBindings": {' "$p/internal/stages/project.md"
  check $? "$label: run.json carries the active candidate per role"

  grep -q "only place it exists" "$p/internal/stages/project.md"
  check $? "$label: the skip rule reads bound identities from the manifest"

  # A dispatched commit can land and the session can die before it is recorded.
  # Re-dispatching then double-commits, and no write-set check catches it.
  grep -q "Check whether it already happened" "$p/internal/stages/implementation.md"
  check $? "$label: the commit is not re-dispatched over work already committed"
done

# opencode validates its contract after the model runs rather than before, which
# is tolerable for evidence and for code about to be reviewed, and not tolerable
# for a verdict. A chain is the likeliest place for that line to erode.
grep -q "opencode never appears on a review chain" "$PLUGIN/internal/stages/project.md"
check $? "no review role can fall back to opencode"

# The committer asserts it moved no remote ref. The field has to stay required and
# stay documented as mandatory-empty, or the assertion becomes decorative.
grep -q "Must be empty" "$PLUGIN/internal/contracts/commit-result.schema.json"
check $? "commit contract forbids touching a remote ref"

grep -q '"remoteRefsTouched"' "$PLUGIN/internal/contracts/commit-result.schema.json"
check $? "commit contract requires the remote-ref assertion"

echo "== field-test gaps stay closed"

# Each of these was a real failure observed in a live end-to-end run. The fix is
# prose, so only a literal check keeps a later edit from silently undoing it.

grep -q "Delivered subject hash" "$PLUGIN/internal/stages/project.md"
check $? "delivered subject hash is defined (recomputable after delivery)"

grep -q "record the delivered subject hash" "$PLUGIN/internal/stages/implementation.md"
check $? "completion records the delivered subject hash"

grep -q "git add -N" "$PLUGIN/internal/stages/review.md"
check $? "full-subject hashing makes untracked files visible first"

grep -q "changelog whenever the change is visible" "$PLUGIN/internal/stages/discovery-spec.md"
check $? "spec write set covers the changelog for user-visible changes"

grep -q "no changelog path is a finding" "$PLUGIN/internal/prompts/plan-check.tpl"
check $? "plan-check looks for the changelog in the write set"

grep -q "Never substitute a location of your own" "$PLUGIN/internal/stages/project.md"
check $? "an unwritable state root blocks setup instead of improvising"

grep -q "not a second writer" "$PLUGIN/internal/stages/implementation.md"
check $? "host-denied worker writes are applied byte for byte, never authored"

grep -q "no remote there will never be one to wait for" "$PLUGIN/internal/stages/implementation.md"
check $? "worktree removal covers the no-remote case"

grep -q "no-ext-diff" "$PLUGIN/internal/stages/project.md"
check $? "subject hashing pins the git diff invocation"

for pattern in \
  'Delivered subject hash' \
  'record the delivered subject hash' \
  'git add -N' \
  'changelog whenever the change is visible' \
  'no changelog path is a finding' \
  'Never substitute a location of your own' \
  'not a second writer' \
  'no remote there will never be one to wait for' \
  'no-ext-diff'; do
  grep -rqF -- "$pattern" "$CODEX_PLUGIN"
  check $? "Codex field-test guard survives: $pattern"
done

echo "== contracts are strict-mode clean"

# Provider-enforced structured output rejects the request with HTTP 400 before the
# model runs if any property lacks "type", or if "required" omits any key in
# "properties" at any depth. Both have bitten this repo. Optional fields are
# nullable and still required.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$PLUGIN/internal/contracts" "$CODEX_PLUGIN/internal/contracts" <<'PY'
import json, pathlib, sys

bad = []

def walk(node, where):
    if isinstance(node, dict):
        if "properties" in node and isinstance(node["properties"], dict):
            props = set(node["properties"])
            req = set(node.get("required", []))
            for missing in sorted(props - req):
                bad.append(f"{where}: '{missing}' in properties but not in required")
            for name, sub in node["properties"].items():
                if isinstance(sub, dict) and "type" not in sub and "$ref" not in sub:
                    if not any(k in sub for k in ("anyOf", "oneOf", "allOf")):
                        bad.append(f"{where}.{name}: no 'type' key")
        for key, sub in node.items():
            if key != "properties":
                walk(sub, f"{where}.{key}")
            else:
                for name, s in sub.items():
                    walk(s, f"{where}.{name}")
    elif isinstance(node, list):
        for i, sub in enumerate(node):
            walk(sub, f"{where}[{i}]")

for directory in sys.argv[1:]:
    for path in sorted(pathlib.Path(directory).glob("*.json")):
        walk(json.load(path.open()), f"{path.parent.parent.parent.name}/{path.name}")

for line in bad:
    print(f"FAIL {line}")
print("ok   contracts are strict-mode clean" if not bad else f"{len(bad)} strict-mode violation(s)")
sys.exit(1 if bad else 0)
PY
  check $? "contract schemas accept --output-schema"
else
  printf 'skip no python3 for strict-mode contract check\n'
fi

echo "== commits stay the user's"

# A plugin that writes commits into other people's repositories must never sign
# them with anything but the repository's own identity.
# Match the trailer form "Co-Authored-By:" rather than the word, so the rule that
# forbids it does not trip its own check.
if grep -rq "Co-Authored-By:" "$PLUGIN" 2>/dev/null; then
  fail "plugin contains a literal Co-Authored-By trailer"
else
  pass "no Co-Authored-By trailer anywhere"
fi

if grep -rq "Co-Authored-By:" "$CODEX_PLUGIN" 2>/dev/null; then
  fail "Codex plugin contains a literal Co-Authored-By trailer"
else
  pass "Codex plugin has no Co-Authored-By trailer"
fi

grep -rq "Never override the repository's Git identity" "$PLUGIN/skills" 2>/dev/null
check $? "commit authorship rule is stated to the Coordinator"

echo "== references resolve"

# Every ${CLAUDE_PLUGIN_ROOT}/... path mentioned anywhere must exist. A typo here
# is invisible until a Run reaches that phase and finds nothing.
missing=0
refs=$(grep -rhoE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9._/-]+' "$PLUGIN" | sort -u)
for ref in $refs; do
  rel=${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}
  if [ ! -e "$PLUGIN/$rel" ]; then
    fail "broken reference: $rel"
    missing=$((missing + 1))
  fi
done
[ "$missing" = "0" ] && pass "all plugin-root references resolve"

# Codex instructions bind <pluginRoot> to the installed package root. Every
# concrete path written in that form must resolve inside the package.
missing=0
refs=$(grep -rhoE '<pluginRoot>/[A-Za-z0-9._/-]+' "$CODEX_PLUGIN" | sort -u)
for ref in $refs; do
  rel=${ref#<pluginRoot>/}
  if [ ! -e "$CODEX_PLUGIN/$rel" ]; then
    fail "broken Codex plugin reference: $rel"
    missing=$((missing + 1))
  fi
done
[ "$missing" = "0" ] && pass "all Codex plugin-root references resolve"

echo "== static plugin"

# The spec forbids shipping a runtime. These are the files that would mean one.
found=$(find "$PLUGIN" \( \
  -name package.json -o -name node_modules -o -name '*.js' -o -name '*.mjs' -o \
  -name '*.ts' -o -name '*.py' -o -name '*.sh' -o -name 'hooks.json' -o \
  -name '.mcp.json' -o -name requirements.txt -o -name pyproject.toml \) -print)
if [ -n "$found" ]; then
  printf 'FAIL runtime artifact in installed plugin:\n%s\n' "$found"
  fails=$((fails + 1))
else
  pass "installed plugin is static"
fi

found=$(find "$CODEX_PLUGIN" \( \
  -name package.json -o -name node_modules -o -name '*.js' -o -name '*.mjs' -o \
  -name '*.ts' -o -name '*.py' -o -name '*.sh' -o -name 'hooks.json' -o \
  -name '.mcp.json' -o -name requirements.txt -o -name pyproject.toml \) -print)
if [ -n "$found" ]; then
  printf 'FAIL runtime artifact in Codex plugin:\n%s\n' "$found"
  fails=$((fails + 1))
else
  pass "Codex plugin is static"
fi

if grep -rilq 'specseam' "$PLUGIN" 2>/dev/null; then
  fail "inherited terminology 'specseam' present in plugin"
else
  pass "no inherited terminology"
fi

if grep -rilq 'specseam' "$CODEX_PLUGIN" 2>/dev/null; then
  fail "inherited terminology 'specseam' present in Codex plugin"
else
  pass "Codex plugin has no inherited terminology"
fi

if grep -rilqE 'claude|sonnet|opus|hybrid' "$CODEX_PLUGIN" 2>/dev/null; then
  fail "Codex plugin contains another host, model family, or mixed-runtime term"
else
  pass "Codex plugin is Codex-only"
fi

echo "== shared assets stay in parity"

for f in \
  internal/checklists/review.md \
  internal/checklists/architecture.md \
  internal/checklists/implementation.md \
  internal/contracts/build-result.schema.json \
  internal/contracts/challenge-result.schema.json \
  internal/contracts/review-result.schema.json \
  internal/contracts/commit-result.schema.json \
  internal/prompts/build.tpl \
  internal/prompts/challenge.tpl \
  internal/prompts/plan-check.tpl \
  internal/prompts/qa.tpl \
  internal/prompts/commit.tpl \
  internal/templates/documents/audit.md.tpl \
  internal/templates/documents/delivery.md.tpl \
  internal/templates/documents/discovery.md.tpl \
  internal/templates/documents/plan.md.tpl \
  internal/templates/documents/research.md.tpl \
  internal/templates/documents/validation.md.tpl; do
  cmp -s "$PLUGIN/$f" "$CODEX_PLUGIN/$f"
  check $? "shared asset matches: $f"
done

# The reference guides are one body of text with two homes. Listing them by name
# would rot the moment a guide is added, so compare the directories wholesale.
if diff -rq "$PLUGIN/internal/references" "$CODEX_PLUGIN/internal/references" >/dev/null 2>&1; then
  pass "reference guides match across distributions"
else
  fail "reference guides differ across distributions"
fi

echo "== reference guides are attributed and reachable"

# The guides are third-party MIT text. Redistributing them without the upstream
# copyright is the one defect here that is not a quality problem.
grep -q 'Copyright (c) 2025 awesome-skills' "$PLUGIN/internal/references/NOTICE.md"
check $? "upstream copyright is preserved"

grep -q 'Permission is hereby granted' "$PLUGIN/internal/references/NOTICE.md"
check $? "upstream license text is preserved"

# README.md is the only map from a stack or a concern to a file. An entry
# pointing at nothing fails the same way a bad ${CLAUDE_PLUGIN_ROOT} path does:
# invisibly, and only once a Run reaches it.
missing=
for ref in $(grep -oE '`[a-z0-9./-]+\.md`' "$PLUGIN/internal/references/README.md" |
             tr -d '`' | grep -v '^checklists/' | sort -u); do
  [ -f "$PLUGIN/internal/references/$ref" ] || missing="$missing $ref"
done
[ -z "$missing" ]
check $? "every guide the reference index names exists${missing:+ (missing:$missing)}"

# And the reverse: a guide nobody can find is a guide nobody loads.
unindexed=
for f in $(cd "$PLUGIN/internal/references" && find . -name '*.md' \
           ! -name README.md ! -name NOTICE.md | sed 's|^\./||' | sort); do
  grep -q "\`$f\`" "$PLUGIN/internal/references/README.md" || unindexed="$unindexed $f"
done
[ -z "$unindexed" ]
check $? "every guide is reachable from the index${unindexed:+ (unindexed:$unindexed)}"

echo "== the audit reaches the widest checklist surface"

# An audit has no diff pointing it anywhere, so it is the mode that depends most
# on the checklists and least on what the subject volunteers. Each link below is
# a line an edit could drop while leaving prose that still reads correctly.
for p in "$PLUGIN" "$CODEX_PLUGIN"; do
  label=$([ "$p" = "$PLUGIN" ] && echo plugin || echo Codex)

  for c in architecture implementation review; do
    grep -q "checklists/$c.md" "$p/skills/audit/SKILL.md"
    check $? "$label: the audit command dispatches against checklists/$c.md"
  done

  grep -q 'internal/references/' "$p/skills/audit/SKILL.md"
  check $? "$label: the audit command reaches the stack guides"

  # The Worker has to know the two extra checklists are its scope in audit mode
  # and nowhere else, or they either go unread or widen every other review.
  grep -q 'In `audit` mode two more checklists are yours' "$p/internal/prompts/change-check.tpl"
  check $? "$label: the audit Worker is told which checklists widen its scope"

  grep -q 'In every other mode the diff is your scope' "$p/internal/prompts/change-check.tpl"
  check $? "$label: the extra checklists do not widen a diff review"

  grep -q 'widest checklist surface of any mode' "$p/internal/stages/review.md"
  check $? "$label: audit mode states why it carries more checklist than a diff"
done

# Both checklists are read by a writer and by an audit, and the two readings have
# different burdens of proof. A file that forgets the second one gets applied to
# shipped code as though it were a standard for new code.
for c in architecture implementation; do
  grep -q 'audit' "$PLUGIN/internal/checklists/$c.md"
  check $? "checklists/$c.md says how an audit reads it"
done

echo
if [ "$fails" -gt 0 ]; then
  printf '%s check(s) failed\n' "$fails"
  exit 1
fi
echo "all checks passed"
