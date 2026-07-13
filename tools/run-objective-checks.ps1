param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Path,
  [switch]$AllowCommands
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$documentPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path
if (-not (Test-Path $documentPath)) { throw "Objective-check document does not exist: $Path" }
$document = Get-Content -LiteralPath $documentPath -Raw -Encoding UTF8 | ConvertFrom-Json

$containers = @()
if ($document.PSObject.Properties.Name -contains "successCriteria") { $containers += @($document.successCriteria) }
if ($document.PSObject.Properties.Name -contains "checks") { $containers += @($document.checks) }
if ($containers.Count -eq 0) { throw "Document has no successCriteria or checks collection." }

foreach ($container in $containers) {
  if ($container.PSObject.Properties.Name -notcontains "objectiveChecks") { throw "Objective-check collection is missing on '$($container.id)'." }
  foreach ($check in @($container.objectiveChecks)) {
    $passed = $false
    $detail = ""
    try {
      switch ([string]$check.kind) {
        "file-exists" {
          $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$check.path)
          $passed = Test-Path $full
          $detail = if ($passed) { "File exists: $($check.path)" } else { "File is missing: $($check.path)" }
        }
        "file-contains" {
          $full = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$check.path)
          if (-not (Test-Path $full)) { $detail = "File is missing: $($check.path)" }
          elseif ([string]::IsNullOrWhiteSpace([string]$check.contains)) { $detail = "contains value is empty." }
          else {
            $passed = (Get-Content -LiteralPath $full -Raw -Encoding UTF8).Contains([string]$check.contains)
            $detail = if ($passed) { "Required text was found." } else { "Required text was not found." }
          }
        }
        "command" {
          if (-not $AllowCommands) {
            $check.status = "skipped"
            $check.detail = "Command checks require explicit -AllowCommands."
            continue
          }
          if ([string]::IsNullOrWhiteSpace([string]$check.command)) { $detail = "command is empty." }
          else {
            Push-Location $ProjectRoot
            try {
              $output = & powershell -NoProfile -ExecutionPolicy Bypass -Command ([string]$check.command) 2>&1
              $passed = $LASTEXITCODE -eq 0
              $detail = (($output | Select-Object -Last 8) -join [Environment]::NewLine)
              if ([string]::IsNullOrWhiteSpace($detail)) { $detail = "Command exit code: $LASTEXITCODE" }
            } finally { Pop-Location }
          }
        }
        default { $detail = "Unsupported objective check kind: $($check.kind)" }
      }
    } catch { $detail = $_.Exception.Message }
    $check.status = if ($passed) { "pass" } else { "fail" }
    $check.detail = $detail
  }
  $statuses = @($container.objectiveChecks | ForEach-Object { [string]$_.status })
  $container.objectiveVerdict = if ($statuses.Count -gt 0 -and @($statuses | Where-Object { $_ -ne "pass" }).Count -eq 0) { "pass" } elseif (@($statuses | Where-Object { $_ -eq "fail" }).Count -gt 0) { "fail" } else { "unknown" }
}

$verdicts = @($containers | ForEach-Object { [string]$_.objectiveVerdict })
$document.objectiveVerdict = if ($verdicts.Count -gt 0 -and @($verdicts | Where-Object { $_ -ne "pass" }).Count -eq 0) { "pass" } elseif (@($verdicts | Where-Object { $_ -eq "fail" }).Count -gt 0) { "fail" } else { "unknown" }
if ($document.PSObject.Properties.Name -contains "verdict") {
  if ([string]$document.declaredVerdict -eq "pass" -and [string]$document.objectiveVerdict -eq "pass") { $document.verdict = "pass" }
  elseif ([string]$document.declaredVerdict -eq "blocked") { $document.verdict = "blocked" }
  else { $document.verdict = "fail" }
}
$document.updated = (Get-Date).ToString("o")
Write-MLGSJsonAtomic -Path $documentPath -Value $document
[pscustomobject]@{ path = $documentPath; objective_verdict = $document.objectiveVerdict; commands_allowed = [bool]$AllowCommands } | ConvertTo-Json -Depth 8
if ([string]$document.objectiveVerdict -ne "pass") { exit 8 }
