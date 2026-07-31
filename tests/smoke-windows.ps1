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

foreach ($s in @('my-plan-install', 'my-plan-start', 'my-plan-audit')) {
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

foreach ($a in @('discovery', 'planner', 'reviewer')) {
    $tools = (Frontmatter (Join-Path $plugin "agents\my-plan-$a.md")) -match '^tools:'
    Check (-not ($tools -match '(Write|Edit|NotebookEdit)')) "agent $a is read-only"
}

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
