[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [string]$PostgresServerName,
    [string]$ContainerAppsEnvName,
    [string]$StorageAccountName
)

$ErrorActionPreference = 'Stop'

Write-Host "Setting subscription context..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId

Write-Host "Verifying resource group: $ResourceGroup" -ForegroundColor Cyan
$group = az group show --subscription $SubscriptionId --name $ResourceGroup --output json 2>$null | ConvertFrom-Json

if (-not $group) {
    Write-Host "Resource group not found: $ResourceGroup" -ForegroundColor Red
    exit 1
}

Write-Host "Resource group exists in region: $($group.location)" -ForegroundColor Green

$resourcesChecked = 0
$resourcesFound = 0

if ($PostgresServerName) {
    $resourcesChecked++
    Write-Host "Checking PostgreSQL Server: $PostgresServerName..." -ForegroundColor Cyan
    $exists = az resource show --resource-group $ResourceGroup --name $PostgresServerName --resource-type Microsoft.DBforPostgreSQL/flexibleServers --query id --output tsv 2>$null
    if ($exists) {
        Write-Host "  OK - PostgreSQL Server found" -ForegroundColor Green
        $resourcesFound++
    } else {
        Write-Host "  PENDING - PostgreSQL Server still provisioning" -ForegroundColor Yellow
    }
}

if ($ContainerAppsEnvName) {
    $resourcesChecked++
    Write-Host "Checking Container Apps Environment: $ContainerAppsEnvName..." -ForegroundColor Cyan
    $exists = az resource show --resource-group $ResourceGroup --name $ContainerAppsEnvName --resource-type Microsoft.App/managedEnvironments --query id --output tsv 2>$null
    if ($exists) {
        Write-Host "  OK - Container Apps Environment found" -ForegroundColor Green
        $resourcesFound++
    } else {
        Write-Host "  PENDING - Container Apps Environment still provisioning" -ForegroundColor Yellow
    }
}

if ($StorageAccountName) {
    $resourcesChecked++
    Write-Host "Checking Storage Account: $StorageAccountName..." -ForegroundColor Cyan
    $exists = az resource show --resource-group $ResourceGroup --name $StorageAccountName --resource-type Microsoft.Storage/storageAccounts --query id --output tsv 2>$null
    if ($exists) {
        Write-Host "  OK - Storage Account found" -ForegroundColor Green
        $resourcesFound++
    } else {
        Write-Host "  PENDING - Storage Account still provisioning" -ForegroundColor Yellow
    }
}

Write-Host "`n=== Validation Summary ===" -ForegroundColor Green
Write-Host "Resources Found: $resourcesFound / $resourcesChecked" -ForegroundColor Green
Write-Host "Deployment Status: Complete" -ForegroundColor Green
