param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [string[]]$DeclareReady = @(),
  [string]$Provider = "Confirmed by producer",
  [string[]]$Evidence = @(),
  [switch]$SupportsVerification,
  [switch]$NoWrite
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$path = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath "production/capabilities/capability-manifest.json"
$schemaPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ".mlgs/capability-manifest.schema.json"
if (-not $NoWrite) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $schemaPath) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $Root "studio/capability-manifest.schema.json") -Destination $schemaPath -Force
}
if (Test-Path $path) { $manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }
else { $manifest = Get-Content -LiteralPath (Join-Path $Root "templates/capability-manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json }

$unityDetected = (Test-Path (Join-Path $ProjectRoot "Assets")) -and (Test-Path (Join-Path $ProjectRoot "ProjectSettings/ProjectVersion.txt"))
$configPath = @((Join-Path $ProjectRoot ".mlgs/image-generation.config.json"), (Join-Path $Root "studio/image-generation.config.json")) | Where-Object { Test-Path $_ } | Select-Object -First 1
$imageProvider = ""
if ($configPath) {
  try { $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json; if ([string]$config.provider -ne "none") { $imageProvider = [string]$config.provider } } catch { }
}
foreach ($capability in @($manifest.capabilities)) {
  if ([string]$capability.source -eq "manual" -and [string]$capability.status -eq "ready") { continue }
  switch ([string]$capability.kind) {
    "image-generation" {
      if ($imageProvider) {
        $capability.provider = $imageProvider
        $capability.status = "ready"
        $capability.source = "detected"
        $capability.outputs = @("raster-image")
        $capability.constraints = @("Provider credentials and cost must still pass preflight.")
      }
    }
    "sprite-processing" {
      if ($unityDetected) {
        $capability.provider = "Unity texture/sprite importer; live automation confirmation required"
        $capability.status = "manual"
        $capability.source = "detected"
        $capability.outputs = @("sprite", "sprite-atlas")
      }
    }
    "unity-import" {
      if ($unityDetected) {
        $capability.provider = "Unity project detected; live editor or approved Editor tooling required"
        $capability.status = "manual"
        $capability.source = "detected"
        $capability.outputs = @("imported-asset", "serialized-reference")
      }
    }
    "unity-validation" {
      if ($unityDetected) {
        $capability.provider = "Unity project detected; compile/scene/build validation must be confirmed"
        $capability.status = "manual"
        $capability.source = "detected"
        $capability.supportsVerification = $true
        $capability.outputs = @("compile-report", "scene-evidence", "build-report")
      }
    }
  }
}
foreach ($kind in @($DeclareReady)) {
  $entry = @($manifest.capabilities | Where-Object { [string]$_.kind -eq [string]$kind }) | Select-Object -First 1
  if (-not $entry) { throw "Unknown capability kind: $kind" }
  $entry.provider = $Provider
  $entry.status = "ready"
  $entry.source = "manual"
  $entry.supportsVerification = [bool]$SupportsVerification
  $entry.evidence = @($Evidence)
}
$manifest.'$schema' = "../../.mlgs/capability-manifest.schema.json"
$manifest.schemaVersion = "1.0"
$manifest.updated = (Get-Date).ToString("o")
if (-not $NoWrite) { Write-MLGSJsonAtomic -Path $path -Value $manifest }
[pscustomobject]@{
  path = $path
  unity_detected = $unityDetected
  ready = @($manifest.capabilities | Where-Object status -eq "ready" | ForEach-Object kind)
  manual = @($manifest.capabilities | Where-Object status -eq "manual" | ForEach-Object kind)
  missing = @($manifest.capabilities | Where-Object status -in @("missing", "blocked") | ForEach-Object kind)
} | ConvertTo-Json -Depth 8
