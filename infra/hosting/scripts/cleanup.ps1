[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Azure {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    $result = & az @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Azure command failed: $($Arguments -join ' ')`n$result"
    }
    return $result
}

# Set subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Cyan
Invoke-Azure account set --subscription $SubscriptionId

# Verify resource group exists
Write-Host "Checking resource group: $ResourceGroup" -ForegroundColor Cyan
$groupExists = (Invoke-Azure group exists --subscription $SubscriptionId --name $ResourceGroup --output tsv).Trim()

if ($groupExists -ne 'true') {
    Write-Host "✗ Resource group not found: $ResourceGroup" -ForegroundColor Red
    exit 1
}

# Get resource count
Write-Host "Retrieving resource count..." -ForegroundColor Cyan
$resources = Invoke-Azure resource list --subscription $SubscriptionId --resource-group $ResourceGroup --output json | ConvertFrom-Json
$resourceCount = $resources.Count

Write-Host "Found $resourceCount resources in resource group: $ResourceGroup" -ForegroundColor Yellow

# Confirm deletion
if (-not $Force) {
    Write-Host "`n⚠️  WARNING: This will permanently delete the resource group and all its resources!" -ForegroundColor Yellow
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Red
    Write-Host "Number of resources to delete: $resourceCount" -ForegroundColor Red
    
    $confirmation = Read-Host "`nType 'DELETE' to confirm resource group deletion"
    
    if ($confirmation -ne 'DELETE') {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Delete resource group
Write-Host "Deleting resource group: $ResourceGroup" -ForegroundColor Cyan
Invoke-Azure group delete --subscription $SubscriptionId --name $ResourceGroup --yes --no-wait

Write-Host "✓ Resource group deletion initiated. This may take several minutes to complete." -ForegroundColor Green
Write-Host "You can monitor the deletion progress in Azure Portal or by running:" -ForegroundColor Yellow
Write-Host "  az group show --subscription $SubscriptionId --name $ResourceGroup --query 'properties.provisioningState' --output tsv" -ForegroundColor Gray
