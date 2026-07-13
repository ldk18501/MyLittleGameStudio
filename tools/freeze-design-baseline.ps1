param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Version = "1",
  [string[]]$SourcePaths = @(),
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if ($SourcePaths.Count -eq 0) {
  $SourcePaths = @("design/concept-package.md", "design/reference-analysis.md", "design/game-profile.json", "design/player-journey.md", "design/onboarding.md", "design/art/visual-target.json", "design/art/style-bible.md", "design/ui/screen-inventory.json", "docs/tech-plan.md", "production/scope/release-scope.json")
}
$target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "design/baseline.json"
if ((Test-Path $target) -and -not $Force) {
  $existing = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$existing.status -eq "frozen") { throw "Design baseline is already frozen. Use -Force only after change impact is reviewed." }
}
$sources = @()
$scopePath = Join-Path $ProjectRoot "production/scope/release-scope.json"
if (Test-Path $scopePath) {
  $scope = Get-Content -LiteralPath $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json
  $scope.designBaselineVersion = $Version
  $scope.updated = (Get-Date).ToString("o")
  Write-MLGSJsonAtomic -Path $scopePath -Value $scope
}
foreach ($relative in $SourcePaths) {
  $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $relative
  if (-not (Test-Path $full)) { throw "Cannot freeze missing design source: $relative" }
  $sources += [ordered]@{
    path = $relative
    sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    affectsScopeIds = @("*")
    affectsAssetIds = @("*")
    affectsWorkPackageIds = @("*")
    invalidatesStages = @("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")
  }
}
$baseline = [ordered]@{
  '$schema' = "../.mlgs/design-baseline.schema.json"
  schemaVersion = "1.0"
  version = $Version
  status = "frozen"
  frozenAt = (Get-Date).ToString("o")
  sources = $sources
}
Write-MLGSJsonAtomic -Path $target -Value $baseline
[pscustomobject]@{ frozen = $true; path = $target; version = $Version; source_count = $sources.Count } | ConvertTo-Json -Depth 6
