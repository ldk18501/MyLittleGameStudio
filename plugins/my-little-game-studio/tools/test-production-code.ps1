param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string[]]$SourcePaths = @("Assets"),
  [string]$OutputPath = "production/quality/code-audit.json",
  [ValidatePattern("^$|^[a-z0-9][a-z0-9-]*$")][string]$TaskId = "",
  [string[]]$ChangedPaths = @(),
  [switch]$FailOnWarnings,
  [switch]$NoWrite
)

$forwardedArrayValues = @($args | ForEach-Object { [string]$_ })
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if ($forwardedArrayValues.Count -gt 0) {
  if ($TaskId -and @($ChangedPaths).Count -gt 0) {
    $ChangedPaths = @($ChangedPaths) + $forwardedArrayValues
  } elseif (@($SourcePaths).Count -gt 0) {
    $SourcePaths = @($SourcePaths) + $forwardedArrayValues
  } else {
    throw "Production code audit received unexpected positional arguments: $($forwardedArrayValues -join ', ')"
  }
}
$SourcePaths = @(@(
  foreach ($value in @($SourcePaths)) {
    foreach ($part in ([string]$value -split ",")) {
      if (-not [string]::IsNullOrWhiteSpace($part)) { $part.Trim() }
    }
  }
) | Select-Object -Unique)
$ChangedPaths = @(@(
  foreach ($value in @($ChangedPaths)) {
    foreach ($part in ([string]$value -split ",")) {
      if (-not [string]::IsNullOrWhiteSpace($part)) { $part.Trim() }
    }
  }
) | Select-Object -Unique)

$rules = @(
  [pscustomobject]@{ id = "not-implemented"; severity = "error"; pattern = "\bNotImplementedException\b"; message = "Release-scope code contains NotImplementedException." },
  [pscustomobject]@{ id = "scene-search"; severity = "error"; pattern = "\b(GameObject\s*\.\s*Find|FindObjectOfType|FindAnyObjectByType)\s*(<|\()"; message = "Hidden scene search is prohibited in production paths." },
  [pscustomobject]@{ id = "send-message"; severity = "error"; pattern = "\bSendMessage\s*\("; message = "SendMessage is prohibited in production paths." },
  [pscustomobject]@{ id = "empty-catch"; severity = "error"; pattern = "catch\s*(\([^)]*\))?\s*\{\s*\}"; message = "Empty catch block swallows production errors." },
  [pscustomobject]@{ id = "temporary-marker"; severity = "warning"; pattern = "\b(TODO|FIXME|HACK|TEMP)\b"; message = "Temporary marker must be removed or tracked before its milestone." },
  [pscustomobject]@{ id = "demo-marker"; severity = "warning"; pattern = "\b(Demo|Prototype|Sample)\b"; message = "Demo/prototype marker in production scope needs review." },
  [pscustomobject]@{ id = "async-void"; severity = "warning"; pattern = "\basync\s+void\b"; message = "async void requires an event-entry justification and contained exception handling." },
  [pscustomobject]@{ id = "resources-load"; severity = "warning"; pattern = "\bResources\s*\.\s*Load"; message = "Runtime string-path loading needs an explicit architecture decision." },
  [pscustomobject]@{ id = "runtime-gameobject-construction"; severity = "warning"; pattern = "\bnew\s+GameObject\s*\("; message = "Runtime GameObject construction must be owned by the approved factory, pool, or composition root." },
  [pscustomobject]@{ id = "runtime-add-component"; severity = "warning"; pattern = "\.AddComponent\s*<"; message = "Runtime AddComponent must be justified by the approved composition/factory architecture." },
  [pscustomobject]@{ id = "ui-owns-gameplay"; severity = "error"; pattern = "(?s)(UnityEngine\.UI|\bButton\b|\bImage\b).{0,800}\b(ApplyDamage|ResolveTurn|CalculateReward|SpawnEnemy|AdvanceWave|SetGameState)\s*\("; message = "A UI script appears to own authoritative gameplay rules; UI may issue commands and render state only." }
)

$files = @()
foreach ($relative in $SourcePaths) {
  $source = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $relative
  if (Test-Path $source) { $files += @(Get-ChildItem -LiteralPath $source -Recurse -File -Filter "*.cs" -ErrorAction SilentlyContinue) }
}
$files = @($files | Sort-Object FullName -Unique)
$findings = @()
foreach ($file in $files) {
  $relativePath = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/').Replace("\", "/")
  if ($relativePath -notmatch "(?i)(^|/)(Tests?|Editor/Tests?)(/|$)" -and $file.BaseName -match "(?i)(Demo|Prototype|Sample|Mock|Temp|Test)") {
    $findings += [pscustomobject]@{ severity = "error"; rule = "production-test-artifact"; path = $relativePath; line = 1; message = "Demo/test/prototype-named runtime script is not allowed in production paths." }
  }
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  foreach ($rule in $rules) {
    foreach ($match in [regex]::Matches($content, $rule.pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
      $line = ($content.Substring(0, $match.Index) -split "`n").Count
      $findings += [pscustomobject]@{ severity = $rule.severity; rule = $rule.id; path = $relativePath; line = $line; message = $rule.message }
    }
  }
}
$frameworkRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-framework-adoption.ps1") -Root $Root -ProjectRoot $ProjectRoot 2>$null
try { $frameworkResult = $frameworkRaw | ConvertFrom-Json } catch { $frameworkResult = [pscustomobject]@{ passed = $false; issues = @("Framework adoption validator returned invalid output.") } }
$presentationRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-presentation-architecture.ps1") -Root $Root -ProjectRoot $ProjectRoot 2>$null
try { $presentationResult = $presentationRaw | ConvertFrom-Json } catch { $presentationResult = [pscustomobject]@{ passed = $false; issues = @("Presentation architecture validator returned invalid output.") } }
foreach ($issue in @($frameworkResult.issues)) { $findings += [pscustomobject]@{ severity = "error"; rule = "framework-adoption"; path = "design/framework-adoption.json"; line = 1; message = [string]$issue } }
foreach ($issue in @($presentationResult.issues)) { $findings += [pscustomobject]@{ severity = "error"; rule = "presentation-architecture"; path = "design/presentation-architecture.json"; line = 1; message = [string]$issue } }
$codebaseRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-codebase-understanding.ps1") -Root $Root -ProjectRoot $ProjectRoot 2>$null
try { $codebaseResult = $codebaseRaw | ConvertFrom-Json } catch { $codebaseResult = [pscustomobject]@{ passed = $false; issues = @("Codebase understanding validator returned invalid output.") } }
foreach ($issue in @($codebaseResult.issues)) { $findings += [pscustomobject]@{ severity = "error"; rule = "codebase-understanding"; path = "design/code/codebase-profile.json"; line = 1; message = [string]$issue } }
$workPackageRoot = Join-Path $ProjectRoot "production/work-packages"
if (Test-Path $workPackageRoot) {
  foreach ($packageFile in @(Get-ChildItem -LiteralPath $workPackageRoot -File -Filter "*.json" -ErrorAction SilentlyContinue)) {
    try { $codePackage = Get-Content $packageFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
    if ([string]$codePackage.workKind -ne "code" -or [string]$codePackage.status -ne "done") { continue }
    if ([string]::IsNullOrWhiteSpace([string]$codePackage.conformanceReportPath)) { $findings += [pscustomobject]@{ severity = "error"; rule = "missing-code-conformance"; path = $packageFile.FullName.Substring($ProjectRoot.Length).TrimStart('\','/').Replace("\","/"); line = 1; message = "Done code work package has no conformance report." }; continue }
    $conformancePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$codePackage.conformanceReportPath)
    if (-not (Test-Path $conformancePath)) { $findings += [pscustomobject]@{ severity = "error"; rule = "missing-code-conformance"; path = [string]$codePackage.conformanceReportPath; line = 1; message = "Done code work package conformance report is missing." } }
    else {
      try {
        $doneConformance = Get-Content $conformancePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([string]$doneConformance.verdict -ne "pass") {
          $findings += [pscustomobject]@{ severity = "error"; rule = "failed-code-conformance"; path = [string]$codePackage.conformanceReportPath; line = 1; message = "Done code work package conformance did not pass." }
        }
      } catch {
        $findings += [pscustomobject]@{ severity = "error"; rule = "invalid-code-conformance"; path = [string]$codePackage.conformanceReportPath; line = 1; message = "Done code work package conformance report is invalid." }
      }
    }
  }
}
$conformanceResult = [pscustomobject]@{ passed = $true; verdict = "not-run"; findings = @() }
if ($TaskId) {
  if (@($ChangedPaths).Count -eq 0) { $findings += [pscustomobject]@{ severity = "error"; rule = "missing-changed-paths"; path = "production/context-packs/$TaskId.json"; line = 1; message = "Task-scoped production audit requires ChangedPaths." } }
  else {
    $conformanceRaw = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/test-code-conformance.ps1") -Root $Root -ProjectRoot $ProjectRoot -TaskId $TaskId -ChangedPaths $ChangedPaths 2>$null
    try { $conformanceResult = $conformanceRaw | ConvertFrom-Json } catch { $conformanceResult = [pscustomobject]@{ verdict = "fail"; findings = @([pscustomobject]@{ severity = "error"; rule = "conformance-output"; path = ""; message = "Code conformance validator returned invalid output." }) } }
    foreach ($finding in @($conformanceResult.findings | Where-Object severity -eq "error")) { $findings += [pscustomobject]@{ severity = "error"; rule = "conformance/$($finding.rule)"; path = [string]$finding.path; line = 1; message = [string]$finding.message } }
  }
}

$errors = @($findings | Where-Object { $_.severity -eq "error" })
$warnings = @($findings | Where-Object { $_.severity -eq "warning" })
$verdict = if ($errors.Count -gt 0) { "fail" } elseif ($warnings.Count -gt 0) { "pass-with-warnings" } else { "pass" }
$report = [ordered]@{
  schemaVersion = "1.0"
  generated = (Get-Date).ToString("o")
  verdict = $verdict
  scannedFiles = $files.Count
  errorCount = $errors.Count
  warningCount = $warnings.Count
  findings = @($findings)
  frameworkAdoptionPassed = [bool]$frameworkResult.passed
  presentationArchitecturePassed = [bool]$presentationResult.passed
  codebaseUnderstandingPassed = [bool]$codebaseResult.passed
  taskId = $TaskId
  conformanceVerdict = [string]$conformanceResult.verdict
  note = "Heuristic audit plus adaptive codebase understanding, framework/presentation contracts, and optional task-scoped conformance review."
}
if (-not $NoWrite) {
  $target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $OutputPath
  Write-MLGSJsonAtomic -Path $target -Value $report
}
$report | ConvertTo-Json -Depth 10
if ($errors.Count -gt 0 -or ($FailOnWarnings -and $warnings.Count -gt 0)) { exit 6 }
