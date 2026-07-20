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
if (-not (Test-Path $manifestFull)) { throw "Missing art asset manifest: $ManifestPath" }
$manifest = Get-Content -LiteralPath $manifestFull -Raw -Encoding UTF8 | ConvertFrom-Json
$asset = @($manifest.assets | Where-Object { [string]$_.id -eq $AssetId }) | Select-Object -First 1
if (-not $asset) { throw "Art asset was not found in the manifest: $AssetId" }
$result = Test-MLGSArtImportRecipe -ProjectRoot $ProjectRoot -Path ([string]$asset.importRecipe) -Asset $asset
$result | ConvertTo-Json -Depth 10
if (-not $result.passed) { exit 20 }
