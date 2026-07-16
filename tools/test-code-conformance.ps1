param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][ValidatePattern("^[a-z0-9][a-z0-9-]*$")][string]$TaskId,
  [Parameter(Mandatory = $true)][string[]]$ChangedPaths,
  [string]$OutputPath = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not $OutputPath) { $OutputPath = "production/quality/code-conformance-$TaskId.json" }
$findings = @()
$taskRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-code-task.ps1") -Root $Root -ProjectRoot $ProjectRoot -TaskId $TaskId -MinimumStatus implemented 2>$null
try { $task = $taskRaw | ConvertFrom-Json } catch { $task = [pscustomobject]@{ passed = $false; issues = @("Code task validator returned invalid output.") } }
foreach ($issue in @($task.issues)) { $findings += [pscustomobject]@{ severity = "error"; rule = "code-task"; path = "production/context-packs/$TaskId.json"; message = [string]$issue } }
$profile = Get-Content (Join-Path $ProjectRoot "design/code/codebase-profile.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$context = Get-Content (Join-Path $ProjectRoot "production/context-packs/$TaskId.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$plan = Get-Content (Join-Path $ProjectRoot "production/change-plans/$TaskId.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$changed = @($ChangedPaths | ForEach-Object { ([string]$_).Replace("\", "/").TrimStart('/') } | Select-Object -Unique)
$planned = @($context.plannedFiles.modify) + @($context.plannedFiles.create) + @($context.plannedFiles.delete) + @($context.plannedFiles.evidence)
$unplanned = @($changed | Where-Object { $planned -notcontains $_ })
foreach ($relative in $unplanned) { $findings += [pscustomobject]@{ severity = "error"; rule = "unplanned-change"; path = $relative; message = "Changed path is outside the approved code task plan." } }
$declaredAbstractions = @($plan.newAbstractions | ForEach-Object { [string]$_.name })
$responsibilityPaths = @($plan.responsibilities | ForEach-Object { [string]$_.path })
foreach ($relative in @($changed | Where-Object { $_ -like "*.cs" })) {
  $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $relative
  if (-not (Test-Path $full)) { continue }
  $content = Get-Content -LiteralPath $full -Raw -Encoding UTF8
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($relative)
  if ($baseName -match "(?i)(Manager|Service|Module|Repository|Factory)$" -and $declaredAbstractions -notcontains $baseName -and $responsibilityPaths -notcontains $relative) {
    $findings += [pscustomobject]@{ severity = "error"; rule = "undeclared-abstraction"; path = $relative; message = "New manager/service/module/repository/factory was not declared in the change plan." }
  }
  if ([string]$profile.conventions.namespaceRoot -and $content -match "\bnamespace\s+([A-Za-z_][A-Za-z0-9_\.]*)" -and $Matches[1] -notlike "$($profile.conventions.namespaceRoot)*") {
    $findings += [pscustomobject]@{ severity = "error"; rule = "namespace-style"; path = $relative; message = "Namespace does not follow the approved project root '$($profile.conventions.namespaceRoot)'." }
  }
  if ([string]$profile.conventions.serializedFields -match "SerializeField.*private" -and $content -match "(?s)\[SerializeField\]\s+(public|protected)\s+") {
    $findings += [pscustomobject]@{ severity = "warning"; rule = "serialized-field-style"; path = $relative; message = "Serialized field does not follow the approved private-field convention." }
  }
}
if ([bool]$profile.policy.requirePostImpact -and [string]$context.structuralEvidence.postImpactVerdict -ne "pass") { $findings += [pscustomobject]@{ severity = "error"; rule = "post-impact"; path = "production/context-packs/$TaskId.json"; message = "Deep project requires passing post-change impact review." } }
$errors = @($findings | Where-Object severity -eq "error")
$report = [ordered]@{ '$schema' = "../../.mlgs/code-conformance.schema.json"; schemaVersion = "1.0"; taskId = $TaskId; projectKind = [string]$profile.projectKind; intensity = [string]$profile.intensity; verdict = $(if ($errors.Count) { "fail" } else { "pass" }); changedPaths = @($changed); unplannedPaths = @($unplanned); findings = @($findings); postImpactVerdict = [string]$context.structuralEvidence.postImpactVerdict; updated = (Get-Date).ToString("o") }
$schemaTarget = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/code-conformance.schema.json"
New-Item -ItemType Directory -Path (Split-Path -Parent $schemaTarget) -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Root "studio/code-conformance.schema.json") -Destination $schemaTarget -Force
$target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $OutputPath
Write-MLGSJsonAtomic -Path $target -Value $report
$report | ConvertTo-Json -Depth 12
if ($errors.Count) { exit 21 }
