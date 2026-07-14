param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string]$Path = "design/presentation-architecture.json",
  [switch]$ContractOnly
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$issues = @()
try { $contractPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $Path } catch { $issues += $_.Exception.Message }
if ($issues.Count -eq 0 -and -not (Test-Path $contractPath)) { $issues += "Missing presentation architecture contract: $Path" }
if ($issues.Count -eq 0) {
  try { $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $issues += "Invalid presentation architecture JSON: $($_.Exception.Message)" }
}
if ($issues.Count -eq 0) {
  if ([string]$contract.schemaVersion -ne "1.0") { $issues += "Presentation architecture schemaVersion must be 1.0." }
  if ([string]$contract.dimension -eq "2d" -and -not [bool]$contract.pureUIGame -and [string]$contract.coreGameplayRenderer -eq "ugui") {
    $issues += "A 2D non-pure-UI game cannot use UGUI as the core gameplay renderer. Use SpriteRenderer/TilemapRenderer in the scene."
  }
  if ([bool]$contract.pureUIGame -and -not [bool]$contract.ownerApprovedPureUI) {
    $issues += "pureUIGame requires explicit owner approval."
  }
  if ([string]$contract.architectVerdict -ne "pass" -or [string]$contract.status -ne "approved") { $issues += "Presentation architecture requires approved Unity Architect pass." }
  if (@($contract.blockers).Count -gt 0) { $issues += "Presentation architecture still has blockers: $(@($contract.blockers) -join '; ')" }
  foreach ($exception in @($contract.allowedUGUIExceptions)) {
    if (-not [bool]$exception.ownerApproved) { $issues += "UGUI exception '$($exception.path)' is not owner-approved." }
  }

  if (-not $ContractOnly) {
    $coreFiles = @()
    foreach ($relative in @($contract.coreGameplayPaths)) {
      try { $resolved = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) } catch { $issues += $_.Exception.Message; continue }
      if (-not (Test-Path $resolved)) { $issues += "Core gameplay path does not exist: $relative"; continue }
      if ((Get-Item -LiteralPath $resolved).PSIsContainer) {
        $coreFiles += @(Get-ChildItem -LiteralPath $resolved -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @(".cs", ".prefab", ".unity", ".asset", ".uxml") })
      } else { $coreFiles += Get-Item -LiteralPath $resolved }
    }
    $coreFiles = @($coreFiles | Sort-Object FullName -Unique)
    if ($coreFiles.Count -eq 0) { $issues += "Core gameplay paths contain no inspectable implementation files." }
    $combined = ""
    foreach ($file in $coreFiles) {
      $relativeFile = $file.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/').Replace("\", "/")
      $allowed = @($contract.allowedUGUIExceptions | Where-Object { [bool]$_.ownerApproved -and $relativeFile.StartsWith(([string]$_.path).TrimEnd('/', '\'), [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
      $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
      $combined += "`n$content"
      if (-not $allowed -and [string]$contract.dimension -eq "2d" -and -not [bool]$contract.pureUIGame -and $content -match "(?i)(UnityEngine\.UI|CanvasRenderer|RectTransform|GraphicRaycaster|m_Name:\s*Canvas|!u!223)") {
        $issues += "UGUI/Canvas content is inside declared core gameplay path: $relativeFile"
      }
    }
    if ([string]$contract.dimension -eq "2d" -and -not [bool]$contract.pureUIGame -and $combined -notmatch "(?i)(SpriteRenderer|TilemapRenderer)") {
      $issues += "2D core gameplay has no SpriteRenderer or TilemapRenderer evidence."
    }
    foreach ($component in @($contract.requiredWorldComponents)) {
      if ($combined -notmatch [regex]::Escape([string]$component)) { $issues += "Missing required world component evidence: $component" }
    }
    foreach ($relative in @($contract.evidence)) {
      $pathIssue = Test-MLGSProjectEvidencePath -ProjectRoot $ProjectRoot -RelativePath ([string]$relative) -Label "Presentation architecture evidence"
      if ($pathIssue) { $issues += $pathIssue }
    }
  }
}
$result = [pscustomobject]@{ passed = $issues.Count -eq 0; path = $contractPath; contractOnly = [bool]$ContractOnly; issues = @($issues) }
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 18 }
