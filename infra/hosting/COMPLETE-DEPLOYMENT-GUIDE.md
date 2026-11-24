# Complete Sandbox Deployment Guide

## Overview

This guide provides end-to-end deployment instructions for the Sandbox application infrastructure on Azure. The deployment is fully automated using Bicep Infrastructure as Code (IaC) and includes:

- ✅ 2 App Services (API + UI) with correct runtimes
- ✅ PostgreSQL Flexible Server with automatic schema initialization
- ✅ Container Registry for image storage
- ✅ Key Vault for secrets management
- ✅ Container Apps environment
- ✅ Storage Account for logs
- ✅ Managed Identities with RBAC

## Prerequisites

Before starting, ensure you have:

1. **Azure Subscription**
   - Owner or Contributor role
   - Enough quota for all resources (see Quota Requirements)

2. **Tools Installation**
   - [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.50+)
   - [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (included with Azure CLI 2.50+)
   - PowerShell 5.1 or PowerShell Core 7+
   - Git (for cloning repository)

3. **Container Images** - Pre-built and pushed to your ACR:
   ```
   - sandbox-api:latest          (Python 3.14 backend)
   - sandbox-ui:latest           (Node.js 24 frontend)
   - sandbox-worker:latest       (Optional: background worker)
   ```

## Quick Start (5 minutes)

### Step 1: Prepare Deployment Parameters

Create a file named `parameters.json` in the deployment directory:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "suffix": {
      "value": "prod8513"
    },
    "imageTag": {
      "value": "20261124"
    },
    "dbAdminUser": {
      "value": "pgadmin"
    },
    "dbAdminPassword": {
      "value": "YourSecurePassword123!@#"
    },
    "minReplicas": {
      "value": 1
    },
    "maxReplicas": {
      "value": 3
    }
  }
}
```

**Parameter Reference:**
- **suffix**: Unique 3-8 character suffix for all resource names (lowercase alphanumeric)
- **imageTag**: Docker image tag (timestamp format recommended: yyyyMMddHHmmss)
- **dbAdminUser**: PostgreSQL admin username
- **dbAdminPassword**: PostgreSQL admin password (must be complex: 8+ chars, uppercase, lowercase, digit, special char)
- **minReplicas**: Minimum replicas for Container Apps (1-30)
- **maxReplicas**: Maximum replicas for Container Apps (1-30)

### Step 2: Create Resource Group

```powershell
$resourceGroupName = "sandbox-prod8513"
$location = "East US"

az group create `
  --name $resourceGroupName `
  --location $location
```

**Recommended Locations:**
- `East US` - Lower costs, good availability
- `West US 2` - West coast data residency
- `North Europe` - Europe data residency

### Step 3: Deploy Infrastructure

```powershell
cd infra/hosting

# Validate the deployment first
az deployment group validate `
  --resource-group $resourceGroupName `
  --template-file main.bicep `
  --parameters parameters.json

# Execute the deployment (this takes 15-20 minutes)
az deployment group create `
  --resource-group $resourceGroupName `
  --template-file main.bicep `
  --parameters parameters.json
```

### Step 4: Verify Deployment

```powershell
# Verify all resources were created
az resource list --resource-group $resourceGroupName --output table

# Check database initialization status
az deployment group show `
  --resource-group $resourceGroupName `
  --name myDeployment `
  --query properties.outputs
```

## Detailed Deployment Steps

### Understanding the Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Resources                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │          App Service Plan (P1V2 Linux)          │   │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │  API App Service (Python 3.14)             │  │   │
│  │  │  - Port: 8000                              │  │   │
│  │  │  - Runtime: python|3.14                    │  │   │
│  │  │  - Managed Identity: System-Assigned       │  │   │
│  │  └────────────────────────────────────────────┘  │   │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │  UI App Service (Node.js 24)               │  │   │
│  │  │  - Runtime: node|24-lts                    │  │   │
│  │  │  - Managed Identity: System-Assigned       │  │   │
│  │  └────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                           ↓                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │      PostgreSQL Flexible Server                 │   │
│  │  - Database: sandboxDB                          │   │
│  │  - 18 Tables (auto-created)                     │   │
│  │  - Admin User: pgadmin                          │   │
│  │  - Public Access: Restricted                    │   │
│  └──────────────────────────────────────────────────┘   │
│                           ↓                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │      Key Vault                                  │   │
│  │  - Secrets: DB credentials                     │   │
│  │  - Access: via Managed Identities               │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Container Registry (Optional: for future)      │   │
│  │  - Images: sandbox-api, sandbox-ui              │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Container Apps Environment                     │   │
│  │  - For background workers                       │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Storage Account                                │   │
│  │  - Application logs                             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Module Descriptions

#### 1. app-service.bicep
**Purpose**: Deploy 2 App Services (API + UI) with shared App Service Plan
**Key Features**:
- Single P1V2 Linux App Service Plan (cost-optimized)
- API App Service (Python 3.14)
  - Startup command: Gunicorn with Uvicorn workers
  - Port: 8000
- UI App Service (Node.js 24-lts)
  - Startup command: npm start
  - Serves as static/SPA frontend
- Both have system-assigned managed identities
- HTTPS only, TLS 1.2 minimum
- Always On enabled (no cold starts)

#### 2. key-vault.bicep
**Purpose**: Secure secrets storage and access control
**Secrets Stored**:
- `db-admin-username`: PostgreSQL admin user
- `db-admin-password`: PostgreSQL admin password
**Access Policies**:
- API App Service: Get + List secrets
- UI App Service: Get + List secrets
**Security Features**:
- Soft delete enabled (7-day retention)
- Standard SKU (cost-effective)
- Requires managed identity for access

#### 3. database-init.bicep
**Purpose**: Automatically create database schema on first deployment
**What It Does**:
1. Installs PostgreSQL client tools (psql)
2. Executes complete schema.sql (18 tables)
3. Seeds default roles: Admin, User
4. Verifies table creation
5. Returns initialization status

**Tables Created**:
- Core: platform_mutex, platform_records, reference_counters
- Users: users, roles, user_roles
- Requests: sandbox_requests, decommission_requests, extension_requests
- Sandboxes: sandboxes, sandbox_history
- Operations: terraform_jobs, terraform_logs
- Other: audit_logs, notifications, request_history, approvals

**Idempotent**: Safe to re-run; uses IF NOT EXISTS for all tables

#### 4. main.bicep
**Purpose**: Orchestrates all modules and resource creation
**Deployment Order**:
1. Create managed identities
2. Create storage account
3. Create PostgreSQL server (runs first)
4. Initialize database schema (waits for PostgreSQL)
5. Create Container Apps environment
6. Create Container Registry
7. Create App Service Plan + App Services
8. Create Key Vault
9. Configure RBAC and access policies

## Environment Variables Configuration

After deployment, configure these environment variables in your App Services:

### For API App Service

```json
{
  "APP_ENV": "production",
  "DEBUG": "false",
  "WEBSITES_PORT": "8000",
  "DATABASE_URL": "postgresql://pgadmin:PASSWORD@psql-prod8513.postgres.database.azure.com:5432/sandboxDB?sslmode=require",
  "KEY_VAULT_URL": "https://kvprod8513.vault.azure.net/",
  "ALLOW_OWNER_ROLE_REQUESTS": "true",
  "CORS_ORIGINS": "[\"https://app-ui-prod8513.azurewebsites.net\"]"
}
```

### For UI App Service

```json
{
  "REACT_APP_API_URL": "https://app-api-prod8513.azurewebsites.net",
  "REACT_APP_ENV": "production",
  "WEBSITES_ENABLE_APP_SERVICE_STORAGE": "false"
}
```

## Troubleshooting

### Database Connection Issues

**Error**: "FATAL: Ident authentication failed"
```
Solution: PostgreSQL public access is restricted. Ensure App Service has correct firewall rules.
Run: az postgres flexible-server firewall-rule list --resource-group RESOURCE_GROUP --server-name psql-SUFFIX
```

**Error**: "Database sandboxDB does not exist"
```
Solution: Database initialization script didn't run. Check deployment script status:
Run: az deployment group show --resource-group RG --name db-init-* --query properties.outputs
```

### App Service Connection Issues

**Error**: "502 Bad Gateway"
```
Possible causes:
1. Application crashed - check App Service logs
2. Database credentials wrong - verify CONNECTION_STRING
3. Port mismatch - should be 8000 for Python app
Run: az webapp log tail --resource-group RG --name app-api-SUFFIX
```

**Error**: "Cannot connect to Key Vault"
```
Solution: Managed identity doesn't have access. Re-deploy key-vault module or manually add access policy:
az keyvault set-policy --name kv-SUFFIX --object-id PRINCIPAL_ID --secret-permissions get list
```

### Deployment Script Failures

**Error**: "psql: command not found"
```
Solution: PostgreSQL client wasn't installed properly. The deployment script should handle this via Chocolatey.
Alternative: Run schema.sql manually from your local machine:
psql -h psql-SUFFIX.postgres.database.azure.com -U pgadmin -d sandboxDB -f schema.sql
```

## Post-Deployment Tasks

### 1. Verify All Resources

```powershell
# Check resource creation
az resource list --resource-group "sandbox-prod8513" --output table

# Verify database tables
$serverName = "psql-prod8513"
$dbName = "sandboxDB"
az postgres flexible-server execute --resource-group "sandbox-prod8513" --server-name $serverName --admin-user "pgadmin" --admin-password "PASSWORD" --database-name $dbName --query-text "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"
```

### 2. Configure Application Settings

For each App Service:
```powershell
# Update API App Service
az webapp config appsettings set `
  --resource-group "sandbox-prod8513" `
  --name "app-api-prod8513" `
  --settings `
    APP_ENV=production `
    DEBUG=false `
    DATABASE_URL="postgresql://pgadmin:PASSWORD@psql-prod8513.postgres.database.azure.com:5432/sandboxDB?sslmode=require"

# Update UI App Service
az webapp config appsettings set `
  --resource-group "sandbox-prod8513" `
  --name "app-ui-prod8513" `
  --settings `
    REACT_APP_API_URL="https://app-api-prod8513.azurewebsites.net"
```

### 3. Deploy Application Code

```powershell
# Deploy API (Python app)
az webapp deployment source config-zip `
  --resource-group "sandbox-prod8513" `
  --name "app-api-prod8513" `
  --src "path/to/api.zip"

# Deploy UI (Node.js app)
az webapp deployment source config-zip `
  --resource-group "sandbox-prod8513" `
  --name "app-ui-prod8513" `
  --src "path/to/ui.zip"
```

### 4. Test Endpoints

```bash
# Test API health
curl https://app-api-prod8513.azurewebsites.net/health

# Test UI
curl https://app-ui-prod8513.azurewebsites.net/

# Test database connection (from API logs)
az webapp log tail --resource-group "sandbox-prod8513" --name "app-api-prod8513"
```

## Quota Requirements

Ensure your subscription has sufficient quota:

| Resource | Required | Default Limit | Status |
|----------|----------|--------------|--------|
| App Service Plans | 1 | 100 | ✓ OK |
| App Services | 2 | 100 | ✓ OK |
| PostgreSQL Flexible Servers | 1 | 20 | Check if needed |
| Container Registries | 1 | 10 | ✓ OK |
| Container App Environments | 1 | 10 | ✓ OK |
| Key Vaults | 1 | 25 | ✓ OK |
| Storage Accounts | 1 | 100 | ✓ OK |

**Check Quotas:**
```powershell
az vm list-usage --location "East US" --query "[?contains(localName, 'App Service')]" -o table
```

## Cost Estimation

Monthly estimated costs (East US region):

| Resource | Type | Quantity | Cost |
|----------|------|----------|------|
| App Service Plan | P1V2 | 1 | $160/month |
| PostgreSQL | Flexible Server | 1 | $80-150/month |
| Container Registry | Standard | 1 | $10/month |
| Key Vault | Standard | 1 | $0.60/month |
| Storage Account | General Purpose | 1 | $0.50-5/month |
| Container Apps | Minimal (1 replica) | 1 | $5-10/month |
| **Total** | | | **$256-336/month** |

**Cost Optimization Tips:**
- Use B2 App Service Plan for dev/test ($18/month instead of $160)
- Use Burstable PostgreSQL SKU ($40/month instead of $80+)
- Use Zone-redundant PostgreSQL for production (+50% cost but high availability)

## Security Best Practices

✓ **Implemented in This Solution**:
- System-assigned managed identities (no secrets in code)
- Key Vault for password storage
- PostgreSQL public access restricted
- HTTPS only for App Services
- TLS 1.2 minimum
- Soft delete on Key Vault

**Additional Recommendations**:
- [ ] Enable Azure Policy for resource compliance
- [ ] Configure Azure Defender for SQL
- [ ] Enable diagnostic logging to Application Insights
- [ ] Set up network isolation (VNet, Private Endpoints)
- [ ] Implement WAF for App Services
- [ ] Regular backup for PostgreSQL (automated)
- [ ] Rotate database passwords quarterly

## Support & Documentation

**Useful References**:
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [App Service Overview](https://learn.microsoft.com/en-us/azure/app-service/overview)
- [PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)

**Getting Help**:
- Check deployment script output for specific error messages
- Review Azure Activity Log for API-level errors
- Inspect Application Insights for runtime diagnostics
- Contact Azure Support for quota or account issues

---

**Last Updated**: 2026-11-24  
**Version**: 1.0.0  
**Deployment Tool**: Azure Bicep
