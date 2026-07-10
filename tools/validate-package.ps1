param([string]$Root = "")

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
$pluginRoot = Join-Path $Root "plugins/my-little-game-studio"
$manifestPath = Join-Path $pluginRoot ".codex-plugin/plugin.json"
$skillPath = Join-Path $pluginRoot "skills/mlgs/SKILL.md"
$errors = @()
try { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { throw "Invalid plugin manifest JSON: $($_.Exception.Message)" }
if ($manifest.name -ne "my-little-game-studio") { $errors += "Plugin name is invalid." }
if ([string]$manifest.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') { $errors += "Plugin version is not strict semver." }
if ($manifest.skills -ne "./skills/") { $errors += "Plugin skills path must be ./skills/." }
if (-not (Test-Path $skillPath)) { $errors += "Public mlgs skill is missing." }
else {
  $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
  if ($skill -notmatch '(?s)^---\s*\r?\nname:\s*mlgs\s*\r?\ndescription:\s*.+?\r?\n---') { $errors += "Public skill frontmatter is invalid." }
  if ($skill -match '\[TODO:') { $errors += "Public skill contains TODO placeholders." }
}
foreach ($relative in @("AGENTS.md", "workflow/catalog.json", "commands/status.md", "tools/resolve-state.ps1", "studio/state.json", "studio/state.schema.json", "dashboard/index.html")) {
  if (-not (Test-Path (Join-Path $pluginRoot $relative))) { $errors += "Self-contained package missing $relative" }
}
if ($errors.Count -gt 0) { throw ($errors -join "`n") }
[pscustomobject]@{ status = "passed"; plugin_root = $pluginRoot; version = $manifest.version } | ConvertTo-Json

