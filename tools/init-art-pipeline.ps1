param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path $ProjectRoot)) { throw "Project root does not exist: $ProjectRoot" }

$directories = @(
  "design/art",
  "production/assets/prompts",
  "production/assets/import-recipes",
  "production/assets/reviews",
  "production/quality",
  ".mlgs"
)
foreach ($relative in $directories) { New-Item -ItemType Directory -Path (Join-Path $ProjectRoot $relative) -Force | Out-Null }

$written = @()
function Copy-MLGSTemplate {
  param([string]$SourceRelative, [string]$TargetRelative)
  $source = Join-Path $Root $SourceRelative
  $target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $TargetRelative
  if ((Test-Path $target) -and -not $Force) { return }
  Copy-Item -LiteralPath $source -Destination $target -Force
  $script:written += $TargetRelative
}

Copy-MLGSTemplate "templates/art-style-bible.md" "design/art/style-bible.md"
Copy-MLGSTemplate "studio/art-asset-manifest.schema.json" ".mlgs/art-asset-manifest.schema.json"
Copy-MLGSTemplate "studio/quality-gate.schema.json" ".mlgs/quality-gate.schema.json"

$manifestPath = Join-Path $ProjectRoot "production/assets/asset-manifest.json"
if ($Force -or -not (Test-Path $manifestPath)) {
  $manifest = [ordered]@{
    '$schema' = "../../.mlgs/art-asset-manifest.schema.json"
    schemaVersion = "1.0"
    updated = (Get-Date).ToString("o")
    assets = @()
  }
  Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
  $written += "production/assets/asset-manifest.json"
}

[pscustomobject]@{
  initialized = $true
  project_root = $ProjectRoot
  manifest_path = $manifestPath
  files_written = @($written)
} | ConvertTo-Json -Depth 8

