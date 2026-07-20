param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [ValidatePattern('^$|^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$InvocationId = "",
  [string[]]$ChangedPaths = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$RuntimeRoot = Get-MLGSRuntimeRoot -Root $Root -RuntimeRoot $RuntimeRoot

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RuntimeRoot", $RuntimeRoot, "-RequireProjectContext")
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
if (-not $resolved.exists -or $resolved.mode -eq "template") { throw "No project state is configured." }
if (-not [bool]$resolved.context_safe) { throw [string]$resolved.context_reason }
$effectiveInvocationId = $InvocationId
if ($resolved.context_invocation_id) {
  if ($effectiveInvocationId -and $effectiveInvocationId -ne [string]$resolved.context_invocation_id) { throw "InvocationId does not match the bound project context." }
  $effectiveInvocationId = [string]$resolved.context_invocation_id
}
if (-not $effectiveInvocationId) { throw "Project change validation requires a bound invocation and active path lease." }
$leaseResult = Test-MLGSActiveProjectLease -ProjectRuntimeRoot ([string]$resolved.project_runtime_root) -ProjectId ([string]$resolved.project_id) -InvocationId $effectiveInvocationId
if (-not $leaseResult.valid) { throw ($leaseResult.issues -join "; ") }
$leaseClaims = @($leaseResult.lease.paths)
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
$leaseViolations = @()
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
  if (@($leaseClaims | Where-Object { Test-MLGSPathWithinClaim -Path $relative -Claim ([string]$_) }).Count -eq 0) { $leaseViolations += $relative }
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
  valid = $violations.Count -eq 0 -and $leaseViolations.Count -eq 0
  project_root = $projectRootPath
  project_id = $resolved.project_id
  context_path = $resolved.context_path
  invocation_id = $effectiveInvocationId
  lease_path = $leaseResult.path
  lease_claims = @($leaseClaims)
  allowed_roots = $allowedRoots
  checked_paths = @($checked)
  violations = @($violations)
  lease_violations = @($leaseViolations)
}
$result | ConvertTo-Json -Depth 8
if (-not $result.valid) { exit 3 }

