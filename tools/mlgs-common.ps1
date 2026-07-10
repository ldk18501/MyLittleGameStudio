Set-StrictMode -Version 2.0

function Get-MLGSRuntimeRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$RuntimeRoot = ""
  )

  if (-not [string]::IsNullOrWhiteSpace($RuntimeRoot)) {
    return [System.IO.Path]::GetFullPath($RuntimeRoot)
  }

  if (Test-Path (Join-Path $Root ".codex-plugin/plugin.json")) {
    $codexHome = $env:CODEX_HOME
    if ([string]::IsNullOrWhiteSpace($codexHome)) {
      $codexHome = Join-Path $HOME ".codex"
    }
    return [System.IO.Path]::GetFullPath((Join-Path $codexHome "mlgs"))
  }

  return [System.IO.Path]::GetFullPath((Join-Path $Root "studio"))
}

function Resolve-MLGSPath {
  param([string]$Base, [string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Base $Path))
}

function Get-MLGSStateCandidate {
  param([Parameter(Mandatory = $true)][string]$ProjectRoot)

  $jsonPath = Join-Path $ProjectRoot ".mlgs/state.json"
  if (Test-Path $jsonPath) { return $jsonPath }

  $legacyPath = Join-Path $ProjectRoot ".mlgs/state.yaml"
  if (Test-Path $legacyPath) { return $legacyPath }

  return $jsonPath
}

function Get-LegacyYamlSection {
  param([string]$Content, [string]$Section)

  $lines = @($Content -split "`r?`n")
  $result = @()
  $inside = $false
  foreach ($line in $lines) {
    if ($line -match "^$([regex]::Escape($Section))\s*:\s*$") {
      $inside = $true
      continue
    }
    if ($inside -and $line -match "^\S") { break }
    if ($inside) { $result += $line }
  }
  return @($result)
}

function Get-LegacyYamlScalar {
  param([string[]]$Lines, [string]$Key, [string]$Default = "")

  foreach ($line in $Lines) {
    if ($line -match "^\s+$([regex]::Escape($Key))\s*:\s*(.*)$") {
      $value = ($matches[1] -replace '\s+#.*$', '').Trim()
      if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      return $value.Replace('\"', '"')
    }
  }
  return $Default
}

function Get-LegacyYamlList {
  param([string[]]$Lines, [string]$Key)

  $items = @()
  $inside = $false
  $keyIndent = -1
  foreach ($line in $Lines) {
    if ($line -match "^(\s*)$([regex]::Escape($Key))\s*:\s*\[\]\s*(?:#.*)?$") { return @() }
    if ($line -match "^(\s*)$([regex]::Escape($Key))\s*:\s*$") {
      $inside = $true
      $keyIndent = $matches[1].Length
      continue
    }
    if ($inside -and $line -match "^\s+-\s*(.*?)\s*$") {
      $value = $matches[1].Trim().Trim('"').Trim("'")
      $items += $value
      continue
    }
    if ($inside -and $line.Trim()) {
      $indent = $line.Length - $line.TrimStart().Length
      if ($indent -le $keyIndent) { break }
    }
  }
  return @($items)
}

function ConvertTo-MLGSBoolean {
  param([object]$Value)
  if ($Value -is [bool]) { return $Value }
  return ([string]$Value).Trim().ToLowerInvariant() -eq "true"
}

function ConvertFrom-MLGSLegacyState {
  param([Parameter(Mandatory = $true)][string]$Content)

  $active = Get-LegacyYamlSection $Content "active_project"
  $participation = Get-LegacyYamlSection $Content "owner_participation"
  $automation = Get-LegacyYamlSection $Content "automation"
  $phase = Get-LegacyYamlSection $Content "phase"
  $approvals = Get-LegacyYamlSection $Content "approvals"
  $prototype = Get-LegacyYamlSection $Content "prototype"
  $nextAction = Get-LegacyYamlSection $Content "next_action"
  $staff = Get-LegacyYamlSection $Content "staff"
  $phaseValue = Get-LegacyYamlScalar $phase "current" "not-started"
  switch ($phaseValue) {
    "idea-alignment" { $phaseValue = "intake" }
    "concept-package" { $phaseValue = "concept" }
    "design-tech-plan" { $phaseValue = "plan" }
    "prototype-validation" { $phaseValue = "prototype" }
    "polish-ship" { $phaseValue = "release" }
  }

  return [pscustomobject]@{
    schemaVersion = "0.3"
    updated = (Get-Date).ToString("o")
    kind = "project"
    activeProject = [pscustomobject]@{
      name = (Get-LegacyYamlScalar $active "name")
      slug = (Get-LegacyYamlScalar $active "slug")
      mode = (Get-LegacyYamlScalar $active "mode" "external-adopted")
      workspacePath = (Get-LegacyYamlScalar $active "workspace_path")
      externalPath = (Get-LegacyYamlScalar $active "external_path")
      engine = (Get-LegacyYamlScalar $active "engine" "Unity")
      language = (Get-LegacyYamlScalar $active "language" "C#")
      engineVersion = (Get-LegacyYamlScalar $active "engine_version")
      approvedWritePaths = @(Get-LegacyYamlList $active "approved_write_paths")
    }
    ownerParticipation = [pscustomobject]@{
      level = (Get-LegacyYamlScalar $participation "level" "medium")
      notes = (Get-LegacyYamlScalar $participation "notes")
    }
    automation = [pscustomobject]@{
      planning = (Get-LegacyYamlScalar $automation "planning" "high")
      production = (Get-LegacyYamlScalar $automation "production" "medium")
    }
    phase = [pscustomobject]@{ current = $phaseValue }
    approvals = [pscustomobject]@{
      projectSelected = (ConvertTo-MLGSBoolean (Get-LegacyYamlScalar $approvals "project_selected" "false"))
      conceptPackage = (ConvertTo-MLGSBoolean (Get-LegacyYamlScalar $approvals "concept_package" "false"))
      designTechPlan = (ConvertTo-MLGSBoolean (Get-LegacyYamlScalar $approvals "design_tech_plan" "false"))
      prototypeValidation = (ConvertTo-MLGSBoolean (Get-LegacyYamlScalar $approvals "prototype_validation" "false"))
      productionUnblocked = (ConvertTo-MLGSBoolean (Get-LegacyYamlScalar $approvals "production_unblocked" "false"))
    }
    prototype = [pscustomobject]@{
      policy = (Get-LegacyYamlScalar $prototype "policy" "recommended")
      type = (Get-LegacyYamlScalar $prototype "type" "html-or-unity-greybox")
      verdict = (Get-LegacyYamlScalar $prototype "verdict" "pending")
      skipReason = (Get-LegacyYamlScalar $prototype "skip_reason")
    }
    nextAction = [pscustomobject]@{
      command = (Get-LegacyYamlScalar $nextAction "command" "/mlgs status")
      reason = (Get-LegacyYamlScalar $nextAction "reason")
      options = @(Get-LegacyYamlList $nextAction "options")
    }
    assumptions = @(Get-LegacyYamlList @($Content -split "`r?`n") "assumptions")
    risks = @(Get-LegacyYamlList @($Content -split "`r?`n") "risks")
    staff = [pscustomobject]@{
      lastLead = (Get-LegacyYamlScalar $staff "last_lead" "producer")
      lastAgents = @(Get-LegacyYamlList $staff "last_agents")
    }
  }
}

function Import-MLGSState {
  param([Parameter(Mandatory = $true)][string]$Path)

  $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  if ([System.IO.Path]::GetExtension($Path).ToLowerInvariant() -eq ".json") {
    return $content | ConvertFrom-Json
  }
  return ConvertFrom-MLGSLegacyState $content
}

function Test-MLGSState {
  param([Parameter(Mandatory = $true)]$State, [switch]$AllowTemplate)

  $errors = @()
  if ($null -eq $State) { return [pscustomobject]@{ valid = $false; errors = @("state is null") } }
  $requiredTop = @("schemaVersion", "updated", "kind", "activeProject", "ownerParticipation", "automation", "phase", "approvals", "prototype", "nextAction", "assumptions", "risks", "staff")
  $topNames = @($State.PSObject.Properties.Name)
  foreach ($name in $requiredTop) {
    if ($topNames -notcontains $name) { $errors += "missing top-level property: $name" }
  }
  foreach ($name in $topNames) {
    if (@($requiredTop + '$schema') -notcontains $name) { $errors += "unexpected top-level property: $name" }
  }
  if ($errors.Count -gt 0) { return [pscustomobject]@{ valid = $false; errors = @($errors) } }

  $requiredNested = [ordered]@{
    activeProject = @("name", "slug", "mode", "workspacePath", "externalPath", "engine", "language", "engineVersion", "approvedWritePaths")
    ownerParticipation = @("level", "notes")
    automation = @("planning", "production")
    phase = @("current")
    approvals = @("projectSelected", "conceptPackage", "designTechPlan", "prototypeValidation", "productionUnblocked")
    prototype = @("policy", "type", "verdict", "skipReason")
    nextAction = @("command", "reason", "options")
    staff = @("lastLead", "lastAgents")
  }
  foreach ($sectionName in $requiredNested.Keys) {
    $section = $State.$sectionName
    if ($null -eq $section) { $errors += "$sectionName is null"; continue }
    $sectionNames = @($section.PSObject.Properties.Name)
    foreach ($propertyName in $requiredNested[$sectionName]) {
      if ($sectionNames -notcontains $propertyName) { $errors += "missing property: $sectionName.$propertyName" }
    }
    foreach ($propertyName in $sectionNames) {
      if ($requiredNested[$sectionName] -notcontains $propertyName) { $errors += "unexpected property: $sectionName.$propertyName" }
    }
  }
  if ($errors.Count -gt 0) { return [pscustomobject]@{ valid = $false; errors = @($errors) } }

  if ([string]$State.schemaVersion -ne "0.3") { $errors += "schemaVersion must be 0.3" }
  if (@("project", "template") -notcontains [string]$State.kind) { $errors += "kind must be project or template" }
  if (-not $AllowTemplate -and [string]$State.kind -ne "project") { $errors += "state must describe a project" }
  if (@("none", "internal", "external-adopted", "embedded") -notcontains [string]$State.activeProject.mode) { $errors += "activeProject.mode is invalid" }
  if ([string]$State.activeProject.engine -ne "Unity") { $errors += "activeProject.engine must be Unity" }
  if ([string]$State.activeProject.language -ne "C#") { $errors += "activeProject.language must be C#" }
  if (@("low", "medium", "high") -notcontains [string]$State.ownerParticipation.level) { $errors += "ownerParticipation.level is invalid" }
  if (@("not-started", "intake", "concept", "plan", "prototype", "vertical-slice", "production", "alpha", "beta", "release-candidate", "release") -notcontains [string]$State.phase.current) { $errors += "phase.current is invalid" }
  if (@("recommended", "required", "skipped-with-risk", "not-needed") -notcontains [string]$State.prototype.policy) { $errors += "prototype.policy is invalid" }
  if (@("pending", "pass", "revise", "skipped") -notcontains [string]$State.prototype.verdict) { $errors += "prototype.verdict is invalid" }
  if ([string]$State.kind -eq "project" -and [string]::IsNullOrWhiteSpace([string]$State.activeProject.name)) { $errors += "activeProject.name is required for project state" }
  if ([string]$State.kind -eq "project" -and [string]::IsNullOrWhiteSpace([string]$State.activeProject.slug)) { $errors += "activeProject.slug is required for project state" }
  foreach ($approvalName in @("projectSelected", "conceptPackage", "designTechPlan", "prototypeValidation", "productionUnblocked")) {
    if ($State.approvals.$approvalName -isnot [bool]) { $errors += "approvals.$approvalName must be boolean" }
  }
  if ($State.activeProject.approvedWritePaths -is [string]) { $errors += "activeProject.approvedWritePaths must be an array" }
  if ($State.assumptions -is [string]) { $errors += "assumptions must be an array" }
  if ($State.risks -is [string]) { $errors += "risks must be an array" }
  if ([string]$State.prototype.policy -eq "skipped-with-risk" -and [string]$State.prototype.verdict -eq "skipped" -and [string]::IsNullOrWhiteSpace([string]$State.prototype.skipReason)) {
    $errors += "prototype.skipReason is required when skipped with risk"
  }

  return [pscustomobject]@{ valid = $errors.Count -eq 0; errors = @($errors) }
}

function Write-MLGSJsonAtomic {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value, [int]$Depth = 30)

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
  $tempPath = Join-Path $directory ("." + [System.IO.Path]::GetFileName($Path) + "." + [guid]::NewGuid().ToString("N") + ".tmp")
  try {
    $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $tempPath -Encoding UTF8
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
  } finally {
    if (Test-Path $tempPath) { Remove-Item -LiteralPath $tempPath -Force }
  }
}

function Test-MLGSArtifactPattern {
  param([Parameter(Mandatory = $true)][string]$ProjectRoot, [Parameter(Mandatory = $true)][string]$Pattern)

  $normalized = $Pattern.Replace("/", [System.IO.Path]::DirectorySeparatorChar)
  if ($normalized.Contains("*")) {
    $directory = Split-Path -Parent $normalized
    $filter = Split-Path -Leaf $normalized
    $fullDirectory = Join-Path $ProjectRoot $directory
    if (-not (Test-Path $fullDirectory)) { return $false }
    return @(Get-ChildItem -LiteralPath $fullDirectory -Filter $filter -File -ErrorAction SilentlyContinue).Count -gt 0
  }
  return Test-Path (Join-Path $ProjectRoot $normalized)
}

function Get-MLGSStageRank {
  param([Parameter(Mandatory = $true)][string]$Stage)

  $stages = @("vertical-slice", "content-complete", "alpha", "beta", "release-candidate", "release")
  $rank = [array]::IndexOf($stages, $Stage)
  if ($rank -lt 0) { throw "Unknown product stage: $Stage" }
  return $rank
}

function Resolve-MLGSProjectArtifactPath {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  if ([System.IO.Path]::IsPathRooted($RelativePath)) { throw "Artifact paths must be project-relative: $RelativePath" }
  $projectFull = [System.IO.Path]::GetFullPath($ProjectRoot)
  $full = [System.IO.Path]::GetFullPath((Join-Path $projectFull $RelativePath))
  if (-not $full.StartsWith($projectFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Artifact path escaped the project root: $RelativePath"
  }
  return $full
}

function Test-MLGSQualityReport {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Stage,
    [string[]]$RequiredChecks = @()
  )

  $issues = @()
  try { $reportPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; stage = $Stage; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $reportPath)) {
    return [pscustomobject]@{ passed = $false; path = $reportPath; stage = $Stage; issues = @("Missing quality report: $Path") }
  }
  try { $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $reportPath; stage = $Stage; issues = @("Invalid quality report JSON: $($_.Exception.Message)") }
  }

  $requiredProperties = @("schemaVersion", "stage", "verdict", "ownerApproval", "updated", "checks", "blockers", "acceptedRisks", "notes")
  $propertyNames = @($report.PSObject.Properties.Name)
  foreach ($name in $requiredProperties) {
    if ($propertyNames -notcontains $name) { $issues += "Missing quality report property: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $reportPath; stage = $Stage; issues = @($issues) } }
  if ([string]$report.schemaVersion -ne "1.0") { $issues += "Quality report schemaVersion must be 1.0." }
  if ([string]$report.stage -ne $Stage) { $issues += "Quality report stage must be $Stage." }
  if ([string]$report.verdict -ne "pass") { $issues += "Quality report verdict must be pass." }
  if ($report.ownerApproval -isnot [bool] -or -not [bool]$report.ownerApproval) { $issues += "Quality report requires ownerApproval: true." }
  if ([string]::IsNullOrWhiteSpace([string]$report.updated)) { $issues += "Quality report updated timestamp is required." }
  if (@($report.blockers).Count -gt 0) { $issues += "Quality report still has blockers: $(@($report.blockers) -join '; ')" }

  $seen = @{}
  foreach ($check in @($report.checks)) {
    $id = [string]$check.id
    if ([string]::IsNullOrWhiteSpace($id)) { $issues += "Quality report contains a check without id."; continue }
    if ($seen.ContainsKey($id)) { $issues += "Duplicate quality check: $id" } else { $seen[$id] = $check }
  }
  foreach ($requiredId in @($RequiredChecks)) {
    if (-not $seen.ContainsKey($requiredId)) { $issues += "Missing required quality check: $requiredId"; continue }
    $check = $seen[$requiredId]
    if ([string]$check.status -ne "pass") { $issues += "Quality check is not pass: $requiredId" }
    if (@($check.evidence).Count -eq 0) { $issues += "Quality check has no evidence: $requiredId" }
  }

  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $reportPath; stage = $Stage; issues = @($issues) }
}

function Test-MLGSArtManifest {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$RequiredFor,
    [ValidateSet("planned", "prompt-ready", "generated", "selected", "processed", "imported", "referenced", "approved")][string]$MinimumStatus = "approved",
    [switch]$DisallowPlaceholders,
    [string[]]$RequiredKinds = @()
  )

  $issues = @()
  $statusOrder = @("planned", "prompt-ready", "generated", "selected", "processed", "imported", "referenced", "approved")
  $minimumRank = [array]::IndexOf($statusOrder, $MinimumStatus)
  $requiredStageRank = Get-MLGSStageRank -Stage $RequiredFor
  try { $manifestPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; requiredFor = $RequiredFor; checkedAssets = 0; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $manifestPath)) {
    return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedAssets = 0; issues = @("Missing art asset manifest: $Path") }
  }
  try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedAssets = 0; issues = @("Invalid art manifest JSON: $($_.Exception.Message)") }
  }
  $manifestNames = @($manifest.PSObject.Properties.Name)
  foreach ($name in @("schemaVersion", "updated", "assets")) {
    if ($manifestNames -notcontains $name) { $issues += "Art manifest property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedAssets = 0; issues = @($issues) } }
  if ([string]$manifest.schemaVersion -ne "1.0") { $issues += "Art manifest schemaVersion must be 1.0." }

  $ids = @{}
  $requiredAssets = @()
  foreach ($asset in @($manifest.assets)) {
    $assetNames = @($asset.PSObject.Properties.Name)
    $requiredAssetProperties = @("id", "kind", "usage", "requiredFor", "sourceType", "source", "license", "promptMetadata", "sourceFile", "outputPath", "status", "placeholder", "importRecipe", "references", "evidence")
    $missingAssetProperties = @($requiredAssetProperties | Where-Object { $assetNames -notcontains $_ })
    if ($missingAssetProperties.Count -gt 0) { $issues += "Art asset is missing properties: $($missingAssetProperties -join ', ')"; continue }
    $id = [string]$asset.id
    if ([string]::IsNullOrWhiteSpace($id)) { $issues += "Art asset is missing id."; continue }
    if ($ids.ContainsKey($id)) { $issues += "Duplicate art asset id: $id" } else { $ids[$id] = $true }
    try { $assetStageRank = Get-MLGSStageRank -Stage ([string]$asset.requiredFor) } catch { $issues += "${id}: $($_.Exception.Message)"; continue }
    if ($assetStageRank -le $requiredStageRank) { $requiredAssets += $asset }
  }
  if ($requiredAssets.Count -eq 0) { $issues += "No art assets are assigned to $RequiredFor or an earlier stage." }

  foreach ($kind in @($RequiredKinds)) {
    if (@($requiredAssets | Where-Object { [string]$_.kind -eq $kind }).Count -eq 0) { $issues += "Required art kind is missing: $kind" }
  }

  foreach ($asset in $requiredAssets) {
    $id = [string]$asset.id
    foreach ($name in @("kind", "usage", "sourceType", "source", "license", "sourceFile", "outputPath", "status", "importRecipe")) {
      if (-not ($asset.PSObject.Properties.Name -contains $name) -or [string]::IsNullOrWhiteSpace([string]$asset.$name)) { $issues += "${id}: missing $name" }
    }
    $statusRank = [array]::IndexOf($statusOrder, [string]$asset.status)
    if ($statusRank -lt $minimumRank) { $issues += "${id}: status '$($asset.status)' is below '$MinimumStatus'." }
    if ($DisallowPlaceholders -and [bool]$asset.placeholder) { $issues += "${id}: placeholder assets are not allowed for $RequiredFor." }

    foreach ($assetPathProperty in @("sourceFile", "outputPath", "importRecipe")) {
      $relative = [string]$asset.$assetPathProperty
      if ([string]::IsNullOrWhiteSpace($relative)) { continue }
      try { $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $relative } catch { $issues += "${id}: $($_.Exception.Message)"; continue }
      if (-not (Test-Path $full)) { $issues += "${id}: missing $assetPathProperty file: $relative" }
    }
    if ([string]$asset.sourceType -eq "generated" -and $statusRank -ge 1) {
      if ([string]::IsNullOrWhiteSpace([string]$asset.promptMetadata)) { $issues += "${id}: generated asset needs promptMetadata." }
      else {
        try { $promptPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$asset.promptMetadata) } catch { $issues += "${id}: $($_.Exception.Message)"; $promptPath = "" }
        if ($promptPath -and -not (Test-Path $promptPath)) { $issues += "${id}: missing prompt metadata: $($asset.promptMetadata)" }
      }
    }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "referenced") -and @($asset.references).Count -eq 0) { $issues += "${id}: referenced/approved asset needs Unity references." }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "approved") -and @($asset.evidence).Count -eq 0) { $issues += "${id}: approved asset needs in-game evidence." }
  }

  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $manifestPath; requiredFor = $RequiredFor; checkedAssets = $requiredAssets.Count; issues = @($issues) }
}

function Test-MLGSCodeAudit {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$AllowWarnings
  )

  try { $auditPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $auditPath)) { return [pscustomobject]@{ passed = $false; path = $auditPath; issues = @("Missing production code audit: $Path") } }
  try { $audit = Get-Content -LiteralPath $auditPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $auditPath; issues = @("Invalid production code audit JSON: $($_.Exception.Message)") }
  }
  $issues = @()
  $names = @($audit.PSObject.Properties.Name)
  foreach ($name in @("schemaVersion", "verdict", "scannedFiles", "errorCount", "warningCount", "findings")) {
    if ($names -notcontains $name) { $issues += "Production code audit property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $auditPath; issues = @($issues) } }
  if ([string]$audit.schemaVersion -ne "1.0") { $issues += "Production code audit schemaVersion must be 1.0." }
  if ([int]$audit.scannedFiles -le 0) { $issues += "Production code audit scanned no C# files." }
  if ([int]$audit.errorCount -gt 0 -or [string]$audit.verdict -eq "fail") { $issues += "Production code audit has blocking errors." }
  if (-not $AllowWarnings -and [int]$audit.warningCount -gt 0) { $issues += "Production code audit warnings must be resolved for this gate." }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $auditPath; issues = @($issues) }
}

function Get-MLGSGateEvaluation {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    $State = $null
  )

  $catalogPath = Join-Path $Root "workflow/catalog.json"
  $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $gateResults = [ordered]@{}
  foreach ($gateProperty in $catalog.gates.PSObject.Properties) {
    $gate = $gateProperty.Value
    $missing = @()
    foreach ($pattern in @($gate.all)) {
      if (-not (Test-MLGSArtifactPattern $ProjectRoot $pattern)) { $missing += $pattern }
    }

    $artifactPass = $missing.Count -eq 0
    $approvalPass = $true
    if ($gate.PSObject.Properties.Name -contains "approval") {
      $approvalName = [string]$gate.approval
      $approvalPass = $false
      if ($null -ne $State -and $State.approvals.PSObject.Properties.Name -contains $approvalName) {
        $approvalPass = [bool]$State.approvals.$approvalName
      }
    }

    $skipped = $false
    if (($gate.PSObject.Properties.Name -contains "allowSkippedWithRisk") -and [bool]$gate.allowSkippedWithRisk -and $null -ne $State) {
      $skipped = [string]$State.prototype.policy -eq "skipped-with-risk" -and [string]$State.prototype.verdict -eq "skipped" -and -not [string]::IsNullOrWhiteSpace([string]$State.prototype.skipReason)
    }

    $qualityPass = $true
    $qualityIssues = @()
    if ($gate.PSObject.Properties.Name -contains "qualityReport") {
      $quality = $gate.qualityReport
      $qualityResult = Test-MLGSQualityReport -ProjectRoot $ProjectRoot -Path ([string]$quality.path) -Stage ([string]$quality.stage) -RequiredChecks @($quality.requiredChecks)
      $qualityPass = [bool]$qualityResult.passed
      $qualityIssues = @($qualityResult.issues)
    }

    $artPass = $true
    $artIssues = @()
    if ($gate.PSObject.Properties.Name -contains "artManifest") {
      $art = $gate.artManifest
      $requiredKinds = @()
      if ($art.PSObject.Properties.Name -contains "requiredKinds") { $requiredKinds = @($art.requiredKinds) }
      $artArgs = @{
        ProjectRoot = $ProjectRoot
        Path = [string]$art.path
        RequiredFor = [string]$art.requiredFor
        MinimumStatus = [string]$art.minimumStatus
        RequiredKinds = $requiredKinds
      }
      if (($art.PSObject.Properties.Name -contains "disallowPlaceholders") -and [bool]$art.disallowPlaceholders) { $artArgs.DisallowPlaceholders = $true }
      $artResult = Test-MLGSArtManifest @artArgs
      $artPass = [bool]$artResult.passed
      $artIssues = @($artResult.issues)
    }

    $codeAuditPass = $true
    $codeAuditIssues = @()
    if ($gate.PSObject.Properties.Name -contains "codeAudit") {
      $audit = $gate.codeAudit
      $allowWarnings = ($audit.PSObject.Properties.Name -contains "allowWarnings") -and [bool]$audit.allowWarnings
      $codeAuditResult = Test-MLGSCodeAudit -ProjectRoot $ProjectRoot -Path ([string]$audit.path) -AllowWarnings:$allowWarnings
      $codeAuditPass = [bool]$codeAuditResult.passed
      $codeAuditIssues = @($codeAuditResult.issues)
    }

    $gateResults[$gateProperty.Name] = [pscustomobject]@{
      passed = (($artifactPass -and $approvalPass -and $qualityPass -and $artPass -and $codeAuditPass) -or ($skipped -and $approvalPass -and $qualityPass -and $artPass -and $codeAuditPass))
      artifactsPassed = $artifactPass
      approvalPassed = $approvalPass
      qualityPassed = $qualityPass
      artPassed = $artPass
      codeAuditPassed = $codeAuditPass
      skippedWithRisk = $skipped
      missing = @($missing)
      qualityIssues = @($qualityIssues)
      artIssues = @($artIssues)
      codeAuditIssues = @($codeAuditIssues)
    }
  }

  $phase = "intake"
  $command = "/mlgs status"
  $reason = "Select or adopt a project."
  $options = @("/mlgs start a new Unity game", "/mlgs adopt <UnityProject>")
  $projectReady = [bool]$gateResults["project-selected"].passed
  $conceptReady = $projectReady -and [bool]$gateResults["concept-approved"].passed
  $planReady = $conceptReady -and [bool]$gateResults["plan-approved"].passed
  $prototypeReady = $planReady -and [bool]$gateResults["prototype-passed-or-skipped"].passed
  $productionReady = $prototypeReady -and [bool]$gateResults["production-unblocked"].passed
  $verticalSliceReady = $productionReady -and [bool]$gateResults["vertical-slice-approved"].passed
  $contentCompleteReady = $verticalSliceReady -and [bool]$gateResults["content-complete-approved"].passed
  $alphaReady = $contentCompleteReady -and [bool]$gateResults["alpha-approved"].passed
  $betaReady = $alphaReady -and [bool]$gateResults["beta-approved"].passed
  $releaseCandidateReady = $betaReady -and [bool]$gateResults["release-candidate-approved"].passed
  $releaseReady = $releaseCandidateReady -and [bool]$gateResults["release-approved"].passed
  if ($projectReady) {
    $phase = "concept"; $command = "/mlgs brainstorm and create the concept package"; $reason = "The concept gate is incomplete."; $options = @($command, "/mlgs review the concept")
  }
  if ($conceptReady) {
    $phase = "plan"; $command = "/mlgs plan systems and tasks"; $reason = "The plan gate is incomplete."; $options = @($command, "/mlgs review the plan")
  }
  if ($planReady) {
    $phase = "prototype"; $command = "/mlgs validate the core prototype"; $reason = "The prototype gate is incomplete."; $options = @($command, "/mlgs define QA checks")
  }
  if ($prototypeReady) {
    $phase = "prototype"; $command = "/mlgs review and unblock production"; $reason = "Prototype evidence exists, but production is not unblocked."; $options = @($command, "/mlgs review current risks")
  }
  if ($productionReady) {
    $phase = "vertical-slice"; $command = "/mlgs build the final-quality vertical slice"; $reason = "Production is unblocked; prove the final-quality pipeline before content scale-up."; $options = @($command, "/mlgs generate and integrate required art", "/mlgs review the vertical slice gate")
  }
  if ($verticalSliceReady) {
    $phase = "production"; $command = "/mlgs continue production toward content complete"; $reason = "The Vertical Slice is approved; complete all release-scope features and content."; $options = @($command, "/mlgs process the next art assets", "/mlgs review content completeness")
  }
  if ($contentCompleteReady) {
    $phase = "alpha"; $command = "/mlgs stabilize the full game for Alpha"; $reason = "Content Complete passed; focus on blockers, full flows, references, performance, and crash-free smoke."; $options = @($command, "/mlgs run the Alpha quality gate", "/mlgs review production code")
  }
  if ($alphaReady) {
    $phase = "beta"; $command = "/mlgs prepare Beta icon localization and crash checks"; $reason = "Alpha passed; validate target-device regression and game-facing release content."; $options = @($command, "/mlgs run localization checks", "/mlgs run crash and error smoke")
  }
  if ($betaReady) {
    $phase = "release-candidate"; $command = "/mlgs prepare and validate the release candidate"; $reason = "Beta passed; lock the candidate after final icon, localization, crash/error, build, and known-issue evidence."; $options = @($command, "/mlgs build the release candidate", "/mlgs review release readiness")
  }
  if ($releaseCandidateReady) {
    $phase = "release"; $command = "/mlgs run the final release smoke"; $reason = "The Release Candidate is approved; perform the final locked-candidate smoke."; $options = @($command, "/mlgs verify the final build", "/mlgs review known issues")
  }
  if ($releaseReady) {
    $phase = "release"; $command = "/mlgs status"; $reason = "MLGS game-content release gates passed."; $options = @("/mlgs review final evidence", "/mlgs show the release dashboard")
  }

  $declaredPhase = $(if ($null -ne $State) { [string]$State.phase.current } else { "" })
  return [pscustomobject]@{
    observedPhase = $phase
    declaredPhase = $declaredPhase
    phaseMismatch = (-not [string]::IsNullOrWhiteSpace($declaredPhase)) -and $declaredPhase -ne $phase
    recommendedCommand = $command
    reason = $reason
    options = @($options)
    gates = [pscustomobject]$gateResults
  }
}
