param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][ValidateSet("pass", "fail", "blocked")][string]$Verdict,
  [string[]]$Artifacts = @(),
  [string[]]$Evidence = @(),
  [string[]]$Gaps = @()
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$packagePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path
$package = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json
$next = [int]$package.budget.currentAttempt + 1
if ($next -gt [int]$package.budget.maxAttempts) { throw "Attempt budget is exhausted." }
if ($Verdict -ne "pass" -and @($Gaps).Count -eq 0) { throw "Failed or blocked attempts require focused gaps." }
$attempt = [pscustomobject]@{
  number = $next
  status = $Verdict
  started = (Get-Date).ToString("o")
  finished = (Get-Date).ToString("o")
  artifacts = @($Artifacts)
  evidence = @($Evidence)
  gaps = @($Gaps)
}
$package.attempts = @($package.attempts) + $attempt
$package.budget.currentAttempt = $next
$package.gaps = @($Gaps)
if ($Verdict -eq "pass" -and [string]$package.objectiveVerdict -eq "pass" -and @($package.blockers).Count -eq 0) {
  $package.status = "done"
  $package.declaredVerdict = "pass"
  $package.gaps = @()
}
elseif ($Verdict -eq "blocked" -or $next -ge [int]$package.budget.maxAttempts) {
  $package.status = "blocked"
  $package.declaredVerdict = "blocked"
  if (@($package.blockers).Count -eq 0) { $package.blockers = @("Attempt budget exhausted or explicitly blocked.") }
}
else {
  $package.status = "ready"
  $package.declaredVerdict = "fail"
}
$package.updated = (Get-Date).ToString("o")
Write-MLGSJsonAtomic -Path $packagePath -Value $package
[pscustomobject]@{ path = $packagePath; status = $package.status; attempt = $next; attempts_remaining = ([int]$package.budget.maxAttempts - $next) } | ConvertTo-Json -Depth 8
