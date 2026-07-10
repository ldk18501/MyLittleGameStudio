param(
  [string]$Root = "",
  [string]$RuntimeRoot = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

$required = @(
  "studio/state.json",
  "studio/state.schema.json",
  "studio/pointer.schema.json",
  "workflow/catalog.json",
  "workflow/onboarding.yaml",
  "tools/resolve-state.ps1",
  "tools/detect-project-stage.ps1",
  "tools/repair-pointer.ps1",
  "tools/migrate-state.ps1"
)
foreach ($relative in $required) {
  if (-not (Test-Path (Join-Path $Root $relative))) { throw "Missing required MLGS file: $relative" }
}

$template = Import-MLGSState -Path (Join-Path $Root "studio/state.json")
$templateValidation = Test-MLGSState -State $template -AllowTemplate
if (-not $templateValidation.valid -or $template.kind -ne "template") {
  throw ("Invalid root state template: " + ($templateValidation.errors -join "; "))
}

$resolved = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -RuntimeRoot $RuntimeRoot -AllowTemplate | ConvertFrom-Json
if (-not $resolved.exists) {
  if ($resolved.needs_repair -and $resolved.template_exists) {
    Write-Output "State check warning: project pointer needs repair ($($resolved.repair_reason))."
    exit 0
  }
  throw "Could not resolve a template or project state."
}

$state = Import-MLGSState -Path $resolved.state_path
$validation = Test-MLGSState -State $state -AllowTemplate
if (-not $validation.valid) { throw ("Resolved state is invalid: " + ($validation.errors -join "; ")) }

[pscustomobject]@{
  status = "passed"
  mode = $resolved.mode
  state_format = $resolved.state_format
  state_path = $resolved.state_path
  runtime_root = $RuntimeRoot
  legacy_migration_available = $resolved.state_format -eq "legacy-yaml"
} | ConvertTo-Json -Depth 5

