param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$statePath = Join-Path $Root "studio/state.yaml"
if (-not (Test-Path $statePath)) {
  Write-Error "Missing studio/state.yaml"
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

$content = Get-Content -Path $statePath -Raw -Encoding UTF8
if ($content -notmatch "active_project:" -or $content -notmatch "phase:" -or $content -notmatch "next_action:") {
  Write-Error "studio/state.yaml is missing required sections."
  exit 1
}

Write-Output "State check passed: studio/state.yaml is the only root state source."

