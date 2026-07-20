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
foreach ($relative in @("AGENTS.md", "agents/art-director.md", "workflow/catalog.json", "profiles/unity/catalog.json", "commands/status.md", "tools/resolve-state.ps1", "tools/init-production-pipeline.ps1", "tools/inspect-codebase.ps1", "tools/test-codebase-understanding.ps1", "tools/new-code-task.ps1", "tools/test-code-task.ps1", "tools/test-code-conformance.ps1", "tools/get-production-capabilities.ps1", "tools/test-production-capabilities.ps1", "tools/new-execution-strategy.ps1", "tools/select-game-profile.ps1", "tools/validate-game-profile-coverage.ps1", "tools/freeze-design-baseline.ps1", "tools/test-design-baseline.ps1", "tools/validate-ui-screen-contract.ps1", "tools/new-work-package.ps1", "tools/run-objective-checks.ps1", "tools/test-art-review.ps1", "tools/test-art-import-recipe.ps1", "tools/test-visual-comparison.ps1", "tools/test_visual_comparison.py", "tools/test-sprite-integrity.ps1", "tools/test_sprite_integrity.py", "tools/validate-release-scope.ps1", "studio/state.json", "studio/state.schema.json", "studio/visual-target.schema.json", "studio/visual-scene-contract.schema.json", "studio/visual-comparison.schema.json", "studio/release-scope.schema.json", "studio/work-package.schema.json", "studio/art-review.schema.json", "studio/art-import-recipe.schema.json", "studio/game-profile.schema.json", "studio/codebase-profile.schema.json", "studio/module-map.schema.json", "studio/task-context.schema.json", "studio/change-plan.schema.json", "studio/code-conformance.schema.json", "studio/ui-screen-contract.schema.json", "studio/design-baseline.schema.json", "studio/change-impact.schema.json", "studio/capability-manifest.schema.json", "studio/execution-strategy.schema.json", "dashboard/index.html")) {
  if (-not (Test-Path (Join-Path $pluginRoot $relative))) { $errors += "Self-contained package missing $relative" }
}
if ($errors.Count -gt 0) { throw ($errors -join "`n") }
[pscustomobject]@{ status = "passed"; plugin_root = $pluginRoot; version = $manifest.version } | ConvertTo-Json
