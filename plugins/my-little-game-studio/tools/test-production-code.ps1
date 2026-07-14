param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string[]]$SourcePaths = @("Assets"),
  [string]$OutputPath = "production/quality/code-audit.json",
  [switch]$FailOnWarnings,
  [switch]$NoWrite
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

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
  note = "Heuristic audit plus mandatory framework-adoption and presentation-architecture contracts; pair with module integration review."
}
if (-not $NoWrite) {
  $target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $OutputPath
  Write-MLGSJsonAtomic -Path $target -Value $report
}
$report | ConvertTo-Json -Depth 10
if ($errors.Count -gt 0 -or ($FailOnWarnings -and $warnings.Count -gt 0)) { exit 6 }
