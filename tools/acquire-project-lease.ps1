param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$InvocationId,
  [string]$TaskId = "",
  [string[]]$Paths = @(),
  [ValidateRange(1, 1440)][int]$LeaseMinutes = 120,
  [switch]$ReadOnly
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")

$resolveArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/resolve-state.ps1"), "-Root", $Root, "-RequireProjectContext")
if ($ProjectRoot) { $resolveArgs += @("-ProjectRoot", $ProjectRoot) }
if ($StatePath) { $resolveArgs += @("-StatePath", $StatePath) }
if ($ContextPath) { $resolveArgs += @("-ContextPath", $ContextPath) }
if ($RuntimeRoot) { $resolveArgs += @("-RuntimeRoot", $RuntimeRoot) }
$resolved = & powershell @resolveArgs | ConvertFrom-Json
if (-not $resolved.exists -or -not [bool]$resolved.context_safe) { throw "Project lease requires a bound project context." }
if ($resolved.context_invocation_id -and $InvocationId -ne [string]$resolved.context_invocation_id) { throw "Lease invocationId does not match the bound project context." }

$normalizedPaths = @($Paths | ForEach-Object {
  $path = ([string]$_).Replace("\", "/").Trim().Trim("/")
  if ([System.IO.Path]::IsPathRooted($path) -or $path -match '(^|/)\.\.(/|$)') { throw "Lease paths must be project-relative and cannot escape the project: $path" }
  $path
} | Where-Object { $_ } | Select-Object -Unique)
if (-not $ReadOnly -and $normalizedPaths.Count -eq 0) { throw "Writable project leases require at least one declared path." }

$runtime = [System.IO.Path]::GetFullPath([string]$resolved.project_runtime_root)
$leaseRoot = Join-Path $runtime "leases"
New-Item -ItemType Directory -Path $leaseRoot -Force | Out-Null
$lockPath = Join-Path $runtime ".lease.lock"
$lock = $null
for ($attempt = 0; $attempt -lt 50 -and $null -eq $lock; $attempt++) {
  try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') } catch { Start-Sleep -Milliseconds 100 }
}
if ($null -eq $lock) { throw "Could not acquire the project lease registry lock." }

$conflicts = @()
$leasePath = Join-Path $leaseRoot ($InvocationId + ".json")
$now = [DateTimeOffset]::Now
try {
  foreach ($file in @(Get-ChildItem -LiteralPath $leaseRoot -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
    try { $lease = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch {
      $conflicts += [pscustomobject]@{ invocationId = "unknown"; taskId = ""; path = $file.Name; reason = "Unreadable lease file" }
      continue
    }
    $expires = [DateTimeOffset]::MinValue
    try { $expires = [DateTimeOffset]::Parse([string]$lease.expiresAt) } catch { }
    if ($expires -le $now) {
      Remove-Item -LiteralPath $file.FullName -Force
      continue
    }
    if ([string]$lease.invocationId -eq $InvocationId -or $ReadOnly -or [bool]$lease.readOnly) { continue }
    foreach ($requestedPath in $normalizedPaths) {
      foreach ($ownedPath in @($lease.paths)) {
        if (Test-MLGSPathOverlap -Left $requestedPath -Right ([string]$ownedPath)) {
          $conflicts += [pscustomobject]@{ invocationId = [string]$lease.invocationId; taskId = [string]$lease.taskId; path = [string]$ownedPath; requestedPath = $requestedPath; reason = "Overlapping project write path" }
        }
      }
    }
  }
  if ($conflicts.Count -eq 0) {
    $lease = [ordered]@{
      schemaVersion = "1.0"
      invocationId = $InvocationId
      taskId = $TaskId
      projectId = [string]$resolved.project_id
      projectRoot = ([System.IO.Path]::GetFullPath([string]$resolved.project_root)).Replace("\", "/")
      readOnly = [bool]$ReadOnly
      paths = @($normalizedPaths)
      acquiredAt = $now.ToString("o")
      expiresAt = $now.AddMinutes($LeaseMinutes).ToString("o")
    }
    Write-MLGSJsonAtomic -Path $leasePath -Value $lease
  }
} finally {
  $lock.Dispose()
  if (Test-Path $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}

$result = [pscustomobject]@{
  acquired = $conflicts.Count -eq 0
  invocation_id = $InvocationId
  task_id = $TaskId
  project_id = $resolved.project_id
  project_root = $resolved.project_root
  runtime_root = $runtime
  lease_path = $(if ($conflicts.Count -eq 0) { $leasePath } else { "" })
  paths = @($normalizedPaths)
  read_only = [bool]$ReadOnly
  conflicts = @($conflicts)
}
$result | ConvertTo-Json -Depth 10
if (-not $result.acquired) { exit 9 }
