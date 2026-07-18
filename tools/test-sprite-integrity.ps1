param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$ManifestPath = "production/assets/asset-manifest.json",
  [string]$ReportPath = "production/qa/evidence/sprite-integrity.json",
  [int]$AlphaThreshold = 8,
  [double]$ComponentRatio = 0.003
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$scriptPath = Join-Path $Root "tools/test_sprite_integrity.py"
if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing Sprite integrity script: $scriptPath" }

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw "Python was not found; Sprite integrity validation cannot run." }

& $python.Source $scriptPath --project-root $ProjectRoot --manifest $ManifestPath --report $ReportPath --alpha-threshold $AlphaThreshold --component-ratio $ComponentRatio
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
