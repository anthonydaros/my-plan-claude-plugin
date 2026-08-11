# Static checks for the My Plan plugin on Windows. Development only.
# Content checks that are platform-independent live in smoke-posix.sh and run on
# Linux and macOS. This script covers what only Windows can prove: that the paths
# resolve and the manifests load under PowerShell.
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$plugin = Join-Path $root 'plugin'
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

$skills = @('map', 'spec', 'plan', 'review-plan', 'implement', 'review', 'validate', 'commit', 'cleanup')

Write-Host '== manifests'

foreach ($m in @(
        (Join-Path $root '.claude-plugin\marketplace.json'),
        (Join-Path $plugin '.claude-plugin\plugin.json'),
        (Join-Path $root '.agents\plugins\marketplace.json'),
        (Join-Path $plugin '.codex-plugin\plugin.json'))) {
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
Check ($manifest.name -eq 'my-plan') 'Claude plugin name is my-plan'

$market = Get-Content -LiteralPath (Join-Path $root '.claude-plugin\marketplace.json') -Raw | ConvertFrom-Json
Check ($market.plugins[0].source -eq './plugin') 'Claude marketplace publishes ./plugin'

$codexManifest = Get-Content -LiteralPath (Join-Path $plugin '.codex-plugin\plugin.json') -Raw | ConvertFrom-Json
Check ($codexManifest.name -eq 'my-plan') 'Codex plugin name is my-plan'
# Pin the shape, not the number: a release must be able to bump this.
Check ($codexManifest.version -match '^\d+\.\d+\.\d+(\+[0-9A-Za-z.-]+)?$') 'Codex plugin declares a semantic version'
Check ($codexManifest.skills -eq './skills/') 'Codex manifest publishes only its skill root'
Check (-not ($codexManifest.PSObject.Properties.Name -contains 'mcpServers')) 'Codex manifest has no MCP servers'
Check (-not ($codexManifest.PSObject.Properties.Name -contains 'hooks')) 'Codex manifest has no hooks'

$codexMarket = Get-Content -LiteralPath (Join-Path $root '.agents\plugins\marketplace.json') -Raw | ConvertFrom-Json
Check ($codexMarket.name -eq 'my-plan-codex') 'Codex marketplace name is my-plan-codex'
Check ($codexMarket.plugins[0].source.path -eq './plugin') 'Codex marketplace publishes ./plugin'
Check ($codexMarket.plugins[0].policy.installation -eq 'AVAILABLE') 'Codex marketplace installation policy is AVAILABLE'
Check ($codexMarket.plugins[0].policy.authentication -eq 'ON_INSTALL') 'Codex marketplace authentication policy is ON_INSTALL'
Check ($codexMarket.plugins[0].category -eq 'Development') 'Codex marketplace category is Development'

# Two manifests describing one artifact must agree, or one of them is stale
# the moment a release bumps only the other.
Check ($manifest.version -eq $codexManifest.version) "both manifests declare the same version (claude:$($manifest.version) codex:$($codexManifest.version))"

Write-Host '== the 9 skills are independent and manual-only'

foreach ($s in $skills) {
    $f = Join-Path $plugin "skills\$s\SKILL.md"
    $meta = Join-Path $plugin "skills\$s\agents\openai.yaml"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing $s"; continue }
    if (-not (Test-Path -LiteralPath $meta)) { Check $false "missing $s metadata"; continue }
    $fm = Frontmatter $f
    Check ([bool]($fm -contains "name: $s")) "$s declares name: $s"
    Check ([bool]($fm -match '^description: .')) "$s has a description"
    Check ([bool]($fm -match '^argument-hint: .')) "$s declares an argument-hint"
    Check ([bool]($fm -contains 'disable-model-invocation: true')) "$s is manual only in Claude Code"
    Check ((Get-Content -LiteralPath $f -Raw) -like '*$ARGUMENTS*') "$s consumes `$ARGUMENTS"
    $metaText = Get-Content -LiteralPath $meta -Raw
    Check ($metaText.Contains('allow_implicit_invocation: false')) "$s is manual only in Codex CLI"
    Check ($metaText.Contains("`$my-plan:$s")) "$s metadata names its invocation"
}

Check (-not (Test-Path -LiteralPath (Join-Path $plugin 'skills\push'))) 'no push skill exists'

$foundSkills = @(Get-ChildItem -LiteralPath (Join-Path $plugin 'skills') -Directory | ForEach-Object { $_.Name } | Sort-Object)
$expectedSkills = @($skills | Sort-Object)
Check (($foundSkills -join ',') -eq ($expectedSkills -join ',')) "skills\ contains exactly the 9 skills (found: $($foundSkills -join ', '))"

Write-Host '== the shared SKILL.md body has no per-host path variable'

$leaked = Get-ChildItem -LiteralPath $plugin -Recurse -File |
    Select-String -Pattern '\$\{CLAUDE_PLUGIN_ROOT\}|<pluginRoot>' -List
Check (-not $leaked) 'no ${CLAUDE_PLUGIN_ROOT} or <pluginRoot> anywhere in plugin\'

Write-Host '== relative knowledge/agent references resolve'

$missing = @()
foreach ($s in $skills) {
    $f = Join-Path $plugin "skills\$s\SKILL.md"
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $dir = Split-Path -Parent $f
    [regex]::Matches((Get-Content -LiteralPath $f -Raw),
        '\.\./\.\./(knowledge|agents)/([A-Za-z0-9._/-]+)') | ForEach-Object {
        $rel = ($_.Groups[1].Value + '/' + $_.Groups[2].Value) -replace '/', '\'
        if (-not (Test-Path -LiteralPath (Join-Path $dir $rel))) { $missing += "$s -> $rel" }
    }
}
foreach ($m in ($missing | Sort-Object -Unique)) { Check $false "broken reference: $m" }
if ($missing.Count -eq 0) { Check $true 'every relative knowledge/agent reference resolves' }

# Agents sit one level shallower than skills (plugin\agents\, not
# plugin\skills\<name>\), so the same reference from an agent file must use
# ..\knowledge\ or ..\agents\, never ..\..\. Check the wrong-depth form
# first: without it, the substring ..\knowledge\... inside a broken
# ..\..\knowledge\... would still match and resolve, masking the bug.
$missing = @()
Get-ChildItem -LiteralPath (Join-Path $plugin 'agents') -Filter *.md | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    $dir = $_.DirectoryName
    if ($text -match '\.\./\.\./(knowledge|agents)/') {
        $missing += "$($_.Name) uses ../../ (agents sit one level shallower than skills)"
    }
    [regex]::Matches($text, '\.\./(knowledge|agents)/([A-Za-z0-9._/-]+)') | ForEach-Object {
        $rel = ($_.Groups[1].Value + '/' + $_.Groups[2].Value) -replace '/', '\'
        if (-not (Test-Path -LiteralPath (Join-Path $dir $rel))) { $missing += "$($_.Name): $rel" }
    }
}
foreach ($m in ($missing | Sort-Object -Unique)) { Check $false "broken reference: $m" }
if ($missing.Count -eq 0) { Check $true 'every relative knowledge/agent reference in agents\ resolves at the right depth' }

Write-Host '== agents'

foreach ($a in @('reviewer', 'committer')) {
    $f = Join-Path $plugin "agents\my-plan-$a.md"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing agent $a"; continue }
    $fm = Frontmatter $f
    Check ([bool]($fm -contains "name: my-plan-$a")) "agent $a name matches its filename"
    Check ([bool]($fm -match '^tools: \[')) "agent $a declares a bounded tool list"
    Check ([bool]($fm -match '^effort: (low|medium|high|xhigh|max)$')) "agent $a declares a valid effort"
    $tools = $fm -match '^tools:'
    Check (-not ($tools -match '(Write|Edit|NotebookEdit)')) "agent $a holds no file-editing tool"
}

$foundAgents = @(Get-ChildItem -LiteralPath (Join-Path $plugin 'agents') -File | ForEach-Object { $_.Name } | Sort-Object)
Check (($foundAgents -join ',') -eq 'my-plan-committer.md,my-plan-reviewer.md') "agents\ contains exactly the 2 native agents (found: $($foundAgents -join ', '))"

Check (Test-Path -LiteralPath (Join-Path $plugin 'LICENSE')) 'exists: LICENSE (NOTICE.md points installs at this file)'

Write-Host '== knowledge assets exist'

foreach ($f in @(
        'knowledge\checklists\review.md',
        'knowledge\checklists\architecture.md',
        'knowledge\checklists\implementation.md',
        'knowledge\checklists\cleanup.md',
        'knowledge\checklists\cleanup-code.md',
        'knowledge\checklists\cleanup-residue.md',
        'knowledge\checklists\cleanup-docs.md',
        'knowledge\checklists\cleanup-refactor.md',
        'knowledge\references\README.md',
        'knowledge\references\NOTICE.md',
        'knowledge\templates\brief.md',
        'knowledge\templates\plan.md',
        'knowledge\templates\task.md',
        'knowledge\templates\report.md')) {
    Check (Test-Path -LiteralPath (Join-Path $plugin $f)) "exists: $f"
}

Write-Host '== push is gated, commits are scanned'

$offenders = Get-ChildItem -LiteralPath (Join-Path $plugin 'skills'), (Join-Path $plugin 'agents') -Recurse -File |
    Where-Object { (Select-String -LiteralPath $_.FullName -Pattern 'git push' -SimpleMatch -List) -and
                   ($_.FullName -ne (Join-Path $plugin 'skills\commit\SKILL.md')) -and
                   ($_.FullName -ne (Join-Path $plugin 'agents\my-plan-committer.md')) }
Check ($offenders.Count -eq 0) 'git push is mentioned only in commit''s skill and agent'

$commitSkill = Get-Content -LiteralPath (Join-Path $plugin 'skills\commit\SKILL.md') -Raw
Check ($commitSkill.Contains('Never `git push`')) 'commit states it never pushes'
Check ($commitSkill.Contains('git push <remote> <branch>')) 'commit prints the push command for the user to run'
foreach ($pattern in @('PRIVATE KEY', 'AKIA', 'api[_-]?key', '.env', 'bearer ')) {
    Check ($commitSkill.Contains($pattern)) "secret scan names $pattern"
}
Check ($commitSkill.Contains("Never override the repository's configured")) 'commit authorship rule is stated'

Write-Host '== the closing-note convention holds'

foreach ($s in $skills) {
    $text = Get-Content -LiteralPath (Join-Path $plugin "skills\$s\SKILL.md") -Raw
    foreach ($label in @('Changed:', 'Validated:', 'Open risks:', 'Suggested next skill:')) {
        Check ($text.Contains($label)) "$s closing note has '$label'"
    }
}

Write-Host '== the declared-blindness convention holds'

foreach ($s in @('review', 'validate', 'commit')) {
    $text = Get-Content -LiteralPath (Join-Path $plugin "skills\$s\SKILL.md") -Raw
    Check ($text.Contains('--spec')) "$s accepts --spec"
    Check ($text.Contains('not evaluated')) "$s declares blindness plainly when nothing was supplied"
}

Write-Host '== independence is stated for both hosts'

foreach ($s in @('review-plan', 'review', 'validate', 'commit', 'cleanup')) {
    $text = Get-Content -LiteralPath (Join-Path $plugin "skills\$s\SKILL.md") -Raw
    Check ($text.Contains('**Claude Code.**')) "$s states its Claude Code independence mechanism"
    Check ($text.Contains('**Codex CLI.**')) "$s states its Codex CLI independence mechanism"
}

Write-Host '== commits stay the user''s'

$trailer = Get-ChildItem -LiteralPath $plugin -Recurse -File |
    Select-String -Pattern 'Co-Authored-By:' -SimpleMatch -List
Check (-not $trailer) 'no Co-Authored-By trailer anywhere'

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

$inherited = Get-ChildItem -LiteralPath $plugin -Recurse -File |
    Select-String -Pattern 'specseam' -SimpleMatch -List
Check (-not $inherited) 'no inherited terminology'

Write-Host '== reference guides are attributed and reachable'

$refDir = Join-Path $plugin 'knowledge\references'
$notice = Get-Content -LiteralPath (Join-Path $refDir 'NOTICE.md') -Raw
Check ($notice.Contains('Copyright (c) 2025 awesome-skills')) 'upstream copyright is preserved'
Check ($notice.Contains('Permission is hereby granted')) 'upstream license text is preserved'

# README.md is the only map from a stack or a concern to a file. Windows also
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

Write-Host ''
if ($fails -gt 0) {
    Write-Host "$fails check(s) failed"
    exit 1
}
Write-Host 'all checks passed'
