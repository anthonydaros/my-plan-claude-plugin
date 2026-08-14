#!/bin/sh
# Static checks for the My Plan plugin. Development only; never installed.
# Fails on anything that would break plugin loading or quietly reopen a
# guarantee this plugin exists to keep.
#
# Deliberately not `set -e`. Every check here runs a command and hands its
# status to check(), which counts the failure and keeps going; under `set -e`
# the shell exits on that same failing command instead, so the first broken
# invariant aborts the run before check() is ever reached. The failure count
# at the end is what decides the exit status.
set -u

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

SKILLS="map plan implement review commit cleanup security"

echo "== manifests"

for m in \
  "$ROOT/.claude-plugin/marketplace.json" \
  "$PLUGIN/.claude-plugin/plugin.json" \
  "$ROOT/.agents/plugins/marketplace.json" \
  "$PLUGIN/.codex-plugin/plugin.json" \
  "$PLUGIN/plugin.json"; do
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
check $? "Claude plugin name is my-plan"

has "$ROOT/.claude-plugin/marketplace.json" '"source": "./plugin"'
check $? "Claude marketplace publishes ./plugin"

has "$PLUGIN/.codex-plugin/plugin.json" '"name": "my-plan"'
check $? "Codex plugin name is my-plan"

# Pin the shape, not the number: the Codex host resolves updates by semantic
# version, so a release must be able to bump this without editing a test.
grep -qE '"version": "[0-9]+\.[0-9]+\.[0-9]+(\+[0-9A-Za-z.-]+)?"' "$PLUGIN/.codex-plugin/plugin.json"
check $? "Codex plugin declares a semantic version"

has "$PLUGIN/.codex-plugin/plugin.json" '"skills": "./skills/"'
check $? "Codex manifest publishes only its skill root"

if grep -Eq '"(mcpServers|hooks)"[[:space:]]*:' "$PLUGIN/.codex-plugin/plugin.json"; then
  fail "Codex manifest must not declare MCP servers or hooks"
else
  pass "Codex manifest has no MCP servers or hooks"
fi

has "$ROOT/.agents/plugins/marketplace.json" '"name": "my-plan-codex"'
check $? "Codex marketplace name is my-plan-codex"

has "$ROOT/.agents/plugins/marketplace.json" '"path": "./plugin"'
check $? "Codex marketplace publishes ./plugin"

has "$ROOT/.agents/plugins/marketplace.json" '"installation": "AVAILABLE"'
check $? "Codex marketplace installation policy is AVAILABLE"

has "$ROOT/.agents/plugins/marketplace.json" '"authentication": "ON_INSTALL"'
check $? "Codex marketplace authentication policy is ON_INSTALL"

has "$ROOT/.agents/plugins/marketplace.json" '"category": "Development"'
check $? "Codex marketplace category is Development"

# The Antigravity manifest sits at the plugin root — the location that
# host's installer requires — and mirrors the field shape Google's own
# plugins ship.
has "$PLUGIN/plugin.json" '"name": "my-plan"'
check $? "Antigravity plugin name is my-plan"

grep -q '"description"' "$PLUGIN/plugin.json"
check $? "Antigravity manifest has a description"

# Three manifests describing one artifact must agree, or one of them is
# stale the moment a release bumps only the others.
claude_version=$(sed -n 's/.*"version": *"\([0-9][0-9.]*\)".*/\1/p' "$PLUGIN/.claude-plugin/plugin.json" | head -1)
codex_version=$(sed -n 's/.*"version": *"\([0-9][0-9.]*\)".*/\1/p' "$PLUGIN/.codex-plugin/plugin.json" | head -1)
agy_version=$(sed -n 's/.*"version": *"\([0-9][0-9.]*\)".*/\1/p' "$PLUGIN/plugin.json" | head -1)
[ -n "$claude_version" ] && [ "$claude_version" = "$codex_version" ] && [ "$claude_version" = "$agy_version" ]
check $? "all three manifests declare the same version (claude:$claude_version codex:$codex_version antigravity:$agy_version)"

echo "== the 7 skills are independent and manual-only"

for s in $SKILLS; do
  f="$PLUGIN/skills/$s/SKILL.md"
  meta="$PLUGIN/skills/$s/agents/openai.yaml"
  if [ ! -f "$f" ]; then fail "missing $f"; continue; fi
  if [ ! -f "$meta" ]; then fail "missing $meta"; continue; fi

  frontmatter "$f" | grep -q "^name: $s\$"
  check $? "$s declares name: $s"

  frontmatter "$f" | grep -q "^description: ."
  check $? "$s has a description"

  frontmatter "$f" | grep -q "^argument-hint: ."
  check $? "$s declares an argument-hint"

  frontmatter "$f" | grep -q "^disable-model-invocation: true\$"
  check $? "$s is manual only in Claude Code"

  has "$f" '$ARGUMENTS'
  check $? "$s consumes \$ARGUMENTS"

  has "$meta" 'allow_implicit_invocation: false'
  check $? "$s is manual only in Codex CLI"

  has "$meta" "\$my-plan:$s"
  check $? "$s metadata names its invocation"

  # The Google hosts have no enforcement field, so the guarantee there is
  # these two sentences in the body — the argument fallback and the guard
  # that stops an implicit activation.
  has "$f" 'Antigravity, and Gemini CLI do not substitute'
  check $? "$s tells the Google hosts how to read its arguments"

  has "$f" 'the user explicitly invoking it'
  check $? "$s carries the manual-only guard for hosts with no enforcement switch"
done

# No push skill exists, and nothing may reintroduce one under another name.
if [ -d "$PLUGIN/skills/push" ]; then
  fail "a push skill exists — the plugin has none by design"
else
  pass "no push skill exists"
fi

# Exactly these 7 skills exist — no orchestration-era command left behind,
# and nothing extra added without updating this list.
found_skills=$(ls "$PLUGIN/skills" 2>/dev/null | sort | tr '\n' ' ')
expected_skills=$(printf '%s\n' $SKILLS | sort | tr '\n' ' ')
[ "$found_skills" = "$expected_skills" ]
check $? "skills/ contains exactly the 7 skills (found:$found_skills)"

echo "== the shared SKILL.md body has no per-host path variable"

# The one thing that used to force two divergent SKILL.md bodies was a
# per-host root variable. Every knowledge/agent reference is now a plain
# relative path, so neither variable should appear anywhere.
if grep -rq '\${CLAUDE_PLUGIN_ROOT}\|<pluginRoot>' "$PLUGIN" 2>/dev/null; then
  fail "a per-host plugin-root variable still appears somewhere in plugin/"
else
  pass "no \${CLAUDE_PLUGIN_ROOT} or <pluginRoot> anywhere in plugin/"
fi

echo "== relative knowledge/agent references resolve"

# Every ../../knowledge/... or ../../agents/... reference in a SKILL.md must
# resolve from that file's own directory. This is what lets one shared body
# work under both Claude Code and Codex CLI with no build step.
missing=0
for f in "$PLUGIN"/skills/*/SKILL.md; do
  dir=$(dirname "$f")
  for rel in $(grep -oE '\.\./\.\./(knowledge|agents)/[A-Za-z0-9._/-]+' "$f" | sort -u); do
    if [ ! -e "$dir/$rel" ]; then
      fail "broken reference in ${f#"$ROOT"/}: $rel"
      missing=$((missing + 1))
    fi
  done
done
[ "$missing" = "0" ] && pass "every relative knowledge/agent reference resolves"

# A skill referencing a sibling skill's body (implement chains review and
# commit by reference) uses ../<skill>/SKILL.md — one level up, not two.
# Check the wrong-depth form first: the substring ../<skill>/SKILL.md
# inside a broken ../../<skill>/SKILL.md would still match and resolve,
# masking the bug.
missing=0
for f in "$PLUGIN"/skills/*/SKILL.md; do
  dir=$(dirname "$f")
  if grep -qE '\.\./\.\./[a-z-]+/SKILL\.md' "$f"; then
    fail "skill ${f#"$ROOT"/} references a sibling skill with ../../ — siblings sit one level up"
    missing=$((missing + 1))
  fi
  for rel in $(grep -oE '\.\./[a-z-]+/SKILL\.md' "$f" | sort -u); do
    if [ ! -e "$dir/$rel" ]; then
      fail "broken sibling-skill reference in ${f#"$ROOT"/}: $rel"
      missing=$((missing + 1))
    fi
  done
done
[ "$missing" = "0" ] && pass "every sibling-skill reference resolves at the right depth"

# Agents sit one level shallower than skills (plugin/agents/, not
# plugin/skills/<name>/), so the same reference from an agent file must use
# ../knowledge/ or ../agents/, never ../../. Check the wrong-depth form
# first: without it, the substring ../knowledge/... inside a broken
# ../../knowledge/... would still match and resolve, masking the bug.
missing=0
for f in "$PLUGIN"/agents/*.md; do
  dir=$(dirname "$f")
  if grep -qE '\.\./\.\./(knowledge|agents)/' "$f"; then
    fail "agent ${f#"$ROOT"/} uses ../../ — agents sit one level shallower than skills"
    missing=$((missing + 1))
  fi
  for rel in $(grep -oE '\.\./(knowledge|agents)/[A-Za-z0-9._/-]+' "$f" | sort -u); do
    if [ ! -e "$dir/$rel" ]; then
      fail "broken reference in ${f#"$ROOT"/}: $rel"
      missing=$((missing + 1))
    fi
  done
done
[ "$missing" = "0" ] && pass "every relative knowledge/agent reference in agents/ resolves at the right depth"

echo "== agents"

# Filename and frontmatter name must agree: the host lists agents by
# filename, so a mismatch makes the agent unaddressable by the name its own
# prompt claims.
for a in reviewer committer; do
  f="$PLUGIN/agents/my-plan-$a.md"
  if [ ! -f "$f" ]; then fail "missing $f"; continue; fi

  frontmatter "$f" | grep -q "^name: my-plan-$a\$"
  check $? "agent $a name matches its filename"

  frontmatter "$f" | grep -q "^tools: \["
  check $? "agent $a declares a bounded tool list"

  # Effort is not overridable per dispatch, so whatever the file declares is
  # what runs. An unrecognized value is dropped by the host and the Worker
  # silently falls back to the session's effort.
  frontmatter "$f" | grep -qE "^effort: (low|medium|high|xhigh|max)\$"
  check $? "agent $a declares a valid effort"

  if frontmatter "$f" | grep -qE '^tools: \[.*(Write|Edit|NotebookEdit)'; then
    fail "agent $a must not hold a file-editing tool"
  else
    pass "agent $a holds no file-editing tool"
  fi
done

# Exactly these 2 native agents exist — no leftover planner, implementer,
# discovery, or reviewer-deep from the orchestration era.
found_agents=$(ls "$PLUGIN/agents" 2>/dev/null | sort | tr '\n' ' ')
[ "$found_agents" = "my-plan-committer.md my-plan-reviewer.md " ]
check $? "agents/ contains exactly the 2 native agents (found:$found_agents)"

[ -f "$PLUGIN/LICENSE" ]
check $? "exists: LICENSE (NOTICE.md points installs at this file)"

echo "== knowledge assets exist"

for f in \
  knowledge/checklists/review.md \
  knowledge/checklists/architecture.md \
  knowledge/checklists/implementation.md \
  knowledge/checklists/cleanup.md \
  knowledge/checklists/cleanup-code.md \
  knowledge/checklists/cleanup-residue.md \
  knowledge/checklists/cleanup-docs.md \
  knowledge/checklists/cleanup-refactor.md \
  knowledge/checklists/secrets-patterns.md \
  knowledge/checklists/security.md \
  knowledge/checklists/security-secrets.md \
  knowledge/checklists/security-deps.md \
  knowledge/checklists/security-code.md \
  knowledge/checklists/security-config.md \
  knowledge/references/README.md \
  knowledge/references/NOTICE.md \
  knowledge/templates/brief.md \
  knowledge/templates/plan.md \
  knowledge/templates/task.md \
  knowledge/templates/report.md; do
  [ -f "$PLUGIN/$f" ]
  check $? "exists: $f"
done

echo "== push is gated, commits are scanned"

# Only skills/commit/SKILL.md may mention a literal push at all, and it must
# mention it only to forbid it or to print the command for the user to run.
offenders=$(grep -rl 'git push' "$PLUGIN/skills" "$PLUGIN/agents" 2>/dev/null | \
  grep -v '^'"$PLUGIN"'/skills/commit/SKILL.md$' | \
  grep -v '^'"$PLUGIN"'/agents/my-plan-committer.md$')
if [ -n "$offenders" ]; then
  fail "git push mentioned outside commit's skill/agent: $offenders"
else
  pass "git push is mentioned only in commit's skill and agent"
fi

has "$PLUGIN/skills/commit/SKILL.md" 'Never `git push`'
check $? "commit states it never pushes"

has "$PLUGIN/skills/commit/SKILL.md" 'git push <remote> <branch>'
check $? "commit prints the push command for the user to run"

# Fixed-string search: these are literal patterns in the doc, not regexes to
# run. The list itself lives in secrets-patterns.md, shared with `security`;
# commit/SKILL.md must point there rather than carry a second copy.
for pattern in 'PRIVATE KEY' 'AKIA' 'api[_-]?key' '.env' 'bearer '; do
  grep -qF -- "$pattern" "$PLUGIN/knowledge/checklists/secrets-patterns.md"
  check $? "secret scan names $pattern"
done

has "$PLUGIN/skills/commit/SKILL.md" 'secrets-patterns.md'
check $? "commit points at the shared secret-pattern list, not a second copy"

has "$PLUGIN/skills/commit/SKILL.md" "Never override the repository's configured"
check $? "commit authorship rule is stated"

echo "== security never remediates"

has "$PLUGIN/skills/security/SKILL.md" 'no `--fix`'
check $? "security states it has no --fix"

frontmatter "$PLUGIN/skills/security/SKILL.md" | grep -q '^argument-hint: "\[path\]"$'
check $? "security's argument-hint carries no --fix"

if grep -qE -- '--fix' "$PLUGIN/skills/security/agents/openai.yaml" 2>/dev/null; then
  fail "security's Codex sidecar mentions --fix"
else
  pass "security's Codex sidecar mentions no --fix"
fi

echo "== the implement chain stays bounded and gated"

# implement chains review and commit inside one invocation. The chain must
# gate the commit on a green review, bound its own loop, stop at the task
# it was invoked on, and defer to the sibling skills' own bodies rather
# than carrying a second copy of either.
f="$PLUGIN/skills/implement/SKILL.md"

has "$f" 'no `blocker` findings'
check $? "implement gates the chained commit on a blocker-free review round"

has "$f" 'Three review rounds is the bound'
check $? "implement bounds its fix loop"

has "$f" 'never starts the next task'
check $? "implement stops at the task it was invoked on"

has "$f" '--solo'
check $? "implement offers --solo to stop after the build"

has "$f" '../review/SKILL.md'
check $? "implement chains review by reference, not by copy"

has "$f" '../commit/SKILL.md'
check $? "implement chains commit by reference, not by copy"

has "$PLUGIN/skills/commit/SKILL.md" '--changelog'
check $? "commit accepts --changelog so the chain never stalls on the ask"

echo "== the closing-note convention holds"

# Every mutating or evaluative skill ends with the same four labels, printed
# to the conversation, so a user driving these one at a time always sees
# what changed, what was checked, and what's open.
for s in $SKILLS; do
  f="$PLUGIN/skills/$s/SKILL.md"
  for label in 'Changed:' 'Validated:' 'Open risks:' 'Suggested next skill:'; do
    has "$f" "$label"
    check $? "$s closing note has '$label'"
  done
done

echo "== the declared-blindness convention holds"

# review and commit each take an optional pointer to a brief or task file,
# and each says plainly when neither exists rather than silently skipping
# conformance and scope-drift checking.
for s in review commit; do
  f="$PLUGIN/skills/$s/SKILL.md"
  has "$f" '--spec'
  check $? "$s accepts --spec"
  has "$f" 'not evaluated'
  check $? "$s declares blindness plainly when nothing was supplied"
done

echo "== independence is stated for every host"

# The reviewer/committer subagent boundary is real in Claude Code and only a
# self-declaration in Codex CLI and Antigravity. Both must be stated, and the
# asymmetry must not be papered over. implement is in this list because its
# chain dispatches the same reviewer and committer.
for s in plan implement review commit cleanup security; do
  f="$PLUGIN/skills/$s/SKILL.md"
  has "$f" '**Claude Code.**'
  check $? "$s states its Claude Code independence mechanism"
  has "$f" '**Codex CLI / Antigravity.**'
  check $? "$s states its Codex CLI / Antigravity independence mechanism"
done

echo "== commits stay the user's"

# A plugin that writes commits into other people's repositories must never
# sign them with anything but the repository's own identity.
if grep -rq "Co-Authored-By:" "$PLUGIN" 2>/dev/null; then
  fail "plugin contains a literal Co-Authored-By trailer"
else
  pass "no Co-Authored-By trailer anywhere"
fi

echo "== static plugin"

# The spec forbids shipping a runtime. These are the files that would mean
# one. Note tests/ itself is a sibling of plugin/, not inside it, so this
# scan never trips on its own POSIX/PowerShell scripts.
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

echo "== reference guides are attributed and reachable"

# The guides are third-party MIT text. Redistributing them without the
# upstream copyright is the one defect here that is not a quality problem.
grep -q 'Copyright (c) 2025 awesome-skills' "$PLUGIN/knowledge/references/NOTICE.md"
check $? "upstream copyright is preserved"

grep -q 'Permission is hereby granted' "$PLUGIN/knowledge/references/NOTICE.md"
check $? "upstream license text is preserved"

# README.md is the only map from a stack or a concern to a file. An entry
# pointing at nothing fails the same way a bad relative reference does:
# invisibly, and only once someone reaches it.
missing=
for ref in $(grep -oE '`[a-z0-9./-]+\.md`' "$PLUGIN/knowledge/references/README.md" |
             tr -d '`' | grep -v '^checklists/' | sort -u); do
  [ -f "$PLUGIN/knowledge/references/$ref" ] || missing="$missing $ref"
done
[ -z "$missing" ]
check $? "every guide the reference index names exists${missing:+ (missing:$missing)}"

# And the reverse: a guide nobody can find is a guide nobody loads.
unindexed=
for f in $(cd "$PLUGIN/knowledge/references" && find . -name '*.md' \
           ! -name README.md ! -name NOTICE.md | sed 's|^\./||' | sort); do
  grep -q "\`$f\`" "$PLUGIN/knowledge/references/README.md" || unindexed="$unindexed $f"
done
[ -z "$unindexed" ]
check $? "every guide is reachable from the index${unindexed:+ (unindexed:$unindexed)}"

echo
if [ "$fails" -gt 0 ]; then
  printf '%s check(s) failed\n' "$fails"
  exit 1
fi
echo "all checks passed"
