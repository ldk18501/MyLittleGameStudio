param([string]$Root = "", [switch]$Check)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $Root "plugins/my-little-game-studio"))
if (-not $pluginRoot.StartsWith($Root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Plugin root escaped the repository." }

$generateArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/generate-workflow.ps1"), "-Root", $Root)
if ($Check) { $generateArgs += "-Check" }
& powershell @generateArgs | Out-Null

$mirrorDirs = @("agents", "commands", "workflow", "rules", "templates", "tools", "profiles")
$files = @([pscustomobject]@{ source = Join-Path $Root "AGENTS.md"; relative = "AGENTS.md" })
foreach ($dir in $mirrorDirs) {
  foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Root $dir) -Recurse -File) {
    $relativeWithin = $file.FullName.Substring((Join-Path $Root $dir).Length).TrimStart('\', '/')
    $files += [pscustomobject]@{ source = $file.FullName; relative = ($dir + "/" + $relativeWithin.Replace("\", "/")) }
  }
}
foreach ($relative in @("dashboard/index.html", "studio/config.md", "studio/state.json", "studio/state.schema.json", "studio/art-asset-manifest.schema.json", "studio/art-review.schema.json", "studio/visual-target.schema.json", "studio/release-scope.schema.json", "studio/work-package.schema.json", "studio/game-profile.schema.json", "studio/ui-screen-contract.schema.json", "studio/design-baseline.schema.json", "studio/change-impact.schema.json", "studio/capability-manifest.schema.json", "studio/execution-strategy.schema.json", "studio/quality-gate.schema.json", "studio/pointer.schema.json", "studio/trace.schema.json", "studio/runtime.example.json", "studio/image-generation.config.example.json", "studio/current-project.example.json")) {
  $files += [pscustomobject]@{ source = Join-Path $Root $relative; relative = $relative }
}

if (-not $Check) {
  foreach ($dir in @($mirrorDirs + @("dashboard", "studio"))) {
    $target = [System.IO.Path]::GetFullPath((Join-Path $pluginRoot $dir))
    if (-not $target.StartsWith($pluginRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe package target: $target" }
    if (Test-Path $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  }
}

$errors = @()
foreach ($file in $files) {
  if (-not (Test-Path $file.source)) { $errors += "Missing source: $($file.source)"; continue }
  $target = Join-Path $pluginRoot $file.relative
  if ($Check) {
    if (-not (Test-Path $target)) { $errors += "Package missing: $($file.relative)"; continue }
    if ((Get-FileHash -LiteralPath $file.source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash) {
      $errors += "Package stale: $($file.relative)"
    }
  } else {
    $targetDir = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Copy-Item -LiteralPath $file.source -Destination $target -Force
  }
}
if ($errors.Count -gt 0) { throw ($errors -join "`n") }

[pscustomobject]@{ status = "passed"; check = [bool]$Check; plugin_root = $pluginRoot; mirrored_files = $files.Count } | ConvertTo-Json
