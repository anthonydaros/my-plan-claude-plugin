# Static checks for the My Plan plugin on Windows. Development only.
# Content checks that are platform-independent live in smoke-posix.sh and run on
# Linux and macOS. This script covers what only Windows can prove: that the paths
# resolve and the manifests load under PowerShell.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$plugin = Join-Path $root 'plugin'
$codexPlugin = Join-Path $root 'codex-plugin'
$fails = 0

function Check([bool]$ok, [string]$label) {
    if ($ok) { Write-Host "ok   $label" }
    else { Write-Host "FAIL $label"; $script:fails++ }
}

function Frontmatter([string]$path) {
    $lines = Get-Content -LiteralPath $path
    if ($lines[0] -ne '---') { return @() }
    $end = 1
    while ($end -lt $lines.Count -and $lines[$end] -ne '---') { $end++ }
    return $lines[1..($end - 1)]
}

Write-Host '== manifests'

foreach ($m in @(
        (Join-Path $root '.claude-plugin\marketplace.json'),
        (Join-Path $plugin '.claude-plugin\plugin.json'),
        (Join-Path $root '.agents\plugins\marketplace.json'),
        (Join-Path $codexPlugin '.codex-plugin\plugin.json'))) {
    $name = $m.Substring($root.Length + 1)
    if (-not (Test-Path -LiteralPath $m)) { Check $false "missing $name"; continue }
    try {
        Get-Content -LiteralPath $m -Raw | ConvertFrom-Json | Out-Null
        Check $true "valid JSON: $name"
    } catch {
        Check $false "valid JSON: $name"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $plugin '.claude-plugin\plugin.json') -Raw | ConvertFrom-Json
Check ($manifest.name -eq 'my-plan') 'plugin name is my-plan'

$market = Get-Content -LiteralPath (Join-Path $root '.claude-plugin\marketplace.json') -Raw | ConvertFrom-Json
Check ($market.plugins[0].source -eq './plugin') 'marketplace publishes ./plugin'

$codexManifest = Get-Content -LiteralPath (Join-Path $codexPlugin '.codex-plugin\plugin.json') -Raw | ConvertFrom-Json
Check ($codexManifest.name -eq 'my-plan') 'Codex plugin name is my-plan'
Check ($codexManifest.version -eq '0.1.0') 'Codex plugin version is 0.1.0'
Check ($codexManifest.skills -eq './skills/') 'Codex manifest publishes only its skill root'
Check (-not ($codexManifest.PSObject.Properties.Name -contains 'mcpServers')) 'Codex manifest has no MCP servers'
Check (-not ($codexManifest.PSObject.Properties.Name -contains 'hooks')) 'Codex manifest has no hooks'

$codexMarket = Get-Content -LiteralPath (Join-Path $root '.agents\plugins\marketplace.json') -Raw | ConvertFrom-Json
Check ($codexMarket.name -eq 'my-plan-codex') 'Codex marketplace name is my-plan-codex'
Check ($codexMarket.plugins[0].source.path -eq './codex-plugin') 'Codex marketplace publishes ./codex-plugin'
Check ($codexMarket.plugins[0].policy.installation -eq 'AVAILABLE') 'Codex marketplace installation policy is AVAILABLE'
Check ($codexMarket.plugins[0].policy.authentication -eq 'ON_INSTALL') 'Codex marketplace authentication policy is ON_INSTALL'
Check ($codexMarket.plugins[0].category -eq 'Development') 'Codex marketplace category is Development'

Write-Host '== public skills'

foreach ($s in @('install', 'start', 'audit')) {
    $f = Join-Path $plugin "skills\$s\SKILL.md"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing $s"; continue }
    $fm = Frontmatter $f
    Check ([bool]($fm -contains "name: $s")) "$s declares name: $s"
    Check ([bool]($fm -contains 'disable-model-invocation: true')) "$s is manual only"
    Check ((Get-Content -LiteralPath $f -Raw) -like '*$ARGUMENTS*') "$s consumes `$ARGUMENTS"
}

Write-Host '== Codex public skills'

foreach ($s in @('install', 'start', 'audit')) {
    $f = Join-Path $codexPlugin "skills\$s\SKILL.md"
    $meta = Join-Path $codexPlugin "skills\$s\agents\openai.yaml"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing Codex skill $s"; continue }
    if (-not (Test-Path -LiteralPath $meta)) { Check $false "missing Codex metadata $s"; continue }
    $fm = @(Frontmatter $f | Where-Object { $_.Trim() -ne '' })
    Check ([bool]($fm -contains "name: $s")) "Codex $s declares name: $s"
    Check ([bool]($fm -match '^description: .')) "Codex $s has a description"
    Check ($fm.Count -eq 2) "Codex $s frontmatter contains only name and description"
    $metaText = Get-Content -LiteralPath $meta -Raw
    Check ($metaText.Contains('allow_implicit_invocation: false')) "Codex $s is manual only"
    Check ($metaText.Contains("`$my-plan:$s")) "Codex $s metadata names its invocation"
}

Write-Host '== agents'

foreach ($a in @('discovery', 'planner', 'implementer', 'reviewer', 'reviewer-deep', 'committer')) {
    $f = Join-Path $plugin "agents\my-plan-$a.md"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing agent $a"; continue }
    $fm = Frontmatter $f
    Check ([bool]($fm -contains "name: my-plan-$a")) "agent $a name matches its filename"
    Check ([bool]($fm -match '^effort: (low|medium|high|xhigh|max)$')) "agent $a declares a valid effort"
}

# The reviewer reviews both plans and code, so it is the one that must never gain
# a write tool. The planner writes the plan; the implementer writes the code.
foreach ($a in @('discovery', 'reviewer', 'reviewer-deep')) {
    $tools = (Frontmatter (Join-Path $plugin "agents\my-plan-$a.md")) -match '^tools:'
    Check (-not ($tools -match '(Write|Edit|NotebookEdit)')) "agent $a is read-only"
}

foreach ($a in @('implementer', 'planner')) {
    $tools = (Frontmatter (Join-Path $plugin "agents\my-plan-$a.md")) -match '^tools:'
    Check ([bool]($tools -match 'Write')) "$a can write"
}

# The committer writes history, not files. One that can edit could repair what the
# secret scan just refused, which is the one refusal that must not be negotiable.
$tools = (Frontmatter (Join-Path $plugin 'agents\my-plan-committer.md')) -match '^tools:'
Check (-not ($tools -match '(Write|Edit|NotebookEdit)')) 'committer edits no files'

# Not every code-graph MCP tool is read-only, and none of their names carries a
# Write or Edit for the checks above to catch. apply_refactor_tool edits source,
# the wiki tools write a second architecture record, three write the index, and
# two reach other repositories. refactor_tool matches apply_refactor_tool as a
# substring, so one pattern covers both.
$graphWriters = '(refactor_tool|generate_wiki_tool|get_wiki_page_tool|build_or_update_graph_tool|run_postprocess_tool|embed_graph_tool|list_repos_tool|cross_repo_search_tool)'
foreach ($a in @('discovery', 'planner', 'implementer', 'reviewer', 'reviewer-deep', 'committer')) {
    $tools = (Frontmatter (Join-Path $plugin "agents\my-plan-$a.md")) -match '^tools:'
    Check (-not ($tools -match $graphWriters)) "agent $a holds no writing or cross-repo graph tool"
}

# The committer runs Git and scans for secrets. It has no codebase to read.
$tools = (Frontmatter (Join-Path $plugin 'agents\my-plan-committer.md')) -match '^tools:'
Check (-not ($tools -match 'mcp__code-review-graph__')) 'committer queries no code graph'

# The graph is an index, not an authority, and its module is the only place that
# boundary is written down.
foreach ($p in @($plugin, $codexPlugin)) {
    $label = if ($p -eq $plugin) { 'plugin' } else { 'Codex' }
    $graphDoc = Get-Content -LiteralPath (Join-Path $p 'internal\code-graph.md') -Raw

    Check ($graphDoc.Contains('The graph never decides a verdict, a write set, a hash, or a gate.')) "$($label): the graph orients a phase, it does not decide one"
    Check ($graphDoc.Contains('rebuilds against the worktree before trusting it')) "$($label): the graph is revalidated against the worktree per phase"
    Check ($graphDoc.Contains('The index lives outside the repository')) "$($label): the graph index stays out of the user's checkout"
    Check ($graphDoc.Contains('Never enable a cloud embedding provider without asking')) "$($label): cloud embeddings need the user, not a default"
    Check ($graphDoc.Contains('--no-instructions --no-skills --no-hooks')) "$($label): provisioning never edits canonical docs, hooks, or skills"
    Check ($graphDoc.Contains('CRG_TOOLS')) "$($label): the transport bounds what a non-agent-file Worker can reach"
}

Write-Host '== provisioning checks before it installs'

# The executable and the MCP entry are machine-wide; only the index belongs to a
# repository. One probe asking "does this repository have a graph?" answers no in
# every new repository, and acting on that reinstalls what the user already has.
foreach ($p in @($plugin, $codexPlugin)) {
    $label = if ($p -eq $plugin) { 'plugin' } else { 'Codex' }
    $graphDoc = Get-Content -LiteralPath (Join-Path $p 'internal\code-graph.md') -Raw
    $projectStage = Get-Content -LiteralPath (Join-Path $p 'internal\stages\project.md') -Raw
    $installSkill = Get-Content -LiteralPath (Join-Path $p 'skills\install\SKILL.md') -Raw

    Check ($graphDoc.Contains('three separate probes, and only the third is per-repository')) "$($label): provisioning separates the machine-wide layers from the repository one"
    Check ($graphDoc.Contains('Probe each layer before touching it, and skip every layer')) "$($label): each layer is probed before it is touched"
    Check ($graphDoc.Contains('not rewrite it, do not normalize it, and do not re-run')) "$($label): an already-configured MCP entry is left alone"
    Check ($projectStage.Contains('Probe the three layers separately, and provision only what is missing')) "$($label): setup provisions only the layers that failed"
    Check ($projectStage.Contains('"mcpEntry"')) "$($label): the profile remembers the machine-wide layers across repositories"
    Check ($installSkill.Contains('Check before installing anything, and probe each layer separately')) "$($label): the install command states the check-first rule"
    Check ($installSkill.Contains('named exception: the code graph')) "$($label): the no-install rule names its one exception"
}

# Same-model review is the failure this product exists to prevent.
function ModelOf([string]$agent) {
    $line = (Frontmatter (Join-Path $plugin "agents\my-plan-$agent.md")) -match '^model:'
    return ($line -replace '^model:\s*', '').Trim()
}
$author = ModelOf 'planner'
$critic = ModelOf 'reviewer'
$coder = ModelOf 'implementer'
$deep = ModelOf 'reviewer-deep'
Check ($author -ne $critic) "plan author ($author) differs from its reviewer ($critic)"
Check ($coder -ne $deep) "code author ($coder) differs from its reviewer ($deep)"
Check ($critic -ne $deep) "the two reviewers are different models ($critic, $deep)"

Write-Host '== commits stay the user''s'

$trailer = Get-ChildItem -LiteralPath $plugin -Recurse -File |
    Select-String -Pattern 'Co-Authored-By:' -SimpleMatch -List
Check (-not $trailer) 'no Co-Authored-By trailer anywhere'

$rule = Get-ChildItem -LiteralPath (Join-Path $plugin 'skills') -Recurse -File |
    Select-String -Pattern "Never override the repository's Git identity" -SimpleMatch -List
Check ([bool]$rule) 'commit authorship rule is stated to the Coordinator'

Write-Host '== push is gated, commits are scanned'

$startSkill = Get-Content -LiteralPath (Join-Path $plugin 'skills\start\SKILL.md') -Raw
$implStage = Get-Content -LiteralPath (Join-Path $plugin 'internal\stages\implementation.md') -Raw

Check ($startSkill -like '*push gate*') 'the push gate is stated to the Coordinator'
Check ($implStage -like '*## The push gate*') 'delivery stops at the push gate'
Check (-not ($startSkill -like '*remediation, commit, fast-forward integration, and push*')) 'spec approval stops at local commits'
Check ($implStage -like '*Before every commit: check what you are about to publish*') 'staged sets are scanned before commit'

foreach ($pattern in @('PRIVATE KEY', 'AKIA', 'api[_-]?key', '.env', 'bearer ')) {
    Check ($implStage.Contains($pattern)) "secret scan names $pattern"
}

$codexStart = Get-Content -LiteralPath (Join-Path $codexPlugin 'skills\start\SKILL.md') -Raw
$codexImpl = Get-Content -LiteralPath (Join-Path $codexPlugin 'internal\stages\implementation.md') -Raw
$codexDiscovery = Get-Content -LiteralPath (Join-Path $codexPlugin 'internal\stages\discovery-spec.md') -Raw
$codexTransport = Get-Content -LiteralPath (Join-Path $codexPlugin 'internal\codex.md') -Raw

Check ($codexStart.Contains('push gate')) 'Codex push gate is stated to the Coordinator'
Check ($codexImpl.Contains('## The push gate')) 'Codex delivery stops at the push gate'
Check ($codexDiscovery.Contains('It never authorizes the push')) 'Codex spec approval stops at local commits'
Check ($codexImpl.Contains('Before every commit: check what you are about to publish')) 'Codex staged sets are scanned before commit'
foreach ($pattern in @('PRIVATE KEY', 'AKIA', 'api[_-]?key', '.env', 'bearer ')) {
    Check ($codexImpl.Contains($pattern)) "Codex secret scan names $pattern"
}
Check ($codexTransport.Contains('--sandbox read-only')) 'Codex reviewers use a read-only sandbox'
Check ($codexTransport.Contains('--sandbox workspace-write')) 'Codex writers use a workspace-write sandbox'
Check ($codexTransport.Contains('--output-schema')) 'Codex Worker results use provider-enforced schemas'
Check ($codexTransport.Contains('Sol and Terra must resolve to different IDs')) 'Codex writer and reviewer models must differ'

Write-Host '== Codex lifecycle contract'

$codexProject = Get-Content -LiteralPath (Join-Path $codexPlugin 'internal\stages\project.md') -Raw
$codexAudit = Get-Content -LiteralPath (Join-Path $codexPlugin 'skills\audit\SKILL.md') -Raw
Check ($codexProject.Contains('Record it in `profile.json` and every')) 'codex-only runtime is recorded in profiles and Runs'
Check ($codexProject.Contains('~/.codex/plugins/data/my-plan-my-plan/')) 'Codex state uses its own POSIX root'
Check ($codexProject.Contains('%USERPROFILE%\.codex\plugins\data\my-plan-my-plan\')) 'Codex state uses its own Windows root'
Check ($codexProject.Contains('.agents/skills/my-plan-project/')) 'Codex setup owns only the .agents Project Skill'
Check (-not (Test-Path -LiteralPath (Join-Path $codexPlugin 'agents'))) 'Codex plugin installs no global agents'
Check ($codexStart.Contains('Everything before approval is read-only against the user')) 'pre-approval repository state is read-only'
Check ($codexStart.Contains("All mutation happens in the Run's isolated")) 'approved mutation stays in the isolated worktree'
Check ($codexTransport.Contains('One bounded retry, then mark the Run blocked')) 'transient Worker failure gets one retry'
Check ($codexTransport.Contains('quota, usage cap, credits, unavailable model')) 'quota and model failures block without fallback'
Check ($codexTransport.Contains('Never resume a last or most')) 'Worker continuation requires an exact thread'
Check ($codexAudit.Contains('Read-only until findings are accepted')) 'audit remains read-only until accepted findings become a spec'
Check ($codexProject.Contains('docs/my-plan/SEAM.md')) 'both distributions share the Architecture Memory path'

Write-Host '== contracts are strict-mode clean'

# Provider-enforced structured output rejects a schema where any property lacks a
# type, or where required omits any key in properties, at any depth.
$violations = @()
function Test-Strict($node, [string]$where) {
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        $keys = $node.PSObject.Properties.Name
        if ($keys -contains 'properties') {
            $props = $node.properties.PSObject.Properties.Name
            $req = @()
            if ($keys -contains 'required') { $req = @($node.required) }
            foreach ($p in $props) {
                if ($req -notcontains $p) { $script:violations += "$where`: '$p' in properties but not in required" }
                $sub = $node.properties.$p
                $subKeys = $sub.PSObject.Properties.Name
                if ($subKeys -notcontains 'type' -and $subKeys -notcontains '$ref' -and
                    $subKeys -notcontains 'anyOf' -and $subKeys -notcontains 'oneOf' -and $subKeys -notcontains 'allOf') {
                    $script:violations += "$where.$p`: no 'type' key"
                }
            }
        }
        foreach ($k in $keys) { Test-Strict $node.$k "$where.$k" }
    } elseif ($node -is [System.Object[]]) {
        for ($i = 0; $i -lt $node.Count; $i++) { Test-Strict $node[$i] "$where[$i]" }
    }
}
foreach ($contractsRoot in @(
        (Join-Path $plugin 'internal\contracts'),
        (Join-Path $codexPlugin 'internal\contracts'))) {
    Get-ChildItem -LiteralPath $contractsRoot -Filter *.json | ForEach-Object {
        Test-Strict (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json) $_.FullName
    }
}
foreach ($v in $violations) { Check $false $v }
if ($violations.Count -eq 0) { Check $true 'contract schemas accept --output-schema' }

Write-Host '== references resolve'

# A ${CLAUDE_PLUGIN_ROOT} path that resolves on POSIX but not here means a
# separator or casing assumption leaked into the plugin.
$missing = @()
Get-ChildItem -LiteralPath $plugin -Recurse -File | ForEach-Object {
    [regex]::Matches((Get-Content -LiteralPath $_.FullName -Raw),
        '\$\{CLAUDE_PLUGIN_ROOT\}/([A-Za-z0-9._/-]+)') | ForEach-Object {
        $rel = $_.Groups[1].Value -replace '/', '\'
        if (-not (Test-Path -LiteralPath (Join-Path $plugin $rel))) { $missing += $rel }
    }
}
$missing = $missing | Sort-Object -Unique
foreach ($m in $missing) { Check $false "broken reference: $m" }
if ($missing.Count -eq 0) { Check $true 'all plugin-root references resolve' }

$missing = @()
Get-ChildItem -LiteralPath $codexPlugin -Recurse -File | ForEach-Object {
    [regex]::Matches((Get-Content -LiteralPath $_.FullName -Raw),
        '<pluginRoot>/([A-Za-z0-9._/-]+)') | ForEach-Object {
        $rel = $_.Groups[1].Value -replace '/', '\'
        if (-not (Test-Path -LiteralPath (Join-Path $codexPlugin $rel))) { $missing += $rel }
    }
}
$missing = $missing | Sort-Object -Unique
foreach ($m in $missing) { Check $false "broken Codex reference: $m" }
if ($missing.Count -eq 0) { Check $true 'all Codex plugin-root references resolve' }

Write-Host '== static plugin'

$runtime = Get-ChildItem -LiteralPath $plugin -Recurse -File -Include `
    'package.json', '*.js', '*.mjs', '*.ts', '*.py', '*.sh', 'hooks.json', `
    '.mcp.json', 'requirements.txt', 'pyproject.toml'
if ($runtime) {
    Write-Host "FAIL runtime artifact in installed plugin:"
    $runtime | ForEach-Object { Write-Host "  $($_.FullName)" }
    $fails++
} else {
    Check $true 'installed plugin is static'
}

$runtime = Get-ChildItem -LiteralPath $codexPlugin -Recurse -File -Include `
    'package.json', '*.js', '*.mjs', '*.ts', '*.py', '*.sh', 'hooks.json', `
    '.mcp.json', 'requirements.txt', 'pyproject.toml'
if ($runtime) {
    Write-Host "FAIL runtime artifact in Codex plugin:"
    $runtime | ForEach-Object { Write-Host "  $($_.FullName)" }
    $fails++
} else {
    Check $true 'Codex plugin is static'
}

$inherited = Get-ChildItem -LiteralPath $plugin -Recurse -File |
    Select-String -Pattern 'specseam' -SimpleMatch -List
Check (-not $inherited) 'no inherited terminology'

$inherited = Get-ChildItem -LiteralPath $codexPlugin -Recurse -File |
    Select-String -Pattern 'specseam' -SimpleMatch -List
Check (-not $inherited) 'Codex plugin has no inherited terminology'

$foreign = Get-ChildItem -LiteralPath $codexPlugin -Recurse -File |
    Select-String -Pattern 'claude|sonnet|opus|hybrid' -List
Check (-not $foreign) 'Codex plugin is Codex-only'

$trailer = Get-ChildItem -LiteralPath $codexPlugin -Recurse -File |
    Select-String -Pattern 'Co-Authored-By:' -SimpleMatch -List
Check (-not $trailer) 'Codex plugin has no Co-Authored-By trailer'

Write-Host '== shared assets stay in parity'

foreach ($f in @(
        'internal\checklists\review.md',
        'internal\checklists\architecture.md',
        'internal\checklists\implementation.md',
        'internal\references\README.md',
        'internal\references\NOTICE.md',
        'internal\contracts\build-result.schema.json',
        'internal\contracts\challenge-result.schema.json',
        'internal\contracts\review-result.schema.json',
        'internal\contracts\commit-result.schema.json',
        'internal\prompts\build.tpl',
        'internal\prompts\challenge.tpl',
        'internal\prompts\plan-check.tpl',
        'internal\prompts\qa.tpl',
        'internal\prompts\commit.tpl',
        'internal\templates\documents\audit.md.tpl',
        'internal\templates\documents\delivery.md.tpl',
        'internal\templates\documents\discovery.md.tpl',
        'internal\templates\documents\plan.md.tpl',
        'internal\templates\documents\research.md.tpl',
        'internal\templates\documents\validation.md.tpl')) {
    $left = (Get-FileHash -LiteralPath (Join-Path $plugin $f) -Algorithm SHA256).Hash
    $right = (Get-FileHash -LiteralPath (Join-Path $codexPlugin $f) -Algorithm SHA256).Hash
    Check ($left -eq $right) "shared asset matches: $f"
}

Write-Host '== reference guides are attributed and reachable'

# The guides are third-party MIT text. Redistributing them without the upstream
# copyright is the one defect here that is not a quality problem.
$refDir = Join-Path $plugin 'internal\references'
$notice = Get-Content -LiteralPath (Join-Path $refDir 'NOTICE.md') -Raw
Check ($notice.Contains('Copyright (c) 2025 awesome-skills')) 'upstream copyright is preserved'
Check ($notice.Contains('Permission is hereby granted')) 'upstream license text is preserved'

# README.md is the only map from a stack or a concern to a file. An entry
# pointing at nothing fails invisibly, only once a Run reaches it. Windows also
# proves the separator holds: the index writes '/', the filesystem takes '\'.
$index = Get-Content -LiteralPath (Join-Path $refDir 'README.md') -Raw
$named = [regex]::Matches($index, '`([a-z0-9./-]+\.md)`') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { -not $_.StartsWith('checklists/') } |
    Sort-Object -Unique
$missing = @($named | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $refDir ($_ -replace '/', '\')))
})
Check ($missing.Count -eq 0) "every guide the reference index names exists$(if ($missing) { ' (missing: ' + ($missing -join ', ') + ')' })"

$onDisk = @(Get-ChildItem -LiteralPath $refDir -Recurse -File -Filter *.md |
    Where-Object { $_.Name -notin @('README.md', 'NOTICE.md') } |
    ForEach-Object { $_.FullName.Substring($refDir.Length + 1) -replace '\\', '/' })
$unindexed = @($onDisk | Where-Object { -not $index.Contains('`' + $_ + '`') })
Check ($unindexed.Count -eq 0) "every guide is reachable from the index$(if ($unindexed) { ' (unindexed: ' + ($unindexed -join ', ') + ')' })"

Write-Host '== the audit reaches the widest checklist surface'

# An audit has no diff pointing it anywhere, so it is the mode that depends most
# on the checklists and least on what the subject volunteers.
foreach ($p in @($plugin, $codexPlugin)) {
    $label = if ($p -eq $plugin) { 'plugin' } else { 'Codex' }
    $auditSkill = Get-Content -LiteralPath (Join-Path $p 'skills\audit\SKILL.md') -Raw
    $changeCheck = Get-Content -LiteralPath (Join-Path $p 'internal\prompts\change-check.tpl') -Raw
    $reviewStage = Get-Content -LiteralPath (Join-Path $p 'internal\stages\review.md') -Raw

    foreach ($c in @('architecture', 'implementation', 'review')) {
        Check ($auditSkill.Contains("checklists/$c.md")) "$($label): the audit command dispatches against checklists/$c.md"
    }
    Check ($auditSkill.Contains('internal/references/')) "$($label): the audit command reaches the stack guides"
    Check ($changeCheck.Contains('In `audit` mode two more checklists are yours')) "$($label): the audit Worker is told which checklists widen its scope"
    Check ($changeCheck.Contains('In every other mode the diff is your scope')) "$($label): the extra checklists do not widen a diff review"
    Check ($reviewStage.Contains('widest checklist surface of any mode')) "$($label): audit mode states why it carries more checklist than a diff"
}

# Both checklists are read by a writer and by an audit, and the two readings have
# different burdens of proof.
foreach ($c in @('architecture', 'implementation')) {
    $doc = Get-Content -LiteralPath (Join-Path $plugin "internal\checklists\$c.md") -Raw
    Check ($doc.Contains('audit')) "checklists/$c.md says how an audit reads it"
}

Write-Host ''
if ($fails -gt 0) {
    Write-Host "$fails check(s) failed"
    exit 1
}
Write-Host 'all checks passed'
