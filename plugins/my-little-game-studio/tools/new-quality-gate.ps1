param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidateSet("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")][string]$Stage,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$initArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/init-production-pipeline.ps1"), "-Root", $Root, "-ProjectRoot", $ProjectRoot)
& powershell @initArgs | Out-Null
$catalog = Get-Content -LiteralPath (Join-Path $Root "workflow/catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$definition = $null
foreach ($gateProperty in $catalog.gates.PSObject.Properties) {
  $gate = $gateProperty.Value
  if (($gate.PSObject.Properties.Name -contains "qualityReport") -and [string]$gate.qualityReport.stage -eq $Stage) {
    $definition = $gate.qualityReport
    break
  }
}
if ($null -eq $definition) { throw "No quality gate definition found for stage: $Stage" }

$schemaTarget = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/quality-gate.schema.json"
New-Item -ItemType Directory -Path (Split-Path -Parent $schemaTarget) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "studio/quality-gate.schema.json") -Destination $schemaTarget -Force

$reportPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$definition.path)
if ((Test-Path $reportPath) -and -not $Force) { throw "Quality report already exists: $reportPath" }
$checks = @()
foreach ($id in @($definition.requiredChecks)) {
  $checks += [ordered]@{ id = [string]$id; status = "pending"; objectiveVerdict = "pending"; evidence = @(); objectiveChecks = @([ordered]@{ id = "evidence-exists"; kind = "file-exists"; path = ""; contains = ""; command = ""; status = "pending"; detail = "" }); notes = "" }
}
$report = [ordered]@{
  '$schema' = "../../.mlgs/quality-gate.schema.json"
  schemaVersion = "1.1"
  stage = $Stage
  verdict = "pending"
  declaredVerdict = "pending"
  objectiveVerdict = "pending"
  ownerApproval = $false
  updated = (Get-Date).ToString("o")
  checks = $checks
  blockers = @()
  acceptedRisks = @()
  notes = ""
}
Write-MLGSJsonAtomic -Path $reportPath -Value $report

function Copy-IfMissing {
  param([string]$Template, [string]$Target)
  $targetPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Target
  if (-not (Test-Path $targetPath)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetPath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root $Template) -Destination $targetPath
  }
}

switch ($Stage) {
  "content-complete" { Copy-IfMissing "templates/qa-report.md" "production/qa/content-complete-qa.md" }
  "alpha" {
    Copy-IfMissing "templates/qa-report.md" "production/qa/alpha-qa.md"
    Copy-IfMissing "templates/crash-check.md" "production/qa/crash-check.md"
  }
  "beta" {
    Copy-IfMissing "templates/qa-report.md" "production/qa/beta-qa.md"
    Copy-IfMissing "templates/icon-checklist.md" "production/release/icon-checklist.md"
    Copy-IfMissing "templates/localization-report.md" "production/localization/localization-report.md"
    Copy-IfMissing "templates/crash-check.md" "production/qa/crash-check.md"
  }
  "release-candidate" {
    Copy-IfMissing "templates/icon-checklist.md" "production/release/icon-checklist.md"
    Copy-IfMissing "templates/localization-report.md" "production/localization/localization-report.md"
    Copy-IfMissing "templates/crash-check.md" "production/qa/crash-check.md"
    Copy-IfMissing "templates/release-checklist.md" "production/release/release-checklist.md"
    Copy-IfMissing "templates/known-issues.md" "production/release/known-issues.md"
  }
  "release" {
    Copy-IfMissing "templates/build-report.md" "production/release/build-report.md"
    Copy-IfMissing "templates/icon-checklist.md" "production/release/icon-checklist.md"
    Copy-IfMissing "templates/localization-report.md" "production/localization/localization-report.md"
    Copy-IfMissing "templates/crash-check.md" "production/qa/crash-check.md"
  }
}

[pscustomobject]@{ created = $true; stage = $Stage; report_path = $reportPath; required_checks = @($definition.requiredChecks) } | ConvertTo-Json -Depth 8
