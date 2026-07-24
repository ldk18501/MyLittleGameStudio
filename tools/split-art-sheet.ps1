param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$PlanPath
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$scriptPath = Join-Path $Root "tools/split_art_sheet.py"
if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing registered art sheet splitter: $scriptPath" }
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { throw "Python was not found; registered art sheet splitting cannot run." }

& $python.Source $scriptPath --project-root $ProjectRoot --plan $PlanPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
