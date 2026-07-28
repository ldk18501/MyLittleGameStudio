param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][ValidateSet("implement", "fix", "generate-art", "productize")][string]$Command,
  [string]$ProjectRoot = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [ValidatePattern('^$|^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$InvocationId = "",
  [ValidatePattern("^$|^[a-z0-9][a-z0-9-]*$")][string]$TaskId = "",
  [Parameter(Mandatory = $true)][string[]]$Paths,
  [ValidateRange(1, 1440)][int]$LeaseMinutes = 120,
  [switch]$AcceptRisk,
  [ValidateSet("model", "full")][string]$View = "model"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
if (-not $ContextPath -and -not $ProjectRoot) { throw "start-route requires -ProjectRoot or -ContextPath." }

if (-not $ContextPath) {
  $contextArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/new-project-context.ps1"), "-Root", $Root, "-ProjectRoot", $ProjectRoot)
  if ($RuntimeRoot) { $contextArgs += @("-RuntimeRoot", $RuntimeRoot) }
  if ($InvocationId) { $contextArgs += @("-InvocationId", $InvocationId) }
  if ($TaskId) { $contextArgs += @("-TaskId", $TaskId) }
  $context = & powershell @contextArgs | ConvertFrom-Json
  $ContextPath = [string]$context.contextPath
  $InvocationId = [string]$context.invocationId
} else {
  $resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-ContextPath", $ContextPath, "-RequireProjectContext")
  if ($RuntimeRoot) { $resolveArgs += @("-RuntimeRoot", $RuntimeRoot) }
  $resolved = & powershell @resolveArgs | ConvertFrom-Json
  if ($InvocationId -and $InvocationId -ne [string]$resolved.context_invocation_id) { throw "InvocationId does not match the bound project context." }
  $InvocationId = [string]$resolved.context_invocation_id
  if (-not $TaskId) { $TaskId = [string]$resolved.context_task_id }
}

$leaseArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/acquire-project-lease.ps1"), "-Root", $Root, "-ContextPath", $ContextPath, "-InvocationId", $InvocationId, "-LeaseMinutes", $LeaseMinutes)
if ($RuntimeRoot) { $leaseArgs += @("-RuntimeRoot", $RuntimeRoot) }
if ($TaskId) { $leaseArgs += @("-TaskId", $TaskId) }
$leaseArgs += @("-Paths") + @($Paths)
$leaseRaw = & powershell @leaseArgs | Out-String
$leaseExit = $LASTEXITCODE
$lease = $leaseRaw | ConvertFrom-Json
if ($leaseExit -ne 0 -or -not [bool]$lease.acquired) {
  $result = [ordered]@{ started = $false; command = $Command; contextPath = $ContextPath; invocationId = $InvocationId; taskId = $TaskId; paths = @($Paths); blockers = @($lease.conflicts) }
  if ($View -eq "model") { $result | ConvertTo-Json -Depth 10 -Compress } else { $result | ConvertTo-Json -Depth 10 }
  exit $(if ($leaseExit) { $leaseExit } else { 9 })
}

$preflightArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/preflight-task.ps1"), "-Root", $Root, "-Command", $Command, "-ContextPath", $ContextPath, "-InvocationId", $InvocationId)
if ($RuntimeRoot) { $preflightArgs += @("-RuntimeRoot", $RuntimeRoot) }
if ($TaskId) { $preflightArgs += @("-TaskId", $TaskId) }
if ($AcceptRisk) { $preflightArgs += "-AcceptRisk" }
$preflightRaw = & powershell @preflightArgs | Out-String
$preflightExit = $LASTEXITCODE
$preflight = $preflightRaw | ConvertFrom-Json
if ($preflightExit -ne 0 -or -not [bool]$preflight.allowed) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/release-project-lease.ps1") -Root $Root -ContextPath $ContextPath -InvocationId $InvocationId 2>$null | Out-Null
  $result = [ordered]@{ started = $false; command = $Command; contextPath = $ContextPath; invocationId = $InvocationId; taskId = $TaskId; leaseReleased = $true; blockers = @($preflight.blockers) }
  if ($View -eq "model") { $result | ConvertTo-Json -Depth 10 -Compress } else { $result | ConvertTo-Json -Depth 10 }
  exit $(if ($preflightExit) { $preflightExit } else { 2 })
}

$result = [ordered]@{
  started = $true
  command = $Command
  projectId = [string]$preflight.project_id
  projectRoot = [string]$preflight.project_root
  contextPath = $ContextPath
  invocationId = $InvocationId
  taskId = $TaskId
  leasePath = [string]$lease.lease_path
  paths = @($lease.paths)
  acceptedRisk = [bool]$AcceptRisk
}
if ($View -eq "model") { $result | ConvertTo-Json -Depth 10 -Compress } else { $result | ConvertTo-Json -Depth 10 }
