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

Write-Host '== manifests'

foreach ($m in @(
        (Join-Path $root '.claude-plugin\marketplace.json'),
        (Join-Path $plugin '.claude-plugin\plugin.json'))) {
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

Write-Host '== public skills'

foreach ($s in @('install', 'start', 'audit')) {
    $f = Join-Path $plugin "skills\$s\SKILL.md"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing $s"; continue }
    $fm = Frontmatter $f
    Check ([bool]($fm -contains "name: $s")) "$s declares name: $s"
    Check ([bool]($fm -contains 'disable-model-invocation: true')) "$s is manual only"
    Check ((Get-Content -LiteralPath $f -Raw) -like '*$ARGUMENTS*') "$s consumes `$ARGUMENTS"
}

Write-Host '== agents'

foreach ($a in @('discovery', 'planner', 'implementer', 'reviewer')) {
    $f = Join-Path $plugin "agents\my-plan-$a.md"
    if (-not (Test-Path -LiteralPath $f)) { Check $false "missing agent $a"; continue }
    $fm = Frontmatter $f
    Check ([bool]($fm -contains "name: my-plan-$a")) "agent $a name matches its filename"
}

# The reviewer reviews both plans and code, so it is the one that must never gain
# a write tool. The planner writes the plan; the implementer writes the code.
foreach ($a in @('discovery', 'reviewer')) {
    $tools = (Frontmatter (Join-Path $plugin "agents\my-plan-$a.md")) -match '^tools:'
    Check (-not ($tools -match '(Write|Edit|NotebookEdit)')) "agent $a is read-only"
}

foreach ($a in @('implementer', 'planner')) {
    $tools = (Frontmatter (Join-Path $plugin "agents\my-plan-$a.md")) -match '^tools:'
    Check ([bool]($tools -match 'Write')) "$a can write"
}

# Same-model review is the failure this product exists to prevent.
function ModelOf([string]$agent) {
    $line = (Frontmatter (Join-Path $plugin "agents\my-plan-$agent.md")) -match '^model:'
    return ($line -replace '^model:\s*', '').Trim()
}
$author = ModelOf 'planner'
$critic = ModelOf 'reviewer'
$coder = ModelOf 'implementer'
Check ($author -ne $critic) "plan author ($author) differs from reviewer ($critic)"
Check ($coder -ne $critic) "code author ($coder) differs from reviewer ($critic)"

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
Get-ChildItem -LiteralPath (Join-Path $plugin 'internal\contracts') -Filter *.json | ForEach-Object {
    Test-Strict (Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json) $_.Name
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

Write-Host ''
if ($fails -gt 0) {
    Write-Host "$fails check(s) failed"
    exit 1
}
Write-Host 'all checks passed'
