param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [string[]]$ChangedPaths = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot)
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
if (-not $resolved.exists -or $resolved.mode -eq "template") { throw "No project state is configured." }
$projectRootPath = [System.IO.Path]::GetFullPath($resolved.project_root).TrimEnd('\', '/')
$state = Import-MLGSState -Path $resolved.state_path
$validation = Test-MLGSState -State $state
if (-not $validation.valid) { throw ("Invalid state: " + ($validation.errors -join "; ")) }

if ($ChangedPaths.Count -eq 0) {
  if (-not (Test-Path (Join-Path $projectRootPath ".git"))) { throw "Project is not a git repository; pass -ChangedPaths explicitly." }
  $ChangedPaths = @(
    git -C $projectRootPath diff --name-only --diff-filter=ACMR
    git -C $projectRootPath diff --cached --name-only --diff-filter=ACMR
    git -C $projectRootPath ls-files --others --exclude-standard
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
}

$catalog = Get-Content -LiteralPath (Join-Path $Root "workflow/catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$allowedRoots = @($catalog.alwaysWritableProjectPaths) + @($state.activeProject.approvedWritePaths)
$allowedRoots = @($allowedRoots | ForEach-Object { ([string]$_).Replace("\", "/").Trim("/") } | Where-Object { $_ } | Select-Object -Unique)
$checked = @()
$violations = @()
foreach ($changed in $ChangedPaths) {
  $pathText = ([string]$changed).Trim()
  if (-not $pathText) { continue }
  if ([System.IO.Path]::IsPathRooted($pathText)) {
    $absolute = [System.IO.Path]::GetFullPath($pathText)
    if (-not $absolute.StartsWith($projectRootPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
      $violations += $pathText
      continue
    }
    $relative = $absolute.Substring($projectRootPath.Length + 1).Replace("\", "/")
  } else {
    $relative = $pathText.Replace("\", "/")
    while ($relative.StartsWith("./", [System.StringComparison]::Ordinal)) { $relative = $relative.Substring(2) }
    $relative = $relative.TrimStart("/")
  }
  $checked += $relative
  $allowed = $false
  foreach ($rootPath in $allowedRoots) {
    if ($relative.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase) -or $relative.StartsWith($rootPath + "/", [System.StringComparison]::OrdinalIgnoreCase)) {
      $allowed = $true
      break
    }
  }
  if (-not $allowed) { $violations += $relative }
}

$result = [pscustomobject]@{
  valid = $violations.Count -eq 0
  project_root = $projectRootPath
  allowed_roots = $allowedRoots
  checked_paths = @($checked)
  violations = @($violations)
}
$result | ConvertTo-Json -Depth 8
if (-not $result.valid) { exit 3 }

