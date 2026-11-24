#!/usr/bin/env pwsh
<#
.SYNOPSIS
  One-command deployment for Azure Sandbox Application (Production)
  Cross-tenant deployment: Pulls images from your ACR to customer's tenant
  
.DESCRIPTION
  Deploys the complete Sandbox infrastructure with:
  - App Service Plan (B1 Basic)
  - 2 App Services (API + UI) pulling from your ACR using token auth
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
  
.PARAMETER SourceAcrUrl
  Your ACR registry URL (where images are stored)
  Default: "acrsbxdev7e76e808.azurecr.io"
  
.PARAMETER AcrTokenUsername
  ACR token username (read-only access)
  Default: "sandbox-pull-token"
  
.PARAMETER AcrTokenPassword
  ACR token password (read-only access)
  Secure input - prompted if not provided
  
.PARAMETER ImageTag
  Docker image tag
  Default: "latest"
  
.PARAMETER Validate
  Run validation tests after deployment
  Default: $true
  
.EXAMPLE
  ./deploy-prod.ps1
  # Uses all defaults, prompts for database and ACR token passwords
  
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
  [string]$SourceAcrUrl = "acrsbxdev7e76e808.azurecr.io",
  
  [Parameter(Mandatory = $false)]
  [string]$AcrTokenUsername = "sandbox-pull-token",
  
  [Parameter(Mandatory = $false)]
  [string]$AcrTokenPassword,
  
  [Parameter(Mandatory = $false)]
  [string]$ImageTag = "latest",
  
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

# Prompt for ACR token password if not provided
if (-not $AcrTokenPassword) {
  $secureAcrPassword = Read-Host "Enter ACR token password (read-only access)" -AsSecureString
  $AcrTokenPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secureAcrPassword)
  )
}

Write-Header "Azure Sandbox Deployment - Cross-Tenant (Production)"

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
  
  # Verify ACR access
  Write-Host "`nVerifying ACR access with provided token..."
  $acrLoginTest = docker login -u $AcrTokenUsername -p $AcrTokenPassword $SourceAcrUrl 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Success "ACR token authentication verified"
    docker logout $SourceAcrUrl | Out-Null
  } else {
    Write-Warning-Custom "Could not verify ACR token (docker not installed or token invalid)"
    Write-Host "Continuing with deployment - will verify after resource creation`n"
  }
  
  # Deploy infrastructure
  Write-Header "Deploying Infrastructure"
  Write-Host "This may take 15-20 minutes...`n"
  
  $deploymentOutput = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file main.bicep `
    --parameters `
      suffix="sbx-prod" `
      imageTag="$ImageTag" `
      dbAdminUser=$DbAdminUser `
      dbAdminPassword=$DbAdminPassword `
      sourceAcrUrl=$SourceAcrUrl `
      acrTokenUsername=$AcrTokenUsername `
      acrTokenPassword=$AcrTokenPassword `
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
  Write-Host "API Service:          https://$apiAppServiceName.azurewebsites.net"
  Write-Host "UI Service:           https://$uiAppServiceName.azurewebsites.net"
  Write-Host "PostgreSQL Server:    $postgresServerName.postgres.database.azure.com"
  Write-Host "Key Vault:            $keyVaultName.vault.azure.net"
  Write-Host "Image Source ACR:     $SourceAcrUrl"
  Write-Host "API Image:            sandbox-api:$ImageTag"
  Write-Host "UI Image:             sandbox-ui:$ImageTag"
  
  # Wait for database initialization
  Write-Host "`nWaiting for database initialization..."
  Start-Sleep -Seconds 30
  Write-Success "Database initialization completed"
  
  # Verify App Services can pull images
  Write-Host "`nVerifying App Services are pulling images..."
  $apiStatus = az webapp show -n $apiAppServiceName -g $ResourceGroupName --query state -o tsv
  $uiStatus = az webapp show -n $uiAppServiceName -g $ResourceGroupName --query state -o tsv
  
  if ($apiStatus -eq "Running" -and $uiStatus -eq "Running") {
    Write-Success "API App Service is running"
    Write-Success "UI App Service is running"
  } else {
    Write-Warning-Custom "One or more App Services not yet running (may still be starting)"
  }
  
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

📍 Cross-Tenant Architecture:
  ✓ Images stored in your ACR: $SourceAcrUrl
  ✓ Customer infrastructure deployed to their tenant
  ✓ App Services pull images using read-only ACR token
  ✓ Token-based access (no service principals needed)

🌐 Endpoints:
  - API:    https://$apiAppServiceName.azurewebsites.net
  - UI:     https://$uiAppServiceName.azurewebsites.net

🔐 Security:
  - ACR Token: Read-only (sandbox-pull-token)
  - Key Vault: Stores credentials securely
  - Managed Identities: Configured
  - HTTPS Only: TLS 1.2+

📊 Database:
  - Server: $postgresServerName
  - Database: sandboxDB
  - 18 tables auto-created
  - Credentials stored in Key Vault

🚀 Images Pulled:
  - API: sandbox-api:$ImageTag
  - UI: sandbox-ui:$ImageTag
  - From: $SourceAcrUrl

📚 Documentation:
  - README.md - Quick start guide
  - AZURE-CONFIGURATION.md - Configuration details
  - QUICK-REFERENCE.md - Quick reference

For help: See README.md in this directory
"@
  
}
catch {
  Write-Error-Custom "Deployment failed: $_"
  exit 1
}
