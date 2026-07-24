param(
  [string]$Root = "",
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [switch]$Force
)

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$Root = [System.IO.Path]::GetFullPath($Root)
. (Join-Path $Root "tools/mlgs-common.ps1")
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path $ProjectRoot)) { throw "Project root does not exist: $ProjectRoot" }

$directories = @(
  "design/art",
  "design/art/targets",
  "production/assets/prompts",
  "production/assets/batches",
  "production/assets/import-recipes",
  "production/assets/usage",
  "production/assets/reviews",
  "production/qa/evidence/art-batches",
  "production/qa/evidence/visual-comparisons",
  "production/quality",
  ".mlgs"
)
foreach ($relative in $directories) { New-Item -ItemType Directory -Path (Join-Path $ProjectRoot $relative) -Force | Out-Null }

$written = @()
function Copy-MLGSTemplate {
  param([string]$SourceRelative, [string]$TargetRelative)
  $source = Join-Path $Root $SourceRelative
  $target = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath $TargetRelative
  if ((Test-Path $target) -and -not $Force) { return }
  Copy-Item -LiteralPath $source -Destination $target -Force
  $script:written += $TargetRelative
}

Copy-MLGSTemplate "templates/art-style-bible.md" "design/art/style-bible.md"
Copy-MLGSTemplate "templates/visual-target.json" "design/art/visual-target.json"
Copy-MLGSTemplate "studio/art-asset-manifest.schema.json" ".mlgs/art-asset-manifest.schema.json"
Copy-MLGSTemplate "studio/visual-target.schema.json" ".mlgs/visual-target.schema.json"
Copy-MLGSTemplate "studio/art-prompt-metadata.schema.json" ".mlgs/art-prompt-metadata.schema.json"
Copy-MLGSTemplate "studio/art-batch.schema.json" ".mlgs/art-batch.schema.json"
Copy-MLGSTemplate "studio/art-usage.schema.json" ".mlgs/art-usage.schema.json"
Copy-MLGSTemplate "studio/quality-gate.schema.json" ".mlgs/quality-gate.schema.json"
Copy-MLGSTemplate "studio/art-review.schema.json" ".mlgs/art-review.schema.json"
Copy-MLGSTemplate "studio/visual-scene-contract.schema.json" ".mlgs/visual-scene-contract.schema.json"
Copy-MLGSTemplate "studio/art-import-recipe.schema.json" ".mlgs/art-import-recipe.schema.json"
Copy-MLGSTemplate "studio/visual-comparison.schema.json" ".mlgs/visual-comparison.schema.json"
Copy-MLGSTemplate "templates/visual-scene-contract.json" "design/art/visual-scene-contract.json"

$visualTargetPath = Join-Path $ProjectRoot "design/art/visual-target.json"
if (Test-Path $visualTargetPath) {
  $visualTarget = Get-Content -LiteralPath $visualTargetPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $visualTargetChanged = $false
  if ([string]$visualTarget.schemaVersion -eq "1.0") {
    $visualTarget.schemaVersion = "1.1"
    $visualTargetChanged = $true
  }
  foreach ($target in @($visualTarget.targets)) {
    if ($target.PSObject.Properties.Name -notcontains "styleLock") {
      $target | Add-Member -MemberType NoteProperty -Name styleLock -Value ([pscustomobject][ordered]@{
        renderingMedium = "MIGRATION REQUIRED: record the approved medium and rendering language."
        palette = @(
          [pscustomobject]@{ hex = "#1B2014"; role = "replace with approved shadow/background" },
          [pscustomobject]@{ hex = "#6F7545"; role = "replace with approved midtone" },
          [pscustomobject]@{ hex = "#D2CD83"; role = "replace with approved highlight" }
        )
        colorTemperature = "MIGRATION REQUIRED"
        saturation = "MIGRATION REQUIRED"
        contrast = "MIGRATION REQUIRED"
        lighting = @("MIGRATION REQUIRED")
        materials = @("MIGRATION REQUIRED")
        surfaceTexture = @("MIGRATION REQUIRED")
        shapeLanguage = @("MIGRATION REQUIRED")
        uiTreatment = @()
        preserve = @("MIGRATION REQUIRED: copy the invariants visible in the approved target image.")
        avoid = @("MIGRATION REQUIRED: record hue, material, UI, and composition drift to reject.")
      })
      $visualTargetChanged = $true
    }
  }
  if ([string]::IsNullOrWhiteSpace([string]$visualTarget.updated)) {
    $visualTarget.updated = (Get-Date).ToString("o")
    $visualTargetChanged = $true
  }
  if ($visualTargetChanged) {
    $visualTarget.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $visualTargetPath -Value $visualTarget
  }
}

$sceneContractPath = Join-Path $ProjectRoot "design/art/visual-scene-contract.json"
if (Test-Path $sceneContractPath) {
  $sceneContract = Get-Content -LiteralPath $sceneContractPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $sceneChanged = $false
  if ([string]$sceneContract.schemaVersion -eq "1.0") { $sceneContract.schemaVersion = "1.1"; $sceneChanged = $true }
  foreach ($scene in @($sceneContract.scenes)) {
    if ($scene.PSObject.Properties.Name -notcontains "comparisonReport") {
      $scene | Add-Member -MemberType NoteProperty -Name comparisonReport -Value ""
      $sceneChanged = $true
    }
  }
  if ([string]::IsNullOrWhiteSpace([string]$sceneContract.updated)) {
    $sceneContract.updated = (Get-Date).ToString("o")
    $sceneChanged = $true
  }
  if ($sceneChanged) { Write-MLGSJsonAtomic -Path $sceneContractPath -Value $sceneContract }
}

$manifestPath = Join-Path $ProjectRoot "production/assets/asset-manifest.json"
if ($Force -or -not (Test-Path $manifestPath)) {
  $manifest = [ordered]@{
    '$schema' = "../../.mlgs/art-asset-manifest.schema.json"
    schemaVersion = "1.6"
    updated = (Get-Date).ToString("o")
    visualTargetPath = "design/art/visual-target.json"
    assets = @()
  }
  Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
  $written += "production/assets/asset-manifest.json"
}
elseif (-not $Force) {
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $changed = $false
  if (@("1.0", "1.1", "1.2", "1.3", "1.4", "1.5") -contains [string]$manifest.schemaVersion) { $manifest.schemaVersion = "1.6"; $changed = $true }
  if ($manifest.PSObject.Properties.Name -notcontains "visualTargetPath") {
    $manifest | Add-Member -MemberType NoteProperty -Name visualTargetPath -Value "design/art/visual-target.json"
    $changed = $true
  }
  foreach ($asset in @($manifest.assets)) {
    if ($asset.PSObject.Properties.Name -notcontains "visualTargets") {
      $asset | Add-Member -MemberType NoteProperty -Name visualTargets -Value @()
      $changed = $true
    }
    if ($asset.PSObject.Properties.Name -notcontains "reviewPath") {
      $asset | Add-Member -MemberType NoteProperty -Name reviewPath -Value ""
      $changed = $true
    }
    if ($asset.PSObject.Properties.Name -notcontains "usageMetadata") {
      $asset | Add-Member -MemberType NoteProperty -Name usageMetadata -Value ("production/assets/usage/" + [string]$asset.id + ".json")
      $changed = $true
    }
    if ($asset.PSObject.Properties.Name -notcontains "visualComponent") {
      $asset | Add-Member -MemberType NoteProperty -Name visualComponent -Value ([pscustomobject][ordered]@{
        mode = "standalone"
        role = "MIGRATION REQUIRED: classify this asset or link it to an audited screen component."
        reuseKey = "MIGRATION REQUIRED: assign a stable reuse family."
        generationUnit = "single-sprite"
        styleDescription = "MIGRATION REQUIRED: record component-specific shape, border, fill, material, wear, and palette details."
        promptCore = "MIGRATION REQUIRED: record the exact component generation instruction."
        textPolicy = "no-text"
        requiredStates = @("default")
        sourceComponents = @()
        preserve = @("MIGRATION REQUIRED: record component-specific invariants.")
        avoid = @("MIGRATION REQUIRED: record component-specific drift to reject.")
      })
      $changed = $true
    }
    if ($asset.PSObject.Properties.Name -notcontains "statusHistory") {
      $asset | Add-Member -MemberType NoteProperty -Name statusHistory -Value @([pscustomobject]@{
        status = "planned"
        at = (Get-Date).ToString("o")
        evidence = @()
        note = "Migrated manifest; reconstruct subsequent lifecycle evidence before approval."
      })
      $changed = $true
    }
    if ($asset.PSObject.Properties.Name -notcontains "integrity") {
      $asset | Add-Member -MemberType NoteProperty -Name integrity -Value ([pscustomobject]@{
        sourceLayout = "individual"
        extractionMode = "single-object"
        minimumTransparentMargin = 8
        minimumFrameMargin = 2
        expectedFrames = 1
        maxSignificantComponents = 1
        maxBaselineVariance = 2
        maxFrameSizeVarianceRatio = 0.15
        reportPath = ""
        verdict = "pending"
      })
      $changed = $true
    }
    else {
      if ($asset.integrity.PSObject.Properties.Name -notcontains "maxBaselineVariance") {
        $asset.integrity | Add-Member -MemberType NoteProperty -Name maxBaselineVariance -Value 2
        $changed = $true
      }
      if ($asset.integrity.PSObject.Properties.Name -notcontains "maxFrameSizeVarianceRatio") {
        $asset.integrity | Add-Member -MemberType NoteProperty -Name maxFrameSizeVarianceRatio -Value 0.15
        $changed = $true
      }
    }
  }
  if ($changed) {
    $manifest.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $manifestPath -Value $manifest
    $written += "production/assets/asset-manifest.json"
  }
}

foreach ($asset in @($manifest.assets)) {
  if ([string]::IsNullOrWhiteSpace([string]$asset.importRecipe)) { continue }
  try { $recipePath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$asset.importRecipe) } catch { continue }
  if (-not (Test-Path $recipePath)) { continue }
  try { $recipe = Get-Content -LiteralPath $recipePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
  $recipeChanged = $false
  if ([string]$recipe.schemaVersion -eq "1.0") { $recipe.schemaVersion = "1.1"; $recipeChanged = $true }
  if ($recipe.PSObject.Properties.Name -notcontains "usageMetadata") {
    $recipe | Add-Member -MemberType NoteProperty -Name usageMetadata -Value ([string]$asset.usageMetadata)
    $recipeChanged = $true
  }
  if ($recipeChanged) {
    Write-MLGSJsonAtomic -Path $recipePath -Value $recipe
    $written += [string]$asset.importRecipe
  }
}

foreach ($asset in @($manifest.assets)) {
  if ([string]::IsNullOrWhiteSpace([string]$asset.promptMetadata)) { continue }
  try { $promptPath = Resolve-MLGSProjectArtifactPath -ProjectRoot $ProjectRoot -RelativePath ([string]$asset.promptMetadata) } catch { continue }
  if (-not (Test-Path $promptPath)) { continue }
  try { $prompt = Get-Content -LiteralPath $promptPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }
  $promptChanged = $false
  if ([string]$prompt.schemaVersion -eq "1.0") { $prompt.schemaVersion = "1.1"; $promptChanged = $true }
  if ($prompt.PSObject.Properties.Name -notcontains "manifestComponentSnapshot") {
    $prompt | Add-Member -MemberType NoteProperty -Name manifestComponentSnapshot -Value $asset.visualComponent
    $promptChanged = $true
  }
  if ($promptChanged) {
    $prompt.updated = (Get-Date).ToString("o")
    Write-MLGSJsonAtomic -Path $promptPath -Value $prompt
    $written += [string]$asset.promptMetadata
  }
}

[pscustomobject]@{
  initialized = $true
  project_root = $ProjectRoot
  manifest_path = $manifestPath
  files_written = @($written)
} | ConvertTo-Json -Depth 8
