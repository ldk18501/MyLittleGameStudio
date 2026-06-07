param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$templatePath = Join-Path $Root "studio/state.yaml"
$pointerPath = Join-Path $Root "studio/current-project.local.yaml"
$resolverPath = Join-Path $Root "tools/resolve-state.ps1"

if (-not (Test-Path $templatePath)) {
  Write-Error "Missing studio/state.yaml template"
  exit 1
}

$forbidden = @(
  "studio/session.md",
  "studio/stage.md",
  "studio/project-index.md"
)

$found = @()
foreach ($relative in $forbidden) {
  $path = Join-Path $Root $relative
  if (Test-Path $path) {
    $found += $relative
  }
}

if ($found.Count -gt 0) {
  Write-Error ("Conflicting root state files found: " + ($found -join ", "))
  exit 1
}

$template = Get-Content -Path $templatePath -Raw -Encoding UTF8
if ($template -notmatch "kind:\s*template" -or $template -notmatch "active_project:" -or $template -notmatch "phase:" -or $template -notmatch "next_action:") {
  Write-Error "studio/state.yaml template is missing required sections."
  exit 1
}

if (-not (Test-Path $resolverPath)) {
  Write-Error "Missing tools/resolve-state.ps1"
  exit 1
}

$resolved = & powershell -ExecutionPolicy Bypass -File $resolverPath -Root $Root -AllowTemplate | ConvertFrom-Json
if (-not $resolved.exists) {
  Write-Error "Could not resolve a template or project state."
  exit 1
}

if ((Test-Path $pointerPath) -and $resolved.mode -eq "local-pointer") {
  $state = Get-Content -Path $resolved.state_path -Raw -Encoding UTF8
  if ($state -notmatch "active_project:" -or $state -notmatch "phase:" -or $state -notmatch "next_action:") {
    Write-Error "Resolved project state is missing required sections: $($resolved.state_path)"
    exit 1
  }
}

Write-Output "State check passed: root state is a template; project state resolves via rules/state.md."
