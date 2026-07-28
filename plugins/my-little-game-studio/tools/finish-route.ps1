param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ContextPath,
  [Parameter(Mandatory = $true)][string]$Command,
  [Parameter(Mandatory = $true)][string]$Title,
  [string]$TaskId = "",
  [string]$LeadAgent = "producer",
  [string[]]$AgentsUsed = @("producer"),
  [string[]]$SkillsUsed = @(),
  [string[]]$FilesRead = @(),
  [string[]]$FilesWritten = @(),
  [string[]]$ChangedPaths = @(),
  [string[]]$Assumptions = @(),
  [string[]]$Decisions = @(),
  [string[]]$Verification = @(),
  [string]$Summary = "",
  [ValidateSet("completed", "partial", "blocked")][string]$Status = "completed",
  [ValidateSet("model", "full")][string]$View = "model"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)

$resolved = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/resolve-state.ps1") -Root $Root -ContextPath $ContextPath -RequireProjectContext | ConvertFrom-Json
$InvocationId = [string]$resolved.context_invocation_id
if (-not $InvocationId) { throw "finish-route requires a bound invocation." }
if (-not $TaskId) { $TaskId = [string]$resolved.context_task_id }

$validateArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $Root "tools/validate-changes.ps1"), "-Root", $Root, "-ContextPath", $ContextPath, "-InvocationId", $InvocationId)
if (@($ChangedPaths).Count -gt 0) { $validateArgs += @("-ChangedPaths") + @($ChangedPaths) }
$validationRaw = & powershell @validateArgs | Out-String
$validationExit = $LASTEXITCODE
$validation = $validationRaw | ConvertFrom-Json
if ($validationExit -ne 0 -or -not [bool]$validation.valid) {
  $result = [ordered]@{
    finished = $false
    command = $Command
    contextPath = $ContextPath
    invocationId = $InvocationId
    taskId = $TaskId
    leaseRetained = $true
    violations = @($validation.violations)
    leaseViolations = @($validation.lease_violations)
  }
  if ($View -eq "model") { $result | ConvertTo-Json -Depth 10 -Compress } else { $result | ConvertTo-Json -Depth 10 }
  exit $(if ($validationExit) { $validationExit } else { 3 })
}

$tracePath = Join-Path $Root "tools/trace.ps1"
$traceOutput = & $tracePath -Root $Root -ContextPath $ContextPath -Command $Command -Title $Title -Status $Status -InvocationId $InvocationId -TaskId $TaskId -LeadAgent $LeadAgent -AgentsUsed $AgentsUsed -SkillsUsed $SkillsUsed -FilesRead $FilesRead -FilesWritten $FilesWritten -Assumptions $Assumptions -Decisions $Decisions -Verification $Verification -Summary $Summary | Out-String
if ($LASTEXITCODE -ne 0) { throw "Route trace failed; the project lease was retained. $traceOutput" }

$release = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root "tools/release-project-lease.ps1") -Root $Root -ContextPath $ContextPath -InvocationId $InvocationId | ConvertFrom-Json
$result = [ordered]@{
  finished = [bool]$release.released
  command = $Command
  projectId = [string]$resolved.project_id
  projectRoot = [string]$resolved.project_root
  contextPath = $ContextPath
  invocationId = $InvocationId
  taskId = $TaskId
  checkedPaths = @($validation.checked_paths).Count
  status = $Status
  traceRecorded = $true
  leaseReleased = [bool]$release.released
}
if ($View -eq "model") { $result | ConvertTo-Json -Depth 10 -Compress } else { $result | ConvertTo-Json -Depth 10 }
