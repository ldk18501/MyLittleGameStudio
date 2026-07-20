param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$TargetPath,
  [Parameter(Mandatory = $true)][string]$CandidatePath,
  [Parameter(Mandatory = $true)][string]$ReportPath,
  [ValidateSet("asset", "scene")][string]$Mode = "asset",
  [ValidateRange(0, 100)][int]$TargetMatch = 0,
  [ValidateRange(0, 100)][int]$DimensionMinimum = 0
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$scriptPath = Join-Path $Root "tools/test_visual_comparison.py"
if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing visual comparison script: $scriptPath" }
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw "Python was not found; visual comparison cannot run." }

$arguments = @($scriptPath, "--project-root", $ProjectRoot, "--target", $TargetPath, "--candidate", $CandidatePath, "--report", $ReportPath, "--mode", $Mode)
if ($TargetMatch -gt 0) { $arguments += @("--target-match", $TargetMatch) }
if ($DimensionMinimum -gt 0) { $arguments += @("--dimension-min", $DimensionMinimum) }
& $python.Source @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
