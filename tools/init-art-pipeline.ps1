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
  "design/art/targets",
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
Copy-MLGSTemplate "templates/visual-target.json" "design/art/visual-target.json"
Copy-MLGSTemplate "studio/art-asset-manifest.schema.json" ".mlgs/art-asset-manifest.schema.json"
Copy-MLGSTemplate "studio/visual-target.schema.json" ".mlgs/visual-target.schema.json"
Copy-MLGSTemplate "studio/quality-gate.schema.json" ".mlgs/quality-gate.schema.json"
Copy-MLGSTemplate "studio/art-review.schema.json" ".mlgs/art-review.schema.json"

$visualTargetPath = Join-Path $ProjectRoot "design/art/visual-target.json"
if (Test-Path $visualTargetPath) {
  $visualTarget = Get-Content -LiteralPath $visualTargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]::IsNullOrWhiteSpace([string]$visualTarget.updated)) {
    $visualTarget.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $visualTargetPath -Value $visualTarget
  }
}

$manifestPath = Join-Path $ProjectRoot "production/assets/asset-manifest.json"
if ($Force -or -not (Test-Path $manifestPath)) {
  $manifest = [ordered]@{
    '$schema' = "../../.mlgs/art-asset-manifest.schema.json"
    schemaVersion = "1.2"
    updated = (Get-Date).ToString("o")
    visualTargetPath = "design/art/visual-target.json"
    assets = @()
  }
  Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
  $written += "production/assets/asset-manifest.json"
}
elseif (-not $Force) {
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $changed = $false
  if (@("1.0", "1.1") -contains [string]$manifest.schemaVersion) { $manifest.schemaVersion = "1.2"; $changed = $true }
  if ($manifest.PSObject.Properties.Name -notcontains "visualTargetPath") {
    $manifest | Add-Member -MemberType NoteProperty -Name visualTargetPath -Value "design/art/visual-target.json"
    $changed = $true
  }
  foreach ($asset in @($manifest.assets)) {
    if ($asset.PSObject.Properties.Name -notcontains "visualTargets") {
      $asset | Add-Member -MemberType NoteProperty -Name visualTargets -Value @()
      $changed = $true
    }
    if ($asset.PSObject.Properties.Name -notcontains "reviewPath") {
      $asset | Add-Member -MemberType NoteProperty -Name reviewPath -Value ""
      $changed = $true
    }
  }
  if ($changed) {
    $manifest.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    $written += "production/assets/asset-manifest.json"
  }
}

[pscustomobject]@{
  initialized = $true
  project_root = $ProjectRoot
  manifest_path = $manifestPath
  files_written = @($written)
} | ConvertTo-Json -Depth 8
