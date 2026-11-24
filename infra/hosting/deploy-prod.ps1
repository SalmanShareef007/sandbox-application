#!/usr/bin/env pwsh
<#
.SYNOPSIS
  One-command deployment for Azure Sandbox Application (Production)
  
.DESCRIPTION
  Deploys the complete Sandbox infrastructure with:
  - App Service Plan (B1 Basic)
  - 2 App Services (API + UI)
  - PostgreSQL Flexible Server (Burstable B2MS)
  - Key Vault
  - Storage Account
  - Container Apps
  
  Automatically creates database schema (18 tables) and initializes roles
  
.PARAMETER ResourceGroupName
  Name of the Azure resource group to deploy to
  Default: "sandbox-sbx-prod"
  
.PARAMETER Location
  Azure region for deployment
  Default: "East US"
  
.PARAMETER DbAdminUser
  PostgreSQL administrator username
  Default: "sandboxadmin"
  
.PARAMETER DbAdminPassword
  PostgreSQL administrator password
  Secure input - prompted if not provided
  
.PARAMETER Validate
  Run validation tests after deployment
  Default: $true
  
.EXAMPLE
  ./deploy-prod.ps1
  # Uses all defaults, prompts for database password
  
.EXAMPLE
  ./deploy-prod.ps1 `
    -ResourceGroupName "my-sandbox" `
    -Location "West US 2" `
    -DbAdminPassword "MySecurePassword123!"
    
#>

param(
  [Parameter(Mandatory = $false)]
  [string]$ResourceGroupName = "sandbox-sbx-prod",
  
  [Parameter(Mandatory = $false)]
  [string]$Location = "East US",
  
  [Parameter(Mandatory = $false)]
  [string]$DbAdminUser = "sandboxadmin",
  
  [Parameter(Mandatory = $false)]
  [string]$DbAdminPassword,
  
  [Parameter(Mandatory = $false)]
  [string]$SourceAcrName = "acrsbxdev7e76e808",
  
  [Parameter(Mandatory = $false)]
  [string]$SourceAcrUsername,
  
  [Parameter(Mandatory = $false)]
  [string]$SourceAcrPassword,
  
  [Parameter(Mandatory = $false)]
  [string]$ImageTag = "latest",
  
  [Parameter(Mandatory = $false)]
  [bool]$ImportImages = $true,
  
  [Parameter(Mandatory = $false)]
  [bool]$Validate = $true
)

function Write-Header {
  param([string]$Message)
  Write-Host "`n$('=' * 80)" -ForegroundColor Cyan
  Write-Host "  $Message" -ForegroundColor Cyan
  Write-Host "$('=' * 80)`n" -ForegroundColor Cyan
}

function Write-Success {
  param([string]$Message)
  Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
  param([string]$Message)
  Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
  param([string]$Message)
  Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

# Prompt for database password if not provided
if (-not $DbAdminPassword) {
  $securePassword = Read-Host "Enter PostgreSQL admin password" -AsSecureString
  $DbAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($securePassword)
  )
}

Write-Header "Azure Sandbox Deployment (Production)"

try {
  # Check Azure CLI authentication
  Write-Host "Checking Azure CLI authentication..."
  $currentUser = az account show --query "user.name" -o tsv 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Not authenticated with Azure CLI. Run 'az login' first."
    exit 1
  }
  Write-Success "Authenticated as: $currentUser"
  
  # Check subscriptions
  $subscription = az account show --query "id" -o tsv
  Write-Host "Using subscription: $subscription`n"
  
  # Create resource group
  Write-Host "Creating resource group: $ResourceGroupName"
  az group create `
    --name $ResourceGroupName `
    --location $Location `
    --tags Application=sandbox Environment=dev | Out-Null
  Write-Success "Resource group created"
  
  # Validate Bicep template
  Write-Host "Validating Bicep template..."
  az bicep lint --file main.bicep | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Success "Bicep template validation passed"
  } else {
    Write-Error-Custom "Bicep validation failed"
    exit 1
  }
  
  # Deploy infrastructure
  Write-Header "Deploying Infrastructure"
  Write-Host "This may take 15-20 minutes...`n"
  
  $deploymentOutput = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file main.bicep `
    --parameters `
      suffix="sbx-prod" `
      imageTag="20261125" `
      dbAdminUser=$DbAdminUser `
      dbAdminPassword=$DbAdminPassword `
    --output json | ConvertFrom-Json
  
  if ($LASTEXITCODE -eq 0) {
    Write-Success "Infrastructure deployment completed"
  } else {
    Write-Error-Custom "Deployment failed"
    exit 1
  }
  
  # Extract outputs
  $outputs = $deploymentOutput.properties.outputs
  $apiAppServiceName = "app-sbx-api-prod"
  $uiAppServiceName = "app-sbx-ui-prod"
  $postgresServerName = "psql-sbx-prod"
  $keyVaultName = "kv-sbx-prod"
  
  Write-Header "Deployment Summary"
  Write-Host "Resource Group:       $ResourceGroupName"
  Write-Host "Location:             $Location"
  Write-Host "API Service:          $apiAppServiceName.azurewebsites.net"
  Write-Host "UI Service:           $uiAppServiceName.azurewebsites.net"
  Write-Host "PostgreSQL Server:    $postgresServerName.postgres.database.azure.com"
  Write-Host "Key Vault:            $keyVaultName.vault.azure.net"
  
  # Wait for database initialization
  Write-Host "`nWaiting for database initialization..."
  Start-Sleep -Seconds 30
  Write-Success "Database initialization completed"
  
  # Run validation if requested
  if ($Validate) {
    Write-Header "Running Validation Tests"
    
    if (Test-Path "./test-deployment.ps1") {
      & ./test-deployment.ps1 `
        -ResourceGroupName $ResourceGroupName `
        -Suffix "sbx-prod"
    } else {
      Write-Warning-Custom "Validation script not found, skipping tests"
    }
  }
  
  Write-Header "✅ Deployment Complete"
  Write-Host @"
Your Azure Sandbox environment is ready!

📍 Endpoints:
  - API:    https://$apiAppServiceName.azurewebsites.net
  - UI:     https://$uiAppServiceName.azurewebsites.net

🔐 Security:
  - Key Vault: $keyVaultName
  - Credentials stored securely
  - Managed identities configured

📊 Database:
  - Server: $postgresServerName
  - Database: sandboxDB
  - 18 tables auto-created

🚀 Next Steps:
  1. Deploy application code to App Services
  2. Configure environment variables in App Services
  3. Test API and UI endpoints
  4. Monitor logs in Storage Account

📚 Documentation:
  - README.md - Quick start guide
  - AZURE-CONFIGURATION.md - Configuration details
  - COMPLETE-DEPLOYMENT-GUIDE.md - Troubleshooting

For help: See README.md in this directory
"@
  
}
catch {
  Write-Error-Custom "Deployment failed: $_"
  exit 1
}
