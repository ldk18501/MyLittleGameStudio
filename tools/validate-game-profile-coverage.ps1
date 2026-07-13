param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$ProfilePath = "design/game-profile.json",
  [string]$ScopePath = "production/scope/release-scope.json",
  [string]$UIScreenPath = "design/ui/screen-inventory.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()
$script:MLGSCoverageIssues = @()
function Read-ProjectJson([string]$Relative, [string]$Label) {
  try { $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Relative } catch { $script:MLGSCoverageIssues += $_.Exception.Message; return $null }
  if (-not (Test-Path $full)) { $script:MLGSCoverageIssues += "Missing ${Label}: $Relative"; return $null }
  try { return Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $script:MLGSCoverageIssues += "Invalid $Label JSON: $($_.Exception.Message)"; return $null }
}
$profile = Read-ProjectJson $ProfilePath "game profile"
$scope = Read-ProjectJson $ScopePath "release scope"
$ui = Read-ProjectJson $UIScreenPath "UI screen contract"
$issues += @($script:MLGSCoverageIssues)
if (-not $profile) { $issues += "Game profile could not be loaded." }
if (-not $scope) { $issues += "Release scope could not be loaded." }
if (-not $ui) { $issues += "UI screen contract could not be loaded." }
if ($profile -and $scope) {
  if ([string]$scope.profileId -ne [string]$profile.id) { $issues += "Release scope profileId must match selected profile '$($profile.id)'." }
  foreach ($requirement in @($profile.releaseScopeRequirements)) {
    $matches = @($scope.items | Where-Object { @($_.profileRequirementIds) -contains [string]$requirement.id })
    if ($matches.Count -eq 0) { $issues += "Profile requirement is not represented in release scope: $($requirement.id)"; continue }
    $planned = ($matches | Measure-Object -Property plannedCount -Sum).Sum
    if ([int]$planned -lt [int]$requirement.minimumPlannedCount) { $issues += "$($requirement.id): planned count $planned is below profile minimum $($requirement.minimumPlannedCount)." }
    foreach ($item in $matches) {
      if ([string]$item.type -ne [string]$requirement.type) { $issues += "$($item.id): type must match profile requirement $($requirement.type)." }
    }
  }
}
if ($profile -and $ui) {
  if ([string]$ui.profileId -ne [string]$profile.id) { $issues += "UI screen contract profileId must match selected profile '$($profile.id)'." }
  foreach ($screenId in @($profile.requiredUiScreens)) {
    if (@($ui.screens | Where-Object { [string]$_.id -eq [string]$screenId }).Count -eq 0) { $issues += "Required profile UI screen is missing: $screenId" }
  }
}
$profileId = if ($profile) { [string]$profile.id } else { "" }
$result = [pscustomobject]@{ passed = $issues.Count -eq 0; profile = $profileId; issues = @($issues) }
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 12 }
