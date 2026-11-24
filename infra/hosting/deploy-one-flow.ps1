#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9]{3,8}$')][string]$Suffix,
    [Parameter(Mandatory)][string]$DbAdminUser,
    [Parameter(Mandatory)][string]$DbAdminPassword,
    [Parameter(HelpMessage = 'Azure region')][string]$Location = 'Central India'
)

$ErrorActionPreference = 'Stop'
$startTime = Get-Date

Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║          AUTOMATED INFRASTRUCTURE DEPLOYMENT                   ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Suffix: $Suffix" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host ""

try {
    # STEP 1: Create Resource Group
    Write-Host "▶ STEP 1: Creating resource group..." -ForegroundColor Cyan
    & .\deploy.ps1 `
        -SubscriptionId $SubscriptionId `
        -ResourceGroup $ResourceGroup `
        -Suffix $Suffix `
        -DbAdminUser $DbAdminUser `
        -DbAdminPassword $DbAdminPassword `
        -Location $Location `
        -CreateResourceGroup
    
    Write-Host "✓ Resource group created/verified" -ForegroundColor Green
    Write-Host ""

    # STEP 2: Deploy Infrastructure
    Write-Host "▶ STEP 2: Deploying infrastructure (this may take 5-10 minutes)..." -ForegroundColor Cyan
    & .\deploy.ps1 `
        -SubscriptionId $SubscriptionId `
        -ResourceGroup $ResourceGroup `
        -Suffix $Suffix `
        -DbAdminUser $DbAdminUser `
        -DbAdminPassword $DbAdminPassword `
        -Location $Location `
        -Apply
    
    Write-Host "✓ Infrastructure deployed successfully" -ForegroundColor Green
    Write-Host ""

    # STEP 3: Validate Deployment
    Write-Host "▶ STEP 3: Validating resources..." -ForegroundColor Cyan
    & .\scripts\validate-deployment.ps1 `
        -SubscriptionId $SubscriptionId `
        -ResourceGroup $ResourceGroup `
        -PostgresServerName "psql-$Suffix" `
        -ContainerAppsEnvName "cae-$Suffix" `
        -StorageAccountName "st$($Suffix -replace '-', '')logs"
    
    Write-Host "✓ All resources validated" -ForegroundColor Green
    Write-Host ""

    $duration = (Get-Date) - $startTime
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                  ✅ DEPLOYMENT COMPLETE!                       ║
║                                                                ║
║  All infrastructure components deployed successfully.          ║
║  Duration: $($duration.TotalMinutes.ToString('F1')) minutes                                   ║
║                                                                ║
║  Next Steps:                                                  ║
║  1. View resources in Azure Portal                            ║
║  2. Configure application settings                            ║
║  3. Deploy application code                                   ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green

} catch {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                 ❌ DEPLOYMENT FAILED                           ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
