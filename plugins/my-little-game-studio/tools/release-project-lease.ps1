param(
  [string]$Root = "",
  [string]$ProjectRoot = "",
  [string]$StatePath = "",
  [string]$ContextPath = "",
  [string]$RuntimeRoot = "",
  [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')][string]$InvocationId
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
if (-not $resolved.exists -or -not [bool]$resolved.context_safe) { throw "Project lease release requires a bound project context." }
if ($resolved.context_invocation_id -and $InvocationId -ne [string]$resolved.context_invocation_id) { throw "Lease invocationId does not match the bound project context." }
$runtime = [System.IO.Path]::GetFullPath([string]$resolved.project_runtime_root)
$leasePath = Join-Path $runtime ("leases/" + $InvocationId + ".json")
$lockPath = Join-Path $runtime ".lease.lock"
$lock = $null
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
for ($attempt = 0; $attempt -lt 50 -and $null -eq $lock; $attempt++) {
  try { $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') } catch { Start-Sleep -Milliseconds 100 }
}
if ($null -eq $lock) { throw "Could not acquire the project lease registry lock." }
try {
  if (Test-Path $leasePath) { Remove-Item -LiteralPath $leasePath -Force }
} finally {
  $lock.Dispose()
  if (Test-Path $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
[pscustomobject]@{ released = $true; invocation_id = $InvocationId; project_id = $resolved.project_id; lease_path = $leasePath } | ConvertTo-Json
