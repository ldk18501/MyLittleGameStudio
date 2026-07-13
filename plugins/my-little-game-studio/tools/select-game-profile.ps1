param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$ProfileId,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$source = Join-Path $Root "profiles/unity/$ProfileId.json"
if (-not (Test-Path $source)) { throw "Unknown Unity game profile: $ProfileId" }
$target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "design/game-profile.json"
if ((Test-Path $target) -and -not $Force) { throw "A game profile is already selected: $target" }
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
$profile = Get-Content -LiteralPath $source -Raw -Encoding UTF8 | ConvertFrom-Json
$profile.'$schema' = "../.mlgs/game-profile.schema.json"
$profile.selectedAt = (Get-Date).ToString("o")
Write-MLGSJsonAtomic -Path $target -Value $profile
foreach ($relative in @("production/scope/release-scope.json", "design/ui/screen-inventory.json")) {
  $relatedPath = Join-Path $ProjectRoot $relative
  if (-not (Test-Path $relatedPath)) { continue }
  $related = Get-Content -LiteralPath $relatedPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $related.profileId = $ProfileId
  if ($related.PSObject.Properties.Name -contains "updated") { $related.updated = (Get-Date).ToString("o") }
  Write-MLGSJsonAtomic -Path $relatedPath -Value $related
}
foreach ($schema in @("game-profile.schema.json", "ui-screen-contract.schema.json", "design-baseline.schema.json", "change-impact.schema.json")) {
  $schemaTarget = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/$schema"
  New-Item -ItemType Directory -Path (Split-Path -Parent $schemaTarget) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $Root "studio/$schema") -Destination $schemaTarget -Force
}
[pscustomobject]@{ selected = $true; profile_id = $ProfileId; path = $target } | ConvertTo-Json -Depth 6
