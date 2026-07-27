param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$AssetId,
  [string]$ManifestPath = "production/assets/asset-manifest.json"
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

$manifestFull = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $ManifestPath
if (-not (Test-Path -LiteralPath $manifestFull)) { throw "Missing art asset manifest: $ManifestPath" }
$manifest = Get-Content -LiteralPath $manifestFull -Raw -Encoding UTF8 | ConvertFrom-Json
$asset = @($manifest.assets | Where-Object { [string]$_.id -eq $AssetId }) | Select-Object -First 1
if (-not $asset) { throw "Art asset was not found in the manifest: $AssetId" }

$validation = Test-MLGSArtPromptMetadata -ProjectRoot $ProjectRoot -Path ([string]$asset.promptMetadata) -Asset $asset -VisualTargetPath ([string]$manifest.visualTargetPath)
if (-not $validation.passed) { throw ("Art prompt metadata is invalid: " + (@($validation.issues) -join "; ")) }

$promptFull = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$asset.promptMetadata)
$prompt = Get-Content -LiteralPath $promptFull -Raw -Encoding UTF8 | ConvertFrom-Json
$styleJson = $prompt.styleLockSnapshot | ConvertTo-Json -Compress -Depth 30
$componentJson = $prompt.manifestComponentSnapshot | ConvertTo-Json -Compress -Depth 30
$bytes = [System.Text.Encoding]::UTF8.GetBytes($styleJson + "`n" + $componentJson)
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
  $fingerprint = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
}
finally {
  $sha.Dispose()
}

[ordered]@{
  schemaVersion = "1.0"
  assetId = [string]$prompt.assetId
  contextFingerprint = $fingerprint
  model = [string]$prompt.model
  quality = [string]$prompt.quality
  referenceImages = @($prompt.referenceImages)
  generationCanvasSize = @($prompt.generationCanvasSize)
  requestedFinalSize = @($prompt.requestedFinalSize)
  background = [string]$prompt.background
  generationStrategy = [string]$prompt.generationStrategy
  batchPlan = [string]$prompt.batchPlan
  promptText = [string]$prompt.promptText
  postProcess = $prompt.postProcess
} | ConvertTo-Json -Depth 12
