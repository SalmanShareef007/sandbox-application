[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]{3,8}$')][string]$Suffix,
    [Parameter(Mandatory)][string]$DbAdminUser,
    [Parameter(Mandatory)][string]$DbAdminPassword,
    [string]$Location = 'Central India',
    [string]$ImageTag = (Get-Date -Format 'yyyyMMddHHmmss'),
    [switch]$CreateResourceGroup,
    [switch]$Apply,
    [switch]$Validate
)

$ErrorActionPreference = 'Stop'

# Set subscription context
Write-Host "Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Failed to set subscription' }

# Check/Create resource group
Write-Host "Checking resource group: $ResourceGroup" -ForegroundColor Cyan
$groupExists = az group exists --resource-group $ResourceGroup --subscription $SubscriptionId | ConvertFrom-Json

if ($CreateResourceGroup) {
    if ($groupExists) {
        Write-Host "Resource group already exists: $ResourceGroup" -ForegroundColor Green
    } else {
        Write-Host "Creating resource group: $ResourceGroup in region: $Location" -ForegroundColor Cyan
        az group create --subscription $SubscriptionId --name $ResourceGroup --location $Location | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Failed to create resource group' }
        Write-Host "Resource group created: $ResourceGroup" -ForegroundColor Green
    }
    return
}

# Prepare deployment parameters
Write-Host "`nPreparing deployment parameters..." -ForegroundColor Cyan
$paramObject = @{
    schema = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        suffix = @{ value = $Suffix }
        imageTag = @{ value = $ImageTag }
        dbAdminUser = @{ value = $DbAdminUser }
        dbAdminPassword = @{ value = $DbAdminPassword }
        location = @{ value = $Location }
    }
}

$tempFile = Join-Path $env:TEMP "bicep-params-$(Get-Random).json"
$paramObject | ConvertTo-Json | Set-Content -LiteralPath $tempFile -Encoding utf8

try {
    # Validate Bicep template
    Write-Host "`nValidating Bicep template..." -ForegroundColor Cyan
    az deployment group validate `
        --subscription $SubscriptionId `
        --resource-group $ResourceGroup `
        --template-file "main.bicep" `
        --parameters "@$tempFile" `
        --output none
    
    if ($LASTEXITCODE -ne 0) { throw 'Validation failed' }
    Write-Host "Template validation passed" -ForegroundColor Green

    # Show what-if preview
    Write-Host "`nGenerating deployment preview..." -ForegroundColor Cyan
    az deployment group what-if `
        --subscription $SubscriptionId `
        --resource-group $ResourceGroup `
        --template-file "main.bicep" `
        --parameters "@$tempFile" `
        --result-format ResourceIdOnly

    if (-not $Apply) {
        Write-Host "`nPreview complete. Run with -Apply flag to deploy." -ForegroundColor Yellow
        return
    }

    # Apply deployment
    Write-Host "`nApplying deployment..." -ForegroundColor Cyan
    az deployment group create `
        --subscription $SubscriptionId `
        --resource-group $ResourceGroup `
        --template-file "main.bicep" `
        --parameters "@$tempFile" `
        --name "sandbox-hosting-$ImageTag" `
        --output none
    
    if ($LASTEXITCODE -ne 0) { throw 'Deployment failed' }
    Write-Host "Deployment completed successfully" -ForegroundColor Green

    # Get and display outputs
    Write-Host "`nRetrieving deployment outputs..." -ForegroundColor Cyan
    $outputs = az deployment group show `
        --subscription $SubscriptionId `
        --resource-group $ResourceGroup `
        --name "sandbox-hosting-$ImageTag" `
        --query 'properties.outputs' `
        --output json | ConvertFrom-Json

    Write-Host "`n=== Deployed Resources ===" -ForegroundColor Green
    if ($outputs.postgresServerName) { Write-Host "PostgreSQL: $($outputs.postgresServerName.value)" -ForegroundColor Cyan }
    if ($outputs.containerAppsEnvName) { Write-Host "Container Apps: $($outputs.containerAppsEnvName.value)" -ForegroundColor Cyan }
    if ($outputs.appServiceName) { Write-Host "App Service: $($outputs.appServiceName.value)" -ForegroundColor Cyan }
    if ($outputs.containerRegistryName) { Write-Host "Container Registry: $($outputs.containerRegistryName.value)" -ForegroundColor Cyan }
    if ($outputs.storageAccountName) { Write-Host "Storage Account: $($outputs.storageAccountName.value)" -ForegroundColor Cyan }

} finally {
    if (Test-Path $tempFile) { Remove-Item -LiteralPath $tempFile -ErrorAction SilentlyContinue }
}

Write-Host "`nInfrastructure deployment complete!" -ForegroundColor Green
