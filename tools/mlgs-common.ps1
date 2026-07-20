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

function Get-MLGSNormalizedProjectRoot {
  param([Parameter(Mandatory = $true)][string]$ProjectRoot)

  return [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\', '/').ToLowerInvariant()
}

function Get-MLGSProjectId {
  param([Parameter(Mandatory = $true)][string]$ProjectRoot)

  $normalized = Get-MLGSNormalizedProjectRoot -ProjectRoot $ProjectRoot
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
    $hash = $sha.ComputeHash($bytes)
  } finally {
    $sha.Dispose()
  }
  $hex = -join ($hash | ForEach-Object { $_.ToString("x2") })
  $slug = (Split-Path -Leaf ([System.IO.Path]::GetFullPath($ProjectRoot))).ToLowerInvariant() -replace '[^a-z0-9]+', '-'
  $slug = $slug.Trim('-')
  if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "project" }
  return "$slug-$($hex.Substring(0, 12))"
}

function Get-MLGSProjectRuntimeRoot {
  param(
    [Parameter(Mandatory = $true)][string]$GlobalRuntimeRoot,
    [Parameter(Mandatory = $true)][string]$ProjectRoot
  )

  $projectId = Get-MLGSProjectId -ProjectRoot $ProjectRoot
  return [System.IO.Path]::GetFullPath((Join-Path $GlobalRuntimeRoot ("projects/" + $projectId)))
}

function Test-MLGSPathOverlap {
  param(
    [Parameter(Mandatory = $true)][string]$Left,
    [Parameter(Mandatory = $true)][string]$Right
  )

  $leftPath = $Left.Replace("\", "/").Trim("/").ToLowerInvariant()
  $rightPath = $Right.Replace("\", "/").Trim("/").ToLowerInvariant()
  if (-not $leftPath -or -not $rightPath) { return $false }
  if ($leftPath -eq "*" -or $rightPath -eq "*") { return $true }
  return $leftPath -eq $rightPath -or $leftPath.StartsWith($rightPath + "/") -or $rightPath.StartsWith($leftPath + "/")
}

function Test-MLGSPathWithinClaim {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Claim
  )

  $pathValue = $Path.Replace("\", "/").Trim("/").ToLowerInvariant()
  $claimValue = $Claim.Replace("\", "/").Trim("/").ToLowerInvariant()
  if (-not $pathValue -or -not $claimValue) { return $false }
  return $claimValue -eq "*" -or $pathValue -eq $claimValue -or $pathValue.StartsWith($claimValue + "/")
}

function Test-MLGSActiveProjectLease {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRuntimeRoot,
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [Parameter(Mandatory = $true)][string]$InvocationId
  )

  $issues = @()
  $leasePath = Join-Path $ProjectRuntimeRoot ("leases/" + $InvocationId + ".json")
  $lease = $null
  if (-not (Test-Path $leasePath)) {
    $issues += "Missing active project write lease for invocation '$InvocationId'."
  } else {
    try { $lease = Get-Content -LiteralPath $leasePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Project write lease is unreadable." }
  }
  if ($lease) {
    if ([string]$lease.projectId -ne $ProjectId) { $issues += "Project write lease belongs to a different project." }
    if ([string]$lease.invocationId -ne $InvocationId) { $issues += "Project write lease invocation does not match." }
    if ([bool]$lease.readOnly) { $issues += "A read-only lease cannot authorize project writes." }
    if (@($lease.paths).Count -eq 0) { $issues += "Project write lease has no declared paths." }
    try {
      if ([DateTimeOffset]::Parse([string]$lease.expiresAt) -le [DateTimeOffset]::Now) { $issues += "Project write lease has expired." }
    } catch { $issues += "Project write lease expiry is invalid." }
  }
  return [pscustomobject]@{ valid = $issues.Count -eq 0; path = $leasePath; lease = $lease; issues = @($issues) }
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

function Test-MLGSProjectEvidencePath {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath)) { return "$Label is empty." }
  try { $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $RelativePath } catch { return "$Label is invalid: $($_.Exception.Message)" }
  if (-not (Test-Path $full)) { return "$Label does not exist: $RelativePath" }
  return ""
}

function Test-MLGSVisualTarget {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $issues = @()
  try { $targetPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; approvedIds = @(); issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $targetPath)) {
    return [pscustomobject]@{ passed = $false; path = $targetPath; approvedIds = @(); issues = @("Missing visual target manifest: $Path") }
  }
  try { $document = Get-Content -LiteralPath $targetPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $targetPath; approvedIds = @(); issues = @("Invalid visual target JSON: $($_.Exception.Message)") }
  }
  foreach ($name in @("schemaVersion", "updated", "targets")) {
    if (@($document.PSObject.Properties.Name) -notcontains $name) { $issues += "Visual target property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $targetPath; approvedIds = @(); issues = @($issues) } }
  if ([string]$document.schemaVersion -ne "1.0") { $issues += "Visual target schemaVersion must be 1.0." }
  if ([string]::IsNullOrWhiteSpace([string]$document.updated)) { $issues += "Visual target updated timestamp is required." }
  $ids = @{}
  $approvedIds = @()
  foreach ($target in @($document.targets)) {
    $names = @($target.PSObject.Properties.Name)
    foreach ($name in @("id", "usage", "imagePath", "source", "approved", "nonNegotiables", "forbidden", "targetResolution")) {
      if ($names -notcontains $name) { $issues += "Visual target is missing property: $name" }
    }
    if ($names -notcontains "id") { continue }
    $id = [string]$target.id
    if ([string]::IsNullOrWhiteSpace($id)) { $issues += "Visual target id is empty."; continue }
    if ($ids.ContainsKey($id)) { $issues += "Duplicate visual target id: $id" } else { $ids[$id] = $true }
    foreach ($name in @("usage", "imagePath", "source", "targetResolution")) {
      if ([string]::IsNullOrWhiteSpace([string]$target.$name)) { $issues += "${id}: visual target $name is required." }
    }
    if (-not [bool]$target.approved) { continue }
    $approvedIds += $id
    if (@($target.nonNegotiables).Count -eq 0) { $issues += "${id}: approved visual target needs nonNegotiables." }
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$target.imagePath) -Label "${id} imagePath"
    if ($pathIssue) { $issues += $pathIssue }
  }
  if ($approvedIds.Count -eq 0) { $issues += "At least one visual target image must be approved." }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $targetPath; approvedIds = @($approvedIds); issues = @($issues) }
}

function Test-MLGSProductionCapabilities {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$RequiredFor,
    [string[]]$RequiredCapabilityKinds = @()
  )

  $issues = @()
  try { $manifestPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; required = @(); issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $manifestPath)) { return [pscustomobject]@{ passed = $false; path = $manifestPath; required = @(); issues = @("Missing capability manifest: $Path") } }
  try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $manifestPath; required = @(); issues = @("Invalid capability manifest JSON: $($_.Exception.Message)") }
  }
  if ([string]$manifest.schemaVersion -ne "1.0") { $issues += "Capability manifest schemaVersion must be 1.0." }
  $required = @($RequiredCapabilityKinds)
  if ($required.Count -eq 0) {
    $artPath = Join-Path $ProjectRoot "production/assets/asset-manifest.json"
    if (-not (Test-Path $artPath)) { $issues += "Cannot derive capabilities without an art asset manifest." }
    else {
      try { $art = Get-Content -LiteralPath $artPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid art asset manifest JSON."; $art = $null }
      if ($art) {
        $stageRank = Get-MLGSStageRank -Stage $RequiredFor
        foreach ($asset in @($art.assets)) {
          try { if ((Get-MLGSStageRank -Stage ([string]$asset.requiredFor)) -gt $stageRank) { continue } } catch { continue }
          $kind = ([string]$asset.kind).ToLowerInvariant()
          $visual = $false
          if ($kind -match "sprite|texture|ui|icon|background|portrait|illustration") {
            $visual = $true
            if ([string]$asset.sourceType -eq "generated") { $required += "image-generation" }
            $required += "sprite-processing"
          }
          elseif ($kind -match "mesh|model|3d") {
            $visual = $true
            $required += "mesh-production"
          }
          elseif ($kind -match "anim") {
            $visual = $true
            $required += "animation-production"
          }
          elseif ($kind -match "audio|music|sfx|voice|speech") { $required += "audio-production" }
          elseif ($kind -match "video|cinematic|trailer") { $required += "video-production" }
          else { $visual = $true; $required += "image-generation" }
          $required += @("unity-import", "unity-validation")
          if ($visual) { $required += "visual-comparison" }
        }
      }
    }
  }
  $required = @($required | Select-Object -Unique)
  foreach ($kind in $required) {
    $entry = @($manifest.capabilities | Where-Object { [string]$_.kind -eq [string]$kind }) | Select-Object -First 1
    if (-not $entry) { $issues += "Required capability is not declared: $kind"; continue }
    if ([string]$entry.status -ne "ready") { $issues += "Required capability is not ready: $kind ($($entry.status))"; continue }
    if (@("unity-validation", "visual-comparison") -contains [string]$kind -and -not [bool]$entry.supportsVerification) { $issues += "$($kind): verification support is required." }
    if (@($entry.evidence).Count -eq 0) { $issues += "$($kind): ready capability needs evidence." }
    foreach ($evidence in @($entry.evidence)) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$evidence) -Label "$($kind) capability evidence"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $manifestPath; required = @($required); issues = @($issues) }
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

  $requiredProperties = @("schemaVersion", "stage", "verdict", "declaredVerdict", "objectiveVerdict", "ownerApproval", "updated", "checks", "blockers", "acceptedRisks", "notes")
  $propertyNames = @($report.PSObject.Properties.Name)
  foreach ($name in $requiredProperties) {
    if ($propertyNames -notcontains $name) { $issues += "Missing quality report property: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $reportPath; stage = $Stage; issues = @($issues) } }
  if ([string]$report.schemaVersion -ne "1.1") { $issues += "Quality report schemaVersion must be 1.1." }
  if ([string]$report.stage -ne $Stage) { $issues += "Quality report stage must be $Stage." }
  if ([string]$report.verdict -ne "pass") { $issues += "Quality report verdict must be pass." }
  if ([string]$report.declaredVerdict -ne "pass") { $issues += "Quality report declaredVerdict must be pass." }
  if ([string]$report.objectiveVerdict -ne "pass") { $issues += "Quality report objectiveVerdict must be pass." }
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
    if ([string]$check.objectiveVerdict -ne "pass") { $issues += "Quality check objective verdict is not pass: $requiredId" }
    if (@($check.objectiveChecks).Count -eq 0) { $issues += "Quality check has no objective checks: $requiredId" }
    foreach ($objectiveCheck in @($check.objectiveChecks)) {
      if ([string]$objectiveCheck.status -ne "pass") { $issues += "Objective check is not pass: $requiredId/$($objectiveCheck.id)" }
    }
    foreach ($evidencePath in @($check.evidence)) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$evidencePath) -Label "Quality check '$requiredId' evidence"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }

  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $reportPath; stage = $Stage; issues = @($issues) }
}

function Test-MLGSVisualComparisonReport {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [ValidateSet("asset", "scene")][string]$ExpectedMode = "asset"
  )

  $issues = @()
  try { $reportPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $reportPath)) { return [pscustomobject]@{ passed = $false; path = $reportPath; issues = @("Missing visual comparison report: $Path") } }
  try { $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $reportPath; issues = @("Invalid visual comparison report JSON: $($_.Exception.Message)") }
  }
  foreach ($name in @("schemaVersion", "mode", "targetImage", "candidateImage", "algorithm", "generatedAt", "scores", "thresholds", "verdict", "limitations")) {
    if (@($report.PSObject.Properties.Name) -notcontains $name) { $issues += "Visual comparison property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $reportPath; issues = @($issues) } }
  if ([string]$report.schemaVersion -ne "1.0") { $issues += "Visual comparison schemaVersion must be 1.0." }
  if ([string]$report.mode -ne $ExpectedMode) { $issues += "Visual comparison mode must be $ExpectedMode." }
  if ([string]$report.verdict -ne "pass") { $issues += "Visual comparison verdict must be pass." }
  if ([string]::IsNullOrWhiteSpace([string]$report.algorithm)) { $issues += "Visual comparison algorithm is required." }
  if ([string]::IsNullOrWhiteSpace([string]$report.generatedAt)) { $issues += "Visual comparison generatedAt is required." }
  if (@($report.limitations).Count -eq 0) { $issues += "Visual comparison limitations must be explicit." }
  foreach ($property in @("targetImage", "candidateImage")) {
    $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$report.$property) -Label "Visual comparison $property"
    if ($pathIssue) { $issues += $pathIssue }
  }
  $expectedScoreNames = if ($ExpectedMode -eq "asset") { @("targetMatch", "composition", "palette", "value", "material", "detail", "readability") } else { @("targetMatch", "composition", "spatialLayout", "depthLighting", "materialLanguage", "detailDensity", "diegeticIntegration", "readability") }
  $scoreNames = @($report.scores.PSObject.Properties.Name)
  foreach ($name in $expectedScoreNames) {
    if ($scoreNames -notcontains $name) { $issues += "Visual comparison score is missing: $name"; continue }
    if (@($report.thresholds.PSObject.Properties.Name) -notcontains $name) { $issues += "Visual comparison threshold is missing: $name"; continue }
    $score = [int]$report.scores.$name
    $threshold = [int]$report.thresholds.$name
    if ($score -lt 0 -or $score -gt 100 -or $threshold -lt 0 -or $threshold -gt 100) { $issues += "Visual comparison score/threshold is outside 0-100: $name" }
    elseif ($score -lt $threshold) { $issues += "Visual comparison score is below threshold: $name ($score < $threshold)" }
  }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $reportPath; report = $report; issues = @($issues) }
}

function Test-MLGSArtImportRecipe {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)]$Asset
  )

  $issues = @()
  $assetId = [string]$Asset.id
  try { $recipePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; assetId = $assetId; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $recipePath)) { return [pscustomobject]@{ passed = $false; path = $recipePath; assetId = $assetId; issues = @("Missing art import recipe: $Path") } }
  try { $recipe = Get-Content -LiteralPath $recipePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $recipePath; assetId = $assetId; issues = @("Invalid art import recipe JSON: $($_.Exception.Message)") }
  }
  $required = @("schemaVersion", "assetId", "texturePath", "textureType", "spriteMode", "pixelsPerUnit", "pivot", "border", "meshType", "alphaIsTransparency", "mipmaps", "filterMode", "wrapMode", "maxSize", "compression", "sourceLayout", "extractionMode", "integrityGate", "slicing", "atlas", "addressable", "platformOverrides", "unityImporterEvidence", "nineSliceEvidence")
  foreach ($name in $required) {
    if (@($recipe.PSObject.Properties.Name) -notcontains $name) { $issues += "Art import recipe property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $recipePath; assetId = $assetId; issues = @($issues) } }
  if ([string]$recipe.schemaVersion -ne "1.0") { $issues += "Art import recipe schemaVersion must be 1.0." }
  if ([string]$recipe.assetId -ne $assetId) { $issues += "Art import recipe assetId must be $assetId." }
  if ([string]$recipe.texturePath -ne [string]$Asset.outputPath) { $issues += "Art import recipe texturePath must match the asset outputPath." }
  $enumChecks = @{
    textureType = @("Sprite", "Default", "NormalMap", "GUI")
    spriteMode = @("Single", "Multiple", "Polygon")
    meshType = @("Tight", "FullRect")
    filterMode = @("Point", "Bilinear", "Trilinear")
    wrapMode = @("Clamp", "Repeat", "Mirror", "MirrorOnce")
    compression = @("Uncompressed", "Compressed", "CompressedHQ", "CompressedLQ")
  }
  foreach ($name in $enumChecks.Keys) {
    if (@($enumChecks[$name]) -notcontains [string]$recipe.$name) { $issues += "Art import recipe $name is invalid: $($recipe.$name)" }
  }
  if (@(32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384) -notcontains [int]$recipe.maxSize) { $issues += "Art import recipe maxSize must be a supported power-of-two size." }
  if ([double]$recipe.pixelsPerUnit -le 0) { $issues += "Art import recipe pixelsPerUnit must be greater than zero." }
  if (@($recipe.pivot).Count -ne 2 -or @($recipe.pivot | Where-Object { [double]$_ -lt 0 -or [double]$_ -gt 1 }).Count -gt 0) { $issues += "Art import recipe pivot must contain two normalized values." }
  if (@($recipe.border).Count -ne 4 -or @($recipe.border | Where-Object { [double]$_ -lt 0 }).Count -gt 0) { $issues += "Art import recipe border must contain four non-negative values." }
  if ([string]$recipe.sourceLayout -ne [string]$Asset.integrity.sourceLayout) { $issues += "Art import recipe sourceLayout must match the asset integrity contract." }
  if ([string]$recipe.extractionMode -ne [string]$Asset.integrity.extractionMode) { $issues += "Art import recipe extractionMode must match the asset integrity contract." }
  if ([string]$recipe.sourceLayout -eq "unverified-sheet") { $issues += "Unverified sheets cannot be used by a formal import recipe." }
  if ([string]$recipe.extractionMode -eq "fixed-grid") {
    if ([string]$recipe.sourceLayout -ne "registered-sheet") { $issues += "Fixed-grid import requires registered-sheet sourceLayout." }
    if ([string]$recipe.slicing.mode -ne "fixed-grid" -or [int]$recipe.slicing.cellSize[0] -le 0 -or [int]$recipe.slicing.cellSize[1] -le 0) { $issues += "Fixed-grid import requires positive slicing cellSize." }
  }
  if ([string]$recipe.extractionMode -eq "explicit-rectangles" -and @($recipe.slicing.rects).Count -eq 0) { $issues += "Explicit-rectangles import requires slicing rects." }
  foreach ($name in @("minimumTransparentMargin", "minimumFrameMargin", "expectedFrames", "maxSignificantComponents", "maxBaselineVariance", "maxFrameSizeVarianceRatio")) {
    if (@($recipe.integrityGate.PSObject.Properties.Name) -notcontains $name) { $issues += "Art import integrityGate property is missing: $name"; continue }
    if ([double]$recipe.integrityGate.$name -ne [double]$Asset.integrity.$name) { $issues += "Art import integrityGate.$name must match the asset integrity contract." }
  }
  $statusOrder = @("planned", "prompt-ready", "generated", "selected", "processed", "imported", "referenced", "approved")
  $statusRank = [array]::IndexOf($statusOrder, [string]$Asset.status)
  if ($statusRank -ge [array]::IndexOf($statusOrder, "imported")) {
    if (@($recipe.unityImporterEvidence).Count -eq 0) { $issues += "Imported art needs Unity importer evidence in its recipe." }
    foreach ($relative in @($recipe.unityImporterEvidence)) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "$assetId Unity importer evidence"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }
  if ($statusRank -ge [array]::IndexOf($statusOrder, "approved") -and @($recipe.border | Where-Object { [double]$_ -gt 0 }).Count -gt 0) {
    if (@($recipe.nineSliceEvidence).Count -lt 3) { $issues += "Approved nine-slice art needs evidence at three target sizes." }
    foreach ($relative in @($recipe.nineSliceEvidence)) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "$assetId nine-slice evidence"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $recipePath; assetId = $assetId; issues = @($issues) }
}

function Test-MLGSArtReview {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$AssetId = ""
  )

  $issues = @()
  try { $reviewPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; assetId = $AssetId; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $reviewPath)) {
    return [pscustomobject]@{ passed = $false; path = $reviewPath; assetId = $AssetId; issues = @("Missing art review: $Path") }
  }
  try { $review = Get-Content -LiteralPath $reviewPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $reviewPath; assetId = $AssetId; issues = @("Invalid art review JSON: $($_.Exception.Message)") }
  }
  $required = @("schemaVersion", "assetId", "visualTargetIds", "targetImages", "candidateSource", "processedAsset", "unityReferences", "inGameScreenshots", "comparisonReport", "scores", "automatedVerdict", "artDirectorVerdict", "qaVerdict", "finalVerdict", "attempt", "maxAttempts", "blockers", "updated")
  foreach ($name in $required) {
    if (@($review.PSObject.Properties.Name) -notcontains $name) { $issues += "Art review property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $reviewPath; assetId = $AssetId; issues = @($issues) } }
  if ([string]$review.schemaVersion -ne "1.1") { $issues += "Art review schemaVersion must be 1.1." }
  if ($AssetId -and [string]$review.assetId -ne $AssetId) { $issues += "Art review assetId must be $AssetId." }
  if ([int]$review.maxAttempts -lt 1 -or [int]$review.maxAttempts -gt 5) { $issues += "Art review maxAttempts must be between 1 and 5." }
  if ([int]$review.attempt -lt 1 -or [int]$review.attempt -gt [int]$review.maxAttempts) { $issues += "Art review attempt must be between 1 and maxAttempts." }
  if (@($review.visualTargetIds).Count -eq 0) { $issues += "Art review needs visualTargetIds." }
  foreach ($property in @("targetImages", "unityReferences", "inGameScreenshots")) {
    if (@($review.$property).Count -eq 0) { $issues += "Art review needs $property." }
    foreach ($relative in @($review.$property)) {
      $issue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Art review $property"
      if ($issue) { $issues += $issue }
    }
  }
  foreach ($property in @("candidateSource", "processedAsset")) {
    $issue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$review.$property) -Label "Art review $property"
    if ($issue) { $issues += $issue }
  }
  if ([string]::IsNullOrWhiteSpace([string]$review.comparisonReport)) { $issues += "Art review needs comparisonReport." }
  else {
    $comparisonResult = Test-MLGSVisualComparisonReport -ProjectRoot $ProjectRoot -Path ([string]$review.comparisonReport) -ExpectedMode asset
    if (-not $comparisonResult.passed) { $issues += @($comparisonResult.issues) }
  }
  if ([int]$review.scores.targetMatch -lt 0 -or [int]$review.scores.targetMatch -gt 100) { $issues += "Art review targetMatch score must be between 0 and 100." }
  elseif ([int]$review.scores.targetMatch -lt 80) { $issues += "Art review targetMatch score must be at least 80." }
  foreach ($name in @("composition", "palette", "value", "material", "detail", "readability")) {
    if ([int]$review.scores.$name -lt 0 -or [int]$review.scores.$name -gt 100) { $issues += "Art review $name score must be between 0 and 100." }
    elseif ([int]$review.scores.$name -lt 70) { $issues += "Art review $name score must be at least 70." }
  }
  if ([string]$review.automatedVerdict -ne "pass") { $issues += "Art review automatedVerdict must be pass; unavailable and errors fail closed." }
  if ([string]$review.artDirectorVerdict -ne "pass") { $issues += "Art review requires Art Director pass." }
  if ([string]$review.qaVerdict -ne "pass") { $issues += "Art review requires QA pass." }
  if ([string]$review.finalVerdict -ne "pass") { $issues += "Art review finalVerdict must be pass." }
  if (@($review.blockers).Count -gt 0) { $issues += "Art review still has blockers: $(@($review.blockers) -join '; ')" }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $reviewPath; assetId = [string]$review.assetId; issues = @($issues) }
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
  foreach ($name in @("schemaVersion", "updated", "visualTargetPath", "assets")) {
    if ($manifestNames -notcontains $name) { $issues += "Art manifest property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedAssets = 0; issues = @($issues) } }
  if ([string]$manifest.schemaVersion -ne "1.4") { $issues += "Art manifest schemaVersion must be 1.4." }
  $visualTargetResult = Test-MLGSVisualTarget -ProjectRoot $ProjectRoot -Path ([string]$manifest.visualTargetPath)
  if (-not $visualTargetResult.passed) { $issues += @($visualTargetResult.issues) }
  $approvedVisualTargets = @{}
  foreach ($visualTargetId in @($visualTargetResult.approvedIds)) { $approvedVisualTargets[[string]$visualTargetId] = $true }

  $ids = @{}
  $requiredAssets = @()
  foreach ($asset in @($manifest.assets)) {
    $assetNames = @($asset.PSObject.Properties.Name)
    $requiredAssetProperties = @("id", "kind", "usage", "requiredFor", "visualTargets", "sourceType", "source", "license", "promptMetadata", "sourceFile", "outputPath", "status", "statusHistory", "placeholder", "importRecipe", "integrity", "references", "evidence", "reviewPath")
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
    if ($statusRank -lt 0) { $issues += "${id}: invalid lifecycle status '$($asset.status)'." }
    if ($statusRank -lt $minimumRank) { $issues += "${id}: status '$($asset.status)' is below '$MinimumStatus'." }
    $history = @($asset.statusHistory)
    if ($history.Count -ne ($statusRank + 1)) { $issues += "${id}: statusHistory must contain every lifecycle step exactly once through '$($asset.status)'." }
    for ($historyIndex = 0; $historyIndex -lt $history.Count; $historyIndex++) {
      $event = $history[$historyIndex]
      $expectedStatus = if ($historyIndex -lt $statusOrder.Count) { $statusOrder[$historyIndex] } else { "<overflow>" }
      if ([string]$event.status -ne $expectedStatus) { $issues += "${id}: lifecycle step $historyIndex must be '$expectedStatus', got '$($event.status)'." }
      if ([string]::IsNullOrWhiteSpace([string]$event.at)) { $issues += "${id}: lifecycle '$($event.status)' needs a timestamp." }
      if ($historyIndex -gt 0 -and @($event.evidence).Count -eq 0) { $issues += "${id}: lifecycle '$($event.status)' needs transition evidence." }
      foreach ($relative in @($event.evidence)) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "${id} lifecycle '$($event.status)' evidence"
        if ($pathIssue) { $issues += $pathIssue }
      }
    }
    if ($DisallowPlaceholders -and [bool]$asset.placeholder) { $issues += "${id}: placeholder assets are not allowed for $RequiredFor." }
    if (@($asset.visualTargets).Count -eq 0) { $issues += "${id}: formal art asset needs at least one approved visual target." }
    foreach ($visualTargetId in @($asset.visualTargets)) {
      if (-not $approvedVisualTargets.ContainsKey([string]$visualTargetId)) { $issues += "${id}: visual target is missing or not approved: $visualTargetId" }
    }

    $pathRequirements = @{
      sourceFile = [array]::IndexOf($statusOrder, "generated")
      outputPath = [array]::IndexOf($statusOrder, "processed")
      importRecipe = [array]::IndexOf($statusOrder, "imported")
    }
    foreach ($assetPathProperty in @("sourceFile", "outputPath", "importRecipe")) {
      $relative = [string]$asset.$assetPathProperty
      if ([string]::IsNullOrWhiteSpace($relative) -or $statusRank -lt [int]$pathRequirements[$assetPathProperty]) { continue }
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
    $integrityNames = if ($asset.integrity) { @($asset.integrity.PSObject.Properties.Name) } else { @() }
    $requiredIntegrityProperties = @("sourceLayout", "extractionMode", "minimumTransparentMargin", "minimumFrameMargin", "expectedFrames", "maxSignificantComponents", "maxBaselineVariance", "maxFrameSizeVarianceRatio", "reportPath", "verdict")
    $missingIntegrityProperties = @($requiredIntegrityProperties | Where-Object { $integrityNames -notcontains $_ })
    if ($missingIntegrityProperties.Count -gt 0) {
      $issues += "${id}: integrity contract is missing properties: $($missingIntegrityProperties -join ', ')"
    }
    elseif ($statusRank -ge [array]::IndexOf($statusOrder, "processed")) {
      if ([string]$asset.integrity.sourceLayout -eq "unverified-sheet") { $issues += "${id}: unverified composite sheets cannot enter formal processing." }
      if ([string]$asset.integrity.extractionMode -eq "fixed-grid" -and [string]$asset.integrity.sourceLayout -ne "registered-sheet") {
        $issues += "${id}: fixed-grid extraction requires a registered-sheet with verified gutters and registration."
      }
      if ([string]$asset.integrity.verdict -ne "pass") { $issues += "${id}: Sprite integrity verdict must be pass before import/reference/approval." }
      if ([string]::IsNullOrWhiteSpace([string]$asset.integrity.reportPath)) { $issues += "${id}: processed art needs an integrity report path." }
      else {
        $integrityIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$asset.integrity.reportPath) -Label "${id} integrity report"
        if ($integrityIssue) { $issues += $integrityIssue }
      }
    }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "referenced") -and @($asset.references).Count -eq 0) { $issues += "${id}: referenced/approved asset needs Unity references." }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "imported") -and -not [string]::IsNullOrWhiteSpace([string]$asset.importRecipe)) {
      $recipeResult = Test-MLGSArtImportRecipe -ProjectRoot $ProjectRoot -Path ([string]$asset.importRecipe) -Asset $asset
      if (-not $recipeResult.passed) {
        foreach ($recipeIssue in @($recipeResult.issues)) { $issues += "${id}: $recipeIssue" }
      }
    }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "referenced")) {
      foreach ($referencePath in @($asset.references)) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$referencePath) -Label "${id} Unity reference"
        if ($pathIssue) { $issues += $pathIssue }
      }
    }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "approved") -and @($asset.evidence).Count -eq 0) { $issues += "${id}: approved asset needs in-game evidence." }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "approved")) {
      foreach ($evidencePath in @($asset.evidence)) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$evidencePath) -Label "${id} in-game evidence"
        if ($pathIssue) { $issues += $pathIssue }
      }
      if ([string]::IsNullOrWhiteSpace([string]$asset.reviewPath)) { $issues += "${id}: approved asset needs a fail-closed art review." }
      else {
        $reviewResult = Test-MLGSArtReview -ProjectRoot $ProjectRoot -Path ([string]$asset.reviewPath) -AssetId $id
        if (-not $reviewResult.passed) {
          foreach ($reviewIssue in @($reviewResult.issues)) { $issues += "${id}: $reviewIssue" }
        }
      }
    }
  }

  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $manifestPath; requiredFor = $RequiredFor; checkedAssets = $requiredAssets.Count; issues = @($issues) }
}

function Test-MLGSGameProfileCoverage {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [string]$ProfilePath = "design/game-profile.json",
    [string]$ScopePath = "production/scope/release-scope.json",
    [string]$UIScreenPath = "design/ui/screen-inventory.json"
  )

  $issues = @()
  $script:MLGSCoverageIssues = @()
  function Read-MLGSCoverageJson([string]$Relative, [string]$Label) {
    try { $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Relative } catch { $script:MLGSCoverageIssues += $_.Exception.Message; return $null }
    if (-not (Test-Path $full)) { $script:MLGSCoverageIssues += "Missing ${Label}: $Relative"; return $null }
    try { return Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $script:MLGSCoverageIssues += "Invalid $Label JSON: $($_.Exception.Message)"; return $null }
  }
  $profile = Read-MLGSCoverageJson $ProfilePath "game profile"
  $scope = Read-MLGSCoverageJson $ScopePath "release scope"
  $ui = Read-MLGSCoverageJson $UIScreenPath "UI screen contract"
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
  return [pscustomobject]@{ passed = $issues.Count -eq 0; profile = $profileId; issues = @($issues) }
}

function Test-MLGSUIScreenContract {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$RequiredFor,
    [Parameter(Mandatory = $true)][string]$MinimumStatus
  )

  $issues = @()
  $statusOrder = @("planned", "specified", "implemented", "integrated", "approved")
  $minimumRank = [array]::IndexOf($statusOrder, $MinimumStatus)
  $requiredStageRank = Get-MLGSStageRank -Stage $RequiredFor
  try { $contractPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $contractPath)) { return [pscustomobject]@{ passed = $false; path = $contractPath; issues = @("Missing UI screen contract: $Path") } }
  try { $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $contractPath; issues = @("Invalid UI screen contract JSON: $($_.Exception.Message)") }
  }
  foreach ($name in @("schemaVersion", "profileId", "updated", "screens")) {
    if (@($contract.PSObject.Properties.Name) -notcontains $name) { $issues += "UI screen contract property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $contractPath; issues = @($issues) } }
  if ([string]$contract.schemaVersion -ne "1.0") { $issues += "UI screen contract schemaVersion must be 1.0." }

  $profilePath = Join-Path $ProjectRoot "design/game-profile.json"
  $scopePath = Join-Path $ProjectRoot "production/scope/release-scope.json"
  if (-not (Test-Path $profilePath)) { $issues += "Missing selected game profile." } else { try { $profile = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid game profile JSON." } }
  if (-not (Test-Path $scopePath)) { $issues += "Missing release scope." } else { try { $scope = Get-Content $scopePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid release scope JSON." } }
  if ($profile -and [string]$contract.profileId -ne [string]$profile.id) { $issues += "UI screen contract profileId does not match selected profile." }

  $approvedTargets = @{}
  $visual = Test-MLGSVisualTarget -ProjectRoot $ProjectRoot -Path "design/art/visual-target.json"
  foreach ($targetId in @($visual.approvedIds)) { $approvedTargets[[string]$targetId] = $true }
  if (-not $visual.passed) { $issues += @($visual.issues) }

  $screenById = @{}
  foreach ($screen in @($contract.screens)) {
    $id = [string]$screen.id
    if ([string]::IsNullOrWhiteSpace($id)) { $issues += "UI screen id is empty."; continue }
    if ($screenById.ContainsKey($id)) { $issues += "Duplicate UI screen id: $id" } else { $screenById[$id] = $screen }
    if (@($screen.visualTargetIds).Count -eq 0) { $issues += "$($id): visualTargetIds are required." }
    foreach ($targetId in @($screen.visualTargetIds)) {
      if (-not $approvedTargets.ContainsKey([string]$targetId)) { $issues += "$($id): visual target is missing or not approved: $targetId" }
    }
  }

  $requiredScopeItems = @()
  if ($scope) {
    foreach ($item in @($scope.items | Where-Object { [string]$_.type -eq "ui-screen" })) {
      try { if ((Get-MLGSStageRank -Stage ([string]$item.requiredFor)) -le $requiredStageRank) { $requiredScopeItems += $item } } catch { $issues += $_.Exception.Message }
    }
  }
  if ($requiredScopeItems.Count -eq 0 -and $RequiredFor -eq "vertical-slice" -and $scope) {
    $requiredScopeItems = @($scope.items | Where-Object { [string]$_.type -eq "ui-screen" } | Select-Object -First 1)
  }
  if ($requiredScopeItems.Count -eq 0) { $issues += "No UI screen scope items are available for $RequiredFor." }
  foreach ($item in $requiredScopeItems) {
    $matches = @($contract.screens | Where-Object { [string]$_.scopeId -eq [string]$item.id })
    if ($matches.Count -eq 0) { $issues += "$($item.id): release-scope UI item has no screen contract."; continue }
    foreach ($screen in $matches) {
      $rank = [array]::IndexOf($statusOrder, [string]$screen.status)
      if ($rank -lt $minimumRank) { $issues += "$($screen.id): status is below $MinimumStatus." }
      if ($rank -ge [array]::IndexOf($statusOrder, "implemented")) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$screen.prefabOrDocument) -Label "$($screen.id) prefabOrDocument"
        if ($pathIssue) { $issues += $pathIssue }
      }
      if ($rank -ge [array]::IndexOf($statusOrder, "approved")) {
        if (@($screen.evidence).Count -eq 0) { $issues += "$($screen.id): approved screen needs evidence." }
        foreach ($evidence in @($screen.evidence)) {
          $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$evidence) -Label "$($screen.id) evidence"
          if ($pathIssue) { $issues += $pathIssue }
        }
      }
    }
  }
  if ($profile -and $requiredStageRank -ge (Get-MLGSStageRank -Stage "content-complete")) {
    foreach ($screenId in @($profile.requiredUiScreens)) {
      if (-not $screenById.ContainsKey([string]$screenId)) { $issues += "Profile-required UI screen is missing: $screenId" }
    }
  }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $contractPath; checkedScreens = $requiredScopeItems.Count; issues = @($issues) }
}

function Test-MLGSDesignBaseline {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$OutputPath = "production/quality/design-change-impact.json",
    [switch]$NoWrite
  )

  $issues = @()
  try { $baselinePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; changedSources = @(); issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $baselinePath)) { return [pscustomobject]@{ passed = $false; path = $baselinePath; changedSources = @(); issues = @("Missing design baseline: $Path") } }
  try { $baseline = Get-Content -LiteralPath $baselinePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $baselinePath; changedSources = @(); issues = @("Invalid design baseline JSON: $($_.Exception.Message)") }
  }
  if ([string]$baseline.schemaVersion -ne "1.0" -or [string]$baseline.status -ne "frozen") { $issues += "Design baseline must be schemaVersion 1.0 and frozen." }
  $changed = @()
  $scopeIds = @()
  $assetIds = @()
  $workIds = @()
  $stages = @()
  foreach ($source in @($baseline.sources)) {
    try { $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$source.path) } catch { $issues += $_.Exception.Message; $changed += [string]$source.path; continue }
    $current = if (Test-Path $full) { (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash } else { "" }
    if ($current -ne [string]$source.sha256) {
      $changed += [string]$source.path
      $scopeIds += @($source.affectsScopeIds)
      $assetIds += @($source.affectsAssetIds)
      $workIds += @($source.affectsWorkPackageIds)
      $stages += @($source.invalidatesStages)
    }
  }
  $impact = [ordered]@{
    '$schema' = "../../.mlgs/change-impact.schema.json"
    schemaVersion = "1.0"
    baselineVersion = [string]$baseline.version
    verdict = if ($changed.Count -eq 0 -and $issues.Count -eq 0) { "current" } elseif ($issues.Count -gt 0) { "error" } else { "stale" }
    checkedAt = (Get-Date).ToString("o")
    changedSources = @($changed | Select-Object -Unique)
    affectedScopeIds = @($scopeIds | Select-Object -Unique)
    affectedAssetIds = @($assetIds | Select-Object -Unique)
    affectedWorkPackageIds = @($workIds | Select-Object -Unique)
    invalidatedStages = @($stages | Select-Object -Unique)
  }
  if (-not $NoWrite) {
    $fullOutput = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $OutputPath
    Write-MLGSJsonAtomic -Path $fullOutput -Value $impact
  }
  if ($changed.Count -gt 0) { $issues += "Design baseline is stale: $($changed -join ', ')" }
  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $baselinePath; verdict = $impact.verdict; changedSources = @($changed); invalidatedStages = @($impact.invalidatedStages); issues = @($issues) }
}

function Test-MLGSReleaseScope {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$RequiredFor,
    [ValidateSet("planned", "specified", "implemented", "integrated", "verified")][string]$MinimumStatus = "integrated",
    [switch]$DisallowPlaceholders,
    [string[]]$RequiredTypes = @()
  )

  $issues = @()
  $statusOrder = @("planned", "specified", "implemented", "integrated", "verified")
  $minimumRank = [array]::IndexOf($statusOrder, $MinimumStatus)
  $requiredStageRank = Get-MLGSStageRank -Stage $RequiredFor
  try { $manifestPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch {
    return [pscustomobject]@{ passed = $false; path = $Path; requiredFor = $RequiredFor; checkedItems = 0; issues = @($_.Exception.Message) }
  }
  if (-not (Test-Path $manifestPath)) {
    return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedItems = 0; issues = @("Missing release scope manifest: $Path") }
  }
  try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
    return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedItems = 0; issues = @("Invalid release scope JSON: $($_.Exception.Message)") }
  }
  foreach ($name in @("schemaVersion", "profileId", "designBaselineVersion", "targetVersion", "releaseDefinition", "updated", "items")) {
    if (@($manifest.PSObject.Properties.Name) -notcontains $name) { $issues += "Release scope property is missing: $name" }
  }
  if ($issues.Count -gt 0) { return [pscustomobject]@{ passed = $false; path = $manifestPath; requiredFor = $RequiredFor; checkedItems = 0; issues = @($issues) } }
  if ([string]$manifest.schemaVersion -ne "1.1") { $issues += "Release scope schemaVersion must be 1.1." }
  if ([string]::IsNullOrWhiteSpace([string]$manifest.profileId)) { $issues += "Release scope profileId is required." }
  if ([string]::IsNullOrWhiteSpace([string]$manifest.designBaselineVersion)) { $issues += "Release scope designBaselineVersion is required." }
  if ([string]::IsNullOrWhiteSpace([string]$manifest.updated)) { $issues += "Release scope updated timestamp is required." }
  if ([string]::IsNullOrWhiteSpace([string]$manifest.releaseDefinition)) { $issues += "Release scope releaseDefinition is required." }
  $versionMatch = [regex]::Match([string]$manifest.targetVersion, '^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$')
  if (-not $versionMatch.Success) { $issues += "Release scope targetVersion must be strict semver." }
  elseif (@("release-candidate", "release") -contains $RequiredFor -and [int]$versionMatch.Groups[1].Value -lt 1) {
    $issues += "Release Candidate and Release require targetVersion 1.0.0 or later; 0.x is prototype/pre-release only."
  }

  $artIds = @{}
  $artManifestPath = Join-Path $ProjectRoot "production/assets/asset-manifest.json"
  if (Test-Path $artManifestPath) {
    try {
      $artManifest = Get-Content -LiteralPath $artManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
      foreach ($asset in @($artManifest.assets)) { $artIds[[string]$asset.id] = $true }
    } catch { $issues += "Cannot cross-check art asset IDs: $($_.Exception.Message)" }
  }

  $ids = @{}
  $requiredItems = @()
  foreach ($item in @($manifest.items)) {
    $names = @($item.PSObject.Properties.Name)
    $requiredProperties = @("id", "type", "description", "source", "requiredFor", "status", "placeholder", "plannedCount", "implementedCount", "verifiedCount", "implementation", "evidence", "artAssetIds", "profileRequirementIds")
    $missing = @($requiredProperties | Where-Object { $names -notcontains $_ })
    if ($missing.Count -gt 0) { $issues += "Release scope item is missing properties: $($missing -join ', ')"; continue }
    $id = [string]$item.id
    if ([string]::IsNullOrWhiteSpace($id)) { $issues += "Release scope item id is empty."; continue }
    if ($ids.ContainsKey($id)) { $issues += "Duplicate release scope item id: $id" } else { $ids[$id] = $true }
    try { $itemStageRank = Get-MLGSStageRank -Stage ([string]$item.requiredFor) } catch { $issues += "${id}: $($_.Exception.Message)"; continue }
    if ($itemStageRank -le $requiredStageRank) { $requiredItems += $item }
  }
  if ($requiredItems.Count -eq 0) { $issues += "No release-scope items are assigned to $RequiredFor or an earlier stage." }
  foreach ($type in @($RequiredTypes)) {
    if (@($requiredItems | Where-Object { [string]$_.type -eq $type }).Count -eq 0) { $issues += "Required release-scope type is missing: $type" }
  }

  foreach ($item in $requiredItems) {
    $id = [string]$item.id
    $statusRank = [array]::IndexOf($statusOrder, [string]$item.status)
    if ($statusRank -lt $minimumRank) { $issues += "${id}: status '$($item.status)' is below '$MinimumStatus'." }
    if ($DisallowPlaceholders -and [bool]$item.placeholder) { $issues += "${id}: placeholder scope items are not allowed for $RequiredFor." }
    if ([int]$item.plannedCount -lt 1) { $issues += "${id}: plannedCount must be at least 1." }
    $sourceIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$item.source) -Label "${id} source"
    if ($sourceIssue) { $issues += $sourceIssue }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "implemented")) {
      if (@($item.implementation).Count -eq 0) { $issues += "${id}: implemented/integrated item needs implementation paths." }
      foreach ($implementationPath in @($item.implementation)) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$implementationPath) -Label "${id} implementation"
        if ($pathIssue) { $issues += $pathIssue }
      }
    }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "integrated") -and [int]$item.implementedCount -lt [int]$item.plannedCount) {
      $issues += "${id}: implementedCount is below plannedCount."
    }
    if ($statusRank -ge [array]::IndexOf($statusOrder, "verified")) {
      if ([int]$item.verifiedCount -lt [int]$item.plannedCount) { $issues += "${id}: verifiedCount is below plannedCount." }
      if (@($item.evidence).Count -eq 0) { $issues += "${id}: verified item needs evidence paths." }
      foreach ($evidencePath in @($item.evidence)) {
        $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$evidencePath) -Label "${id} evidence"
        if ($pathIssue) { $issues += $pathIssue }
      }
    }
    if ([string]$item.type -eq "art") {
      if (@($item.artAssetIds).Count -eq 0) { $issues += "${id}: art scope item needs artAssetIds." }
      if (@($item.artAssetIds).Count -lt [int]$item.plannedCount) { $issues += "${id}: artAssetIds count is below plannedCount." }
      foreach ($artId in @($item.artAssetIds)) {
        if (-not $artIds.ContainsKey([string]$artId)) { $issues += "${id}: art asset ID is missing from the art manifest: $artId" }
      }
    }
  }

  return [pscustomobject]@{ passed = $issues.Count -eq 0; path = $manifestPath; requiredFor = $RequiredFor; targetVersion = [string]$manifest.targetVersion; checkedItems = $requiredItems.Count; issues = @($issues) }
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

    $scopePass = $true
    $scopeIssues = @()
    if ($gate.PSObject.Properties.Name -contains "scopeManifest") {
      $scope = $gate.scopeManifest
      $requiredTypes = @()
      if ($scope.PSObject.Properties.Name -contains "requiredTypes") { $requiredTypes = @($scope.requiredTypes) }
      $scopeArgs = @{
        ProjectRoot = $ProjectRoot
        Path = [string]$scope.path
        RequiredFor = [string]$scope.requiredFor
        MinimumStatus = [string]$scope.minimumStatus
        RequiredTypes = $requiredTypes
      }
      if (($scope.PSObject.Properties.Name -contains "disallowPlaceholders") -and [bool]$scope.disallowPlaceholders) { $scopeArgs.DisallowPlaceholders = $true }
      $scopeResult = Test-MLGSReleaseScope @scopeArgs
      $scopePass = [bool]$scopeResult.passed
      $scopeIssues = @($scopeResult.issues)
    }

    $capabilityPass = $true
    $capabilityIssues = @()
    if ($gate.PSObject.Properties.Name -contains "capabilityManifest") {
      $capabilityDefinition = $gate.capabilityManifest
      $requiredCapabilityKinds = @()
      if ($capabilityDefinition.PSObject.Properties.Name -contains "requiredCapabilityKinds") { $requiredCapabilityKinds = @($capabilityDefinition.requiredCapabilityKinds) }
      $capabilityResult = Test-MLGSProductionCapabilities -ProjectRoot $ProjectRoot -Path ([string]$capabilityDefinition.path) -RequiredFor ([string]$capabilityDefinition.requiredFor) -RequiredCapabilityKinds $requiredCapabilityKinds
      $capabilityPass = [bool]$capabilityResult.passed
      $capabilityIssues = @($capabilityResult.issues)
    }

    $profilePass = $true
    $profileIssues = @()
    if ($gate.PSObject.Properties.Name -contains "gameProfileCoverage") {
      $profileResult = Test-MLGSGameProfileCoverage -ProjectRoot $ProjectRoot
      $profilePass = [bool]$profileResult.passed
      $profileIssues = @($profileResult.issues)
    }

    $uiPass = $true
    $uiIssues = @()
    if ($gate.PSObject.Properties.Name -contains "uiScreenContract") {
      $uiDefinition = $gate.uiScreenContract
      $uiResult = Test-MLGSUIScreenContract -ProjectRoot $ProjectRoot -Path ([string]$uiDefinition.path) -RequiredFor ([string]$uiDefinition.requiredFor) -MinimumStatus ([string]$uiDefinition.minimumStatus)
      $uiPass = [bool]$uiResult.passed
      $uiIssues = @($uiResult.issues)
    }

    $baselinePass = $true
    $baselineIssues = @()
    if ($gate.PSObject.Properties.Name -contains "designBaseline") {
      $baselineResult = Test-MLGSDesignBaseline -ProjectRoot $ProjectRoot -Path ([string]$gate.designBaseline.path) -NoWrite
      $baselinePass = [bool]$baselineResult.passed
      $baselineIssues = @($baselineResult.issues)
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

    $visualScenePass = $true
    $visualSceneIssues = @()
    if ($gate.PSObject.Properties.Name -contains "visualSceneContract") {
      $definition = $gate.visualSceneContract
      $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) "tools/test-visual-scene-contract.ps1") -Root (Split-Path -Parent $PSScriptRoot) -ProjectRoot $ProjectRoot -Path ([string]$definition.path) -RequiredFor ([string]$definition.requiredFor) -MinimumStatus ([string]$definition.minimumStatus) 2>$null
      try { $visualSceneResult = $raw | ConvertFrom-Json; $visualScenePass = [bool]$visualSceneResult.passed; $visualSceneIssues = @($visualSceneResult.issues) } catch { $visualScenePass = $false; $visualSceneIssues = @("Visual scene contract validator did not return parseable output.") }
    }

    $frameworkPass = $true
    $frameworkIssues = @()
    if ($gate.PSObject.Properties.Name -contains "frameworkAdoption") {
      $definition = $gate.frameworkAdoption
      $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) "tools/test-framework-adoption.ps1") -Root (Split-Path -Parent $PSScriptRoot) -ProjectRoot $ProjectRoot -Path ([string]$definition.path) 2>$null
      try { $frameworkResult = $raw | ConvertFrom-Json; $frameworkPass = [bool]$frameworkResult.passed; $frameworkIssues = @($frameworkResult.issues) } catch { $frameworkPass = $false; $frameworkIssues = @("Framework adoption validator did not return parseable output.") }
    }

    $presentationPass = $true
    $presentationIssues = @()
    if ($gate.PSObject.Properties.Name -contains "presentationArchitecture") {
      $definition = $gate.presentationArchitecture
      $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path (Split-Path -Parent $PSScriptRoot) "tools/test-presentation-architecture.ps1"), "-Root", (Split-Path -Parent $PSScriptRoot), "-ProjectRoot", $ProjectRoot, "-Path", [string]$definition.path)
      if (($definition.PSObject.Properties.Name -contains "contractOnly") -and [bool]$definition.contractOnly) { $args += "-ContractOnly" }
      $raw = & powershell @args 2>$null
      try { $presentationResult = $raw | ConvertFrom-Json; $presentationPass = [bool]$presentationResult.passed; $presentationIssues = @($presentationResult.issues) } catch { $presentationPass = $false; $presentationIssues = @("Presentation architecture validator did not return parseable output.") }
    }

    $codebasePass = $true
    $codebaseIssues = @()
    if ($gate.PSObject.Properties.Name -contains "codebaseUnderstanding") {
      $definition = $gate.codebaseUnderstanding
      $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path -Parent $PSScriptRoot) "tools/test-codebase-understanding.ps1") -Root (Split-Path -Parent $PSScriptRoot) -ProjectRoot $ProjectRoot -ProfilePath ([string]$definition.profilePath) -ModuleMapPath ([string]$definition.moduleMapPath) 2>$null
      try { $codebaseResult = $raw | ConvertFrom-Json; $codebasePass = [bool]$codebaseResult.passed; $codebaseIssues = @($codebaseResult.issues) } catch { $codebasePass = $false; $codebaseIssues = @("Codebase understanding validator did not return parseable output.") }
    }

    $gateResults[$gateProperty.Name] = [pscustomobject]@{
      passed = (($artifactPass -and $approvalPass -and $qualityPass -and $artPass -and $scopePass -and $capabilityPass -and $profilePass -and $uiPass -and $baselinePass -and $codeAuditPass -and $visualScenePass -and $frameworkPass -and $presentationPass -and $codebasePass) -or ($skipped -and $approvalPass -and $qualityPass -and $artPass -and $scopePass -and $capabilityPass -and $profilePass -and $uiPass -and $baselinePass -and $codeAuditPass -and $visualScenePass -and $frameworkPass -and $presentationPass -and $codebasePass))
      artifactsPassed = $artifactPass
      approvalPassed = $approvalPass
      qualityPassed = $qualityPass
      artPassed = $artPass
      scopePassed = $scopePass
      profileCoveragePassed = $profilePass
      capabilityManifestPassed = $capabilityPass
      uiScreenContractPassed = $uiPass
      designBaselinePassed = $baselinePass
      codeAuditPassed = $codeAuditPass
      visualSceneContractPassed = $visualScenePass
      frameworkAdoptionPassed = $frameworkPass
      presentationArchitecturePassed = $presentationPass
      codebaseUnderstandingPassed = $codebasePass
      skippedWithRisk = $skipped
      missing = @($missing)
      qualityIssues = @($qualityIssues)
      artIssues = @($artIssues)
      scopeIssues = @($scopeIssues)
      profileCoverageIssues = @($profileIssues)
      capabilityManifestIssues = @($capabilityIssues)
      uiScreenContractIssues = @($uiIssues)
      designBaselineIssues = @($baselineIssues)
      codeAuditIssues = @($codeAuditIssues)
      visualSceneContractIssues = @($visualSceneIssues)
      frameworkAdoptionIssues = @($frameworkIssues)
      presentationArchitectureIssues = @($presentationIssues)
      codebaseUnderstandingIssues = @($codebaseIssues)
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
