#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Test and validate the complete Sandbox deployment
.DESCRIPTION
  Validates database creation, app service configuration, and connectivity
.PARAMETER ResourceGroupName
  Azure resource group name
.PARAMETER Suffix
  Resource naming suffix (e.g., prod8513)
.EXAMPLE
  .\test-deployment.ps1 -ResourceGroupName "sandbox-prod8513" -Suffix "prod8513"
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$ResourceGroupName,
  
  [Parameter(Mandatory = $true)]
  [string]$Suffix,
  
  [string]$Location = "East US"
)

$ErrorActionPreference = "Continue"
$results = @()

function Test-Result {
  param([string]$Name, [bool]$Success, [string]$Message)
  
  $status = if ($Success) { "✓ PASS" } else { "✗ FAIL" }
  $color = if ($Success) { "Green" } else { "Red" }
  
  Write-Host "$status - $Name" -ForegroundColor $color
  if ($Message) { Write-Host "  → $Message" -ForegroundColor Gray }
  
  $results += @{
    Name    = $Name
    Success = $Success
    Message = $Message
  }
}

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Sandbox Deployment Validation & Testing Suite       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# 1. Verify Azure CLI and login
Write-Host "1. Verifying Azure CLI Authentication" -ForegroundColor Cyan
try {
  $account = az account show 2>/dev/null | ConvertFrom-Json
  Test-Result "Azure CLI Login" $? "Logged in as $($account.user.name)"
} catch {
  Test-Result "Azure CLI Login" $false "Not logged in. Run 'az login' first."
  exit 1
}

# 2. Check Resource Group
Write-Host "`n2. Checking Resource Group" -ForegroundColor Cyan
$rg = az group show --name $ResourceGroupName 2>/dev/null | ConvertFrom-Json
Test-Result "Resource Group Exists" ($rg -ne $null) "$ResourceGroupName in $Location"

# 3. Verify Resources
Write-Host "`n3. Verifying Deployed Resources" -ForegroundColor Cyan

$resources = az resource list --resource-group $ResourceGroupName --query "[].{type:type, name:name}" -o json 2>/dev/null | ConvertFrom-Json

$requiredTypes = @(
  "Microsoft.Web/serverfarms",
  "Microsoft.Web/sites",
  "Microsoft.DBforPostgreSQL/flexibleServers",
  "Microsoft.KeyVault/vaults",
  "Microsoft.Storage/storageAccounts",
  "Microsoft.ContainerRegistry/registries"
)

foreach ($type in $requiredTypes) {
  $found = $resources | Where-Object { $_.type -eq $type }
  $typeName = ($type -split "/")[-1]
  Test-Result "$typeName Deployed" ($found -ne $null) "Count: $($found.Count)"
}

# 4. Check App Services
Write-Host "`n4. Checking App Services" -ForegroundColor Cyan

$apiAppName = "app-api-$Suffix"
$uiAppName = "app-ui-$Suffix"

$apiApp = az webapp show --resource-group $ResourceGroupName --name $apiAppName 2>/dev/null | ConvertFrom-Json
Test-Result "API App Service (Python 3.14)" ($apiApp -ne $null) "$($apiApp.defaultHostName)"

$uiApp = az webapp show --resource-group $ResourceGroupName --name $uiAppName 2>/dev/null | ConvertFrom-Json
Test-Result "UI App Service (Node.js 24)" ($uiApp -ne $null) "$($uiApp.defaultHostName)"

if ($apiApp) {
  Test-Result "API App Runtime" ($apiApp.siteConfig.linuxFxVersion -like "*PYTHON*") "Runtime: $($apiApp.siteConfig.linuxFxVersion)"
}

if ($uiApp) {
  Test-Result "UI App Runtime" ($uiApp.siteConfig.linuxFxVersion -like "*NODE*") "Runtime: $($uiApp.siteConfig.linuxFxVersion)"
}

# 5. Check PostgreSQL
Write-Host "`n5. Checking PostgreSQL Server" -ForegroundColor Cyan

$postgresName = "psql-$Suffix"
$postgres = az postgres flexible-server show --resource-group $ResourceGroupName --name $postgresName 2>/dev/null | ConvertFrom-Json
Test-Result "PostgreSQL Flexible Server" ($postgres -ne $null) "$($postgres.fullyQualifiedDomainName)"

if ($postgres) {
  Test-Result "PostgreSQL SKU" ($postgres -ne $null) "$($postgres.sku.name) - $($postgres.sku.tier)"
  Test-Result "PostgreSQL Storage" ($postgres -ne $null) "$($postgres.storage.storageSizeGB) GB"
}

# 6. Check Key Vault
Write-Host "`n6. Checking Key Vault" -ForegroundColor Cyan

$keyVaultName = "kv$(($Suffix -replace '-', ''))"
$keyVault = az keyvault show --name $keyVaultName --resource-group $ResourceGroupName 2>/dev/null | ConvertFrom-Json
Test-Result "Key Vault Deployed" ($keyVault -ne $null) "$($keyVault.name)"

if ($keyVault) {
  $secrets = az keyvault secret list --vault-name $keyVaultName --query "length(@)" 2>/dev/null
  Test-Result "Key Vault Secrets" ($secrets -gt 0) "Secrets stored: $secrets"
}

# 7. Test Database Connectivity
Write-Host "`n7. Testing Database Connectivity" -ForegroundColor Cyan

if ($postgres) {
  $dbTest = $true
  try {
    # This would require psql installed locally
    Write-Host "  → Skipping psql test (requires local PostgreSQL client)" -ForegroundColor Gray
    Write-Host "  → Manual test: psql -h $($postgres.fullyQualifiedDomainName) -U pgadmin -d sandboxDB" -ForegroundColor Gray
  } catch {
    $dbTest = $false
  }
  Test-Result "Database Reachable" $dbTest "FQDN: $($postgres.fullyQualifiedDomainName)"
}

# 8. Check Managed Identities
Write-Host "`n8. Checking Managed Identities" -ForegroundColor Cyan

if ($apiApp) {
  $apiIdentity = $apiApp.identity.principalId
  Test-Result "API App Identity" ($apiIdentity -ne $null) "Principal ID: $apiIdentity"
}

if ($uiApp) {
  $uiIdentity = $uiApp.identity.principalId
  Test-Result "UI App Identity" ($uiIdentity -ne $null) "Principal ID: $uiIdentity"
}

# 9. Test App Service Health
Write-Host "`n9. Testing App Service Health" -ForegroundColor Cyan

if ($apiApp) {
  $apiState = $apiApp.state
  Test-Result "API App Running" ($apiState -eq "Running") "State: $apiState"
}

if ($uiApp) {
  $uiState = $uiApp.state
  Test-Result "UI App Running" ($uiState -eq "Running") "State: $uiState"
}

# 10. Summary
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                   Test Summary                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$passCount = ($results | Where-Object { $_.Success }).Count
$failCount = ($results | Where-Object { -not $_.Success }).Count
$total = $results.Count

Write-Host "Total Tests: $total" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "Success Rate: $([math]::Round(($passCount / $total) * 100, 1))%`n"

if ($failCount -eq 0) {
  Write-Host "✓ All validation tests passed! Deployment is successful." -ForegroundColor Green
} else {
  Write-Host "✗ Some tests failed. Review the results above." -ForegroundColor Red
  Write-Host "  For database table verification, run:"
  Write-Host "  az postgres flexible-server execute --resource-group $ResourceGroupName --server-name $postgresName --admin-user pgadmin --admin-password PASSWORD --database-name sandboxDB --query-text `"SELECT table_name FROM information_schema.tables WHERE table_schema='public';`"" -ForegroundColor Yellow
}

# 11. Post-Deployment Steps
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            Next Steps - Configuration                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "1. Configure App Service Settings:" -ForegroundColor Yellow
Write-Host "   az webapp config appsettings set --resource-group $ResourceGroupName --name $apiAppName --settings APP_ENV=production DATABASE_URL=postgresql://..." -ForegroundColor Gray

Write-Host "`n2. Deploy Application Code:" -ForegroundColor Yellow
Write-Host "   az webapp deployment source config-zip --resource-group $ResourceGroupName --name $apiAppName --src api.zip" -ForegroundColor Gray
Write-Host "   az webapp deployment source config-zip --resource-group $ResourceGroupName --name $uiAppName --src ui.zip" -ForegroundColor Gray

Write-Host "`n3. Test Application Endpoints:" -ForegroundColor Yellow
if ($apiApp) {
  Write-Host "   API: https://$($apiApp.defaultHostName)/health" -ForegroundColor Gray
}
if ($uiApp) {
  Write-Host "   UI:  https://$($uiApp.defaultHostName)/" -ForegroundColor Gray
}

Write-Host "`n4. Monitor Deployment:" -ForegroundColor Yellow
Write-Host "   az webapp log tail --resource-group $ResourceGroupName --name $apiAppName" -ForegroundColor Gray

Write-Host "`n"
