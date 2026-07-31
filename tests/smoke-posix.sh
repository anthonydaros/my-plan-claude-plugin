#!/bin/sh
# Static checks for the My Plan plugin. Development only; never installed.
# Fails on anything that would break plugin loading or violate the frozen spec.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PLUGIN="$ROOT/plugin"
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

for m in "$ROOT/.claude-plugin/marketplace.json" "$PLUGIN/.claude-plugin/plugin.json"; do
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

echo "== agents"

# Filename and frontmatter name must agree: the host lists agents by filename,
# so a mismatch makes the agent unaddressable by the name its prompt claims.
for a in discovery planner implementer reviewer; do
  f="$PLUGIN/agents/my-plan-$a.md"
  if [ ! -f "$f" ]; then fail "missing $f"; continue; fi

  frontmatter "$f" | grep -q "^name: my-plan-$a\$"
  check $? "agent $a name matches its filename"

  frontmatter "$f" | grep -q "^tools: \["
  check $? "agent $a declares a bounded tool list"
done

# The writer/reviewer boundary is the one invariant a prompt edit could silently
# break, so it gets its own check rather than trusting review. The reviewer
# reviews both plans and code, so it is the one that must never gain a write tool.
for a in discovery reviewer; do
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

# Plan author and plan reviewer must not be the same model, and neither must the
# code author and the code reviewer. Same-model review is the failure this whole
# product exists to prevent.
author=$(frontmatter "$PLUGIN/agents/my-plan-planner.md" | grep '^model:' | cut -d' ' -f2)
critic=$(frontmatter "$PLUGIN/agents/my-plan-reviewer.md" | grep '^model:' | cut -d' ' -f2)
coder=$(frontmatter "$PLUGIN/agents/my-plan-implementer.md" | grep '^model:' | cut -d' ' -f2)
[ "$author" != "$critic" ]
check $? "plan author ($author) differs from reviewer ($critic)"
[ "$coder" != "$critic" ]
check $? "code author ($coder) differs from reviewer ($critic)"

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
  internal/contracts/handoff.schema.json \
  internal/contracts/challenge-result.schema.json \
  internal/contracts/review-result.schema.json \
  internal/contracts/build-result.schema.json \
  internal/checklists/review.md \
  internal/templates/project-skill.md.tpl; do
  [ -f "$PLUGIN/$f" ]
  check $? "exists: $f"
done

for d in discovery research spec plan implementation validation review audit delivery; do
  [ -f "$PLUGIN/internal/templates/documents/$d.md.tpl" ]
  check $? "exists: documents/$d.md.tpl"
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

echo "== contracts are strict-mode clean"

# Provider-enforced structured output rejects the request with HTTP 400 before the
# model runs if any property lacks "type", or if "required" omits any key in
# "properties" at any depth. Both have bitten this repo. Optional fields are
# nullable and still required.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$PLUGIN/internal/contracts" <<'PY'
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

for path in sorted(pathlib.Path(sys.argv[1]).glob("*.json")):
    walk(json.load(path.open()), path.name)

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

if grep -rilq 'specseam' "$PLUGIN" 2>/dev/null; then
  fail "inherited terminology 'specseam' present in plugin"
else
  pass "no inherited terminology"
fi

echo
if [ "$fails" -gt 0 ]; then
  printf '%s check(s) failed\n' "$fails"
  exit 1
fi
echo "all checks passed"
