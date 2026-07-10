param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][ValidateSet("implement", "fix", "build", "test", "review", "generate-art", "productize", "release")][string]$Command,
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [switch]$AcceptRisk
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot)
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
$blockers = @()
if (-not $resolved.exists -or $resolved.mode -eq "template") {
  $blockers += "No project state is configured."
} else {
  $state = Import-MLGSState -Path $resolved.state_path
  $validation = Test-MLGSState -State $state
  if (-not $validation.valid) { $blockers += $validation.errors }

  if (@("implement", "fix", "generate-art", "productize") -contains $Command) {
    if (-not [bool]$state.approvals.productionUnblocked -and -not $AcceptRisk) {
      $blockers += "Production is not unblocked. Use -AcceptRisk only after explicit owner acceptance."
    }
    if (@($state.activeProject.approvedWritePaths).Count -eq 0) {
      $blockers += "No approved Unity write paths are configured."
    }
  }
}

$result = [pscustomobject]@{
  allowed = $blockers.Count -eq 0
  command = $Command
  project_root = $resolved.project_root
  state_path = $resolved.state_path
  accepted_risk = [bool]$AcceptRisk
  blockers = @($blockers)
}
$result | ConvertTo-Json -Depth 8
if (-not $result.allowed) { exit 2 }
