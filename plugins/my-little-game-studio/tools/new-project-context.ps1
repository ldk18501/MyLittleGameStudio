param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$RuntimeRoot = "",
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$InvocationId = "",
  [string]$TaskId = ""
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
if ([string]::IsNullOrWhiteSpace($InvocationId)) {
  $InvocationId = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 10)
}

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RequireProjectContext")
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($RuntimeRoot) { $resolveArgs += @("-RuntimeRoot", $RuntimeRoot) }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
if (-not $resolved.exists -or -not $resolved.project_exists -or -not $resolved.context_safe) {
  throw "Cannot bind MLGS project context: $($resolved.context_reason)"
}

$contextDirectory = Join-Path ([string]$resolved.project_runtime_root) "contexts"
$contextPath = Join-Path $contextDirectory ($InvocationId + ".json")
$now = (Get-Date).ToString("o")
$context = [ordered]@{
  schemaVersion = "1.0"
  invocationId = $InvocationId
  taskId = $TaskId
  projectId = [string]$resolved.project_id
  projectRoot = ([System.IO.Path]::GetFullPath([string]$resolved.project_root)).Replace("\", "/")
  statePath = ([System.IO.Path]::GetFullPath([string]$resolved.state_path)).Replace("\", "/")
  runtimeRoot = ([System.IO.Path]::GetFullPath([string]$resolved.project_runtime_root)).Replace("\", "/")
  sourceMode = [string]$resolved.mode
  pointerMismatch = [bool]$resolved.pointer_mismatch
  pointerProjectRoot = [string]$resolved.pointer_project_root
  created = $now
  updated = $now
}
Write-MLGSJsonAtomic -Path $contextPath -Value $context
$context["contextPath"] = $contextPath.Replace("\", "/")
$context | ConvertTo-Json -Depth 8
