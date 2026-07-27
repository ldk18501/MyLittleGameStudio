Set-StrictMode -Version 2.0

function Resolve-MLGSWorkflowCatalogPath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
  $candidate = [System.IO.Path]::GetFullPath((Join-Path $rootPath $RelativePath))
  if (-not $candidate.StartsWith($rootPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Workflow catalog reference escaped the MLGS root: $RelativePath"
  }
  if (-not (Test-Path -LiteralPath $candidate)) { throw "Workflow catalog reference is missing: $RelativePath" }
  return $candidate
}

function Import-MLGSWorkflowCatalog {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [switch]$IncludePhases,
    [switch]$IncludeGates
  )

  $catalogPath = Resolve-MLGSWorkflowCatalogPath -Root $Root -RelativePath "workflow/catalog.json"
  $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json

  if ($IncludePhases -and $catalog.PSObject.Properties.Name -notcontains "phases") {
    if ($catalog.PSObject.Properties.Name -notcontains "phaseCatalog") { throw "workflow/catalog.json is missing phaseCatalog." }
    $phasePath = Resolve-MLGSWorkflowCatalogPath -Root $Root -RelativePath ([string]$catalog.phaseCatalog)
    $phaseDocument = Get-Content -LiteralPath $phasePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $catalog | Add-Member -MemberType NoteProperty -Name phases -Value @($phaseDocument.phases) -Force
  }

  if ($IncludeGates -and $catalog.PSObject.Properties.Name -notcontains "gates") {
    if ($catalog.PSObject.Properties.Name -notcontains "gateCatalog") { throw "workflow/catalog.json is missing gateCatalog." }
    $gatePath = Resolve-MLGSWorkflowCatalogPath -Root $Root -RelativePath ([string]$catalog.gateCatalog)
    $gateDocument = Get-Content -LiteralPath $gatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $catalog | Add-Member -MemberType NoteProperty -Name gates -Value $gateDocument.gates -Force
  }

  return $catalog
}
