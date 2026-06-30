param(
  [string]$Root = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) {
  $scriptPath = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
  }
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $Root = (Get-Location).Path
  } else {
    $Root = Split-Path -Parent (Split-Path -Parent $scriptPath)
  }
}

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Body
  )

  try {
    & $Body | Out-Null
    [pscustomobject]@{
      name = $Name
      status = "pass"
      detail = ""
    }
  } catch {
    [pscustomobject]@{
      name = $Name
      status = "fail"
      detail = $_.Exception.Message
    }
  }
}

$results = @()

$results += Invoke-Step "check-state" {
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/check-state.ps1") -Root $Root
  if (($output -join "`n") -notmatch "passed|warning") {
    throw "Unexpected check-state output: $output"
  }
}

$tempProject = Join-Path ([System.IO.Path]::GetTempPath()) ("mlgs-smoke-" + [guid]::NewGuid().ToString("N").Substring(0, 8))

$results += Invoke-Step "detect-unity-project" {
  New-Item -ItemType Directory -Path (Join-Path $tempProject "Assets") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $tempProject "ProjectSettings") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $tempProject "Packages") -Force | Out-Null
  Set-Content -Path (Join-Path $tempProject "ProjectSettings/ProjectVersion.txt") -Value "m_EditorVersion: 6000.0.0f1" -Encoding UTF8
  Set-Content -Path (Join-Path $tempProject "Packages/manifest.json") -Value "{}" -Encoding UTF8

  $detected = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/detect-project-stage.ps1") -Root $Root -ProjectRoot $tempProject | ConvertFrom-Json
  if (-not $detected.is_unity_project -or $detected.recommended_command -ne "adopt") {
    throw "Unity adoption detection failed."
  }
}

$results += Invoke-Step "init-project-state" {
  $init = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/init-project-state.ps1") -Root $Root -ProjectRoot $tempProject -Name "MLGS Smoke Test" -Mode external-adopted -UnityVersion "6000.0.0f1" -ApprovedWritePaths "Assets" -OwnerParticipation low -SkipPointer | ConvertFrom-Json
  if (-not (Test-Path $init.state_path)) {
    throw "State file was not created."
  }
  $state = Get-Content -Raw -Encoding UTF8 -LiteralPath $init.state_path
  if ($state -notmatch "owner_participation:" -or $state -notmatch "current:\s*intake") {
    throw "Initialized state is missing v0.2 fields."
  }
}

$results += Invoke-Step "resolve-explicit-project" {
  $resolved = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -ProjectRoot $tempProject | ConvertFrom-Json
  if (-not $resolved.exists) {
    throw "Explicit project state did not resolve."
  }
}

$adoptProject = Join-Path ([System.IO.Path]::GetTempPath()) ("mlgs-adopt-" + [guid]::NewGuid().ToString("N").Substring(0, 8))

$results += Invoke-Step "adopt-report" {
  New-Item -ItemType Directory -Path (Join-Path $adoptProject "Assets/Scripts") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $adoptProject "ProjectSettings") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $adoptProject "Packages") -Force | Out-Null
  Set-Content -Path (Join-Path $adoptProject "ProjectSettings/ProjectVersion.txt") -Value "m_EditorVersion: 6000.0.0f1" -Encoding UTF8
  Set-Content -Path (Join-Path $adoptProject "Packages/manifest.json") -Value "{}" -Encoding UTF8
  Set-Content -Path (Join-Path $adoptProject "Assets/Scripts/PlayerController.cs") -Value "public sealed class PlayerController { }" -Encoding UTF8

  $report = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/adopt-project.ps1") -Root $Root -ProjectRoot $adoptProject -Name "Adopt Smoke" -OwnerParticipation high | ConvertFrom-Json
  if ($report.recommendation -ne "adopt-unity" -or -not $report.detection.is_unity_project) {
    throw "Adoption report did not recognize Unity project."
  }
}

$results += Invoke-Step "adopt-apply-status" {
  $apply = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/adopt-project.ps1") -Root $Root -ProjectRoot $adoptProject -Name "Adopt Smoke" -OwnerParticipation high -Apply | ConvertFrom-Json
  if (-not (Test-Path $apply.apply_result.state_path)) {
    throw "Adoption apply did not create state."
  }

  $status = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/get-project-status.ps1") -Root $Root -ProjectRoot $adoptProject | ConvertFrom-Json
  if ($status.active_project.owner_participation -ne "high" -or $status.active_project.phase -ne "intake") {
    throw "Status report did not include expected project snapshot."
  }
  if ($status.next_options.Count -lt 1) {
    throw "Status report did not include next options."
  }

  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/repair-pointer.ps1") -Root $Root -Clear | Out-Null
}

$results += Invoke-Step "trace-dashboard" {
  $traceOutput = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/trace.ps1") -Root $Root -Command "test" -Title "MLGS smoke test trace" -Status completed -LeadAgent "qa-lead" -AgentsUsed "qa-lead","producer" -Verification "Smoke trace write" -Summary "Smoke test trace event."
  if (($traceOutput -join "`n") -notmatch "Trace recorded") {
    throw "Trace did not report success."
  }
  if (-not (Test-Path (Join-Path $Root "dashboard/studio-data.js"))) {
    throw "Dashboard data was not exported."
  }
}

[pscustomobject]@{
  status = $(if (($results | Where-Object { $_.status -eq "fail" }).Count -eq 0) { "pass" } else { "fail" })
  temp_project = $tempProject
  adopt_project = $adoptProject
  results = $results
} | ConvertTo-Json -Depth 8
