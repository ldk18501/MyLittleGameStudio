param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][ValidateSet("implement", "fix", "build", "test", "review", "generate-art", "productize", "release")][string]$Command,
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [ValidatePattern("^$|^[a-z0-9][a-z0-9-]*$")][string]$TaskId = "",
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
    if (@("implement", "fix", "productize") -contains $Command -and [bool]$state.approvals.productionUnblocked) {
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-framework-adoption.ps1") -Root $Root -ProjectRoot $resolved.project_root 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) { $blockers += "Framework adoption contract is missing or invalid; implementation may not bypass the project's existing architecture." }
      & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-presentation-architecture.ps1") -Root $Root -ProjectRoot $resolved.project_root -ContractOnly 2>$null | Out-Null
      if ($LASTEXITCODE -ne 0) { $blockers += "Presentation architecture contract is missing or invalid." }
      if (@("implement", "fix") -contains $Command) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-codebase-understanding.ps1") -Root $Root -ProjectRoot $resolved.project_root 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { $blockers += "Codebase profile/module understanding is missing, stale, or unapproved." }
        if ([string]::IsNullOrWhiteSpace($TaskId)) { $blockers += "Production code work requires -TaskId and a matching task context/change plan." }
        else {
          & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-code-task.ps1") -Root $Root -ProjectRoot $resolved.project_root -TaskId $TaskId -MinimumStatus ready 2>$null | Out-Null
          if ($LASTEXITCODE -ne 0) { $blockers += "Task context/change plan is missing, stale, underspecified, or unapproved for '$TaskId'." }
        }
      }
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
