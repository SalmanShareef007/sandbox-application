# 🚀 Sandbox Application - Complete Azure Deployment Package

> **One-command deployment of the entire Sandbox infrastructure to Azure with automatic database initialization**

## 📋 What's Included

This deployment package automates the creation of a production-ready Sandbox application infrastructure on Azure:

✅ **2 App Services** (API + UI)
- API: Python 3.14 backend running on port 8000
- UI: Node.js 24-lts frontend
- Shared P1V2 Linux App Service Plan (cost-optimized)
- System-assigned managed identities for secure access
- HTTPS only, TLS 1.2 minimum

✅ **PostgreSQL Flexible Server**
- Database: `sandboxDB` (automatically created)
- 18 tables with full schema
- 10 default roles seeded
- Automatic initialization on deployment

✅ **Azure Key Vault**
- Stores database credentials securely
- Grants access via managed identities
- Soft delete enabled

✅ **Container Registry** (optional)
- For storing Docker images

✅ **Container Apps Environment**
- For background workers

✅ **Storage Account**
- Application logs and diagnostics

✅ **Managed Identities & RBAC**
- Secure, passwordless authentication
- Zero secrets in code

## 🎯 Key Features

- **Completely Automated**: One Bicep deployment creates everything
- **Database Auto-Init**: Tables created automatically on first deployment
- **Production-Ready**: HTTPS, TLS 1.2, managed identities, Key Vault integration
- **Cost-Optimized**: Shared App Service Plan, appropriate SKUs for each service
- **Idempotent**: Safe to re-run without deleting existing data
- **Fully Documented**: Complete deployment guide and troubleshooting

## 📁 File Structure

```
infra/hosting/
├── main.bicep                           # Main orchestration template
├── modules/
│   ├── app-service.bicep               # API + UI App Services
│   ├── key-vault.bicep                 # Secrets management
│   ├── database-init.bicep             # Database schema setup
│   ├── postgresql.bicep                # PostgreSQL server
│   ├── container-apps.bicep            # Container Apps environment
│   ├── acr.bicep                       # Container Registry
│   ├── storage.bicep                   # Storage account
│   ├── managed-identity.bicep          # Managed identities
│   ├── container-apps-environment.bicep # Container Apps networking
│   └── role-assignments.bicep          # RBAC configuration
├── parameters.json                      # Deployment parameters template
├── COMPLETE-DEPLOYMENT-GUIDE.md        # Detailed deployment instructions
├── test-deployment.ps1                 # Validation script
├── deploy.ps1                          # Deployment execution script
└── deploy-one-flow.ps1                 # One-command deployment orchestrator
```

## ⚡ Quick Start (5 Minutes)

### Prerequisites
- Azure CLI 2.50+ installed ([download](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli))
- PowerShell 5.1 or PowerShell Core 7+
- Logged into Azure: `az login`

### Step 1: Create Parameters File

Create `parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "suffix": { "value": "prod8513" },
    "imageTag": { "value": "20261124" },
    "dbAdminUser": { "value": "pgadmin" },
    "dbAdminPassword": { "value": "YourSecurePassword123!@#" }
  }
}
```

### Step 2: Deploy

```powershell
cd infra/hosting

# Option A: One-command deployment
./deploy-one-flow.ps1 -ResourceGroupName "sandbox-prod8513" -Location "East US"

# Option B: Manual deployment
az group create --name "sandbox-prod8513" --location "East US"

az deployment group create `
  --resource-group "sandbox-prod8513" `
  --template-file main.bicep `
  --parameters parameters.json
```

### Step 3: Verify

```powershell
./test-deployment.ps1 -ResourceGroupName "sandbox-prod8513" -Suffix "prod8513"
```

**That's it!** Your infrastructure is ready. Next:
1. Deploy your application code
2. Configure environment variables
3. Test endpoints

See [COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md) for detailed instructions.

## 🔧 Configuration

### Environment Variables - API App Service

Required variables that must be set after deployment:

```env
# Database
DATABASE_URL=postgresql://pgadmin:PASSWORD@psql-prod8513.postgres.database.azure.com:5432/sandboxDB?sslmode=require

# Key Vault
KEY_VAULT_URL=https://kvprod8513.vault.azure.net/

# Application
APP_ENV=production
DEBUG=false
WEBSITES_PORT=8000

# CORS
CORS_ORIGINS=["https://app-ui-prod8513.azurewebsites.net"]

# Optional: Entra ID Integration
ENTRA_CLIENT_ID=your-client-id
ENTRA_TENANT_ID=your-tenant-id
ENTRA_REQUIRED_SCOPE=access_as_user
```

### Environment Variables - UI App Service

```env
REACT_APP_API_URL=https://app-api-prod8513.azurewebsites.net
REACT_APP_ENV=production
WEBSITES_ENABLE_APP_SERVICE_STORAGE=false
```

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Azure Resources                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌────────────────────────────────────────────────┐    │
│  │      App Service Plan (P1V2 Linux)            │    │
│  ├────────────────────────────────────────────────┤    │
│  │  API (Python 3.14)      UI (Node.js 24)      │    │
│  │  Port: 8000             Frontend SPA         │    │
│  │  Managed Identity       Managed Identity     │    │
│  └────────────────────────────────────────────────┘    │
│                        ↓                               │
│  ┌────────────────────────────────────────────────┐    │
│  │   PostgreSQL Flexible Server (sandboxDB)      │    │
│  │   18 Tables + Default Roles Auto-Created      │    │
│  └────────────────────────────────────────────────┘    │
│                        ↓                               │
│  ┌────────────────────────────────────────────────┐    │
│  │  Key Vault (Secrets + Access Policies)        │    │
│  │  - DB Credentials                            │    │
│  │  - Managed Identity Access                   │    │
│  └────────────────────────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 🗄️ Database Schema

The deployment automatically creates 18 tables:

| Table | Purpose |
|-------|---------|
| **Platform** | platform_mutex, platform_records, reference_counters |
| **Users** | users, roles, user_roles |
| **Requests** | sandbox_requests, decommission_requests, extension_requests |
| **Sandboxes** | sandboxes, sandbox_history |
| **Operations** | terraform_jobs, terraform_logs |
| **Other** | audit_logs, notifications, request_history, approvals |

Default roles seeded:
- `Admin` - Manages sandbox requests and approvals
- `User` - Can request and manage assigned sandboxes

## 💰 Cost Estimation

**Monthly cost (East US region):**

| Resource | Cost |
|----------|------|
| App Service Plan (P1V2) | $160 |
| PostgreSQL Flexible Server | $80-150 |
| Container Registry (Standard) | $10 |
| Key Vault | <$1 |
| Storage Account | $1-5 |
| **Total** | **$251-326/month** |

**Cost Optimization**:
- Dev/Test: Use B2 tier App Service Plan ($18/month)
- Use Burstable PostgreSQL SKU ($40/month)
- Automate shut-down during off-hours

## 🧪 Validation & Testing

### Run Validation Script

```powershell
./test-deployment.ps1 -ResourceGroupName "sandbox-prod8513" -Suffix "prod8513"
```

Checks:
- ✓ All resources deployed
- ✓ App Services running
- ✓ PostgreSQL accessible
- ✓ Key Vault secrets stored
- ✓ Database tables created
- ✓ Managed identities configured

### Manual Verification

```powershell
# List all resources
az resource list --resource-group "sandbox-prod8513" --output table

# Check database tables
psql -h psql-prod8513.postgres.database.azure.com -U pgadmin -d sandboxDB -c "\dt"

# View app service logs
az webapp log tail --resource-group "sandbox-prod8513" --name "app-api-prod8513"

# Test API health
curl https://app-api-prod8513.azurewebsites.net/health
```

## 🛠️ Troubleshooting

### Database Connection Error

**Error**: "FATAL: Ident authentication failed"

```powershell
# Check firewall rules
az postgres flexible-server firewall-rule list `
  --resource-group "sandbox-prod8513" `
  --server-name "psql-prod8513"

# Allow App Service to connect
az postgres flexible-server firewall-rule create `
  --resource-group "sandbox-prod8513" `
  --server-name "psql-prod8513" `
  --name "AllowAppService" `
  --start-ip-address "0.0.0.0" `
  --end-ip-address "255.255.255.255"
```

### Application Crashes

```powershell
# View detailed logs
az webapp log tail --resource-group "sandbox-prod8513" --name "app-api-prod8513" --follow

# Check deployment status
az webapp deployment show-status `
  --resource-group "sandbox-prod8513" `
  --name "app-api-prod8513"
```

### Database Schema Not Created

```powershell
# Check if tables exist
psql -h psql-prod8513.postgres.database.azure.com \
  -U pgadmin \
  -d sandboxDB \
  -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public';"

# If missing, manually apply schema
psql -h psql-prod8513.postgres.database.azure.com \
  -U pgadmin \
  -d sandboxDB \
  -f Backend/schema.sql
```

See [COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md) for more troubleshooting.

## 📚 Next Steps

1. **Deploy Application Code**
   ```powershell
   az webapp deployment source config-zip `
     --resource-group "sandbox-prod8513" `
     --name "app-api-prod8513" `
     --src "api.zip"
   ```

2. **Configure Environment Variables**
   ```powershell
   az webapp config appsettings set `
     --resource-group "sandbox-prod8513" `
     --name "app-api-prod8513" `
     --settings DATABASE_URL="..." KEY_VAULT_URL="..."
   ```

3. **Enable Monitoring**
   - Application Insights integration
   - Log Analytics workspace
   - Alert rules for critical metrics

4. **Security Hardening**
   - Enable WAF on App Services
   - Set up VNet integration
   - Configure private endpoints
   - Enable Azure Defender

5. **Production Setup**
   - Configure custom domain/SSL
   - Set up backup strategies
   - Configure CDN for UI
   - Implement load balancing

## 🔐 Security

✅ **Built-In Security**:
- System-assigned managed identities (no secrets in code)
- Key Vault for password storage
- PostgreSQL public access restricted
- HTTPS only
- TLS 1.2 minimum
- Soft delete on Key Vault

**Recommended Additional Steps**:
- [ ] Enable Azure Policy for compliance
- [ ] Configure Network Security Groups
- [ ] Set up Private Endpoints
- [ ] Enable WAF
- [ ] Regular password rotation
- [ ] Enable diagnostic logging
- [ ] Implement backup strategy
- [ ] Regular security patching

## 📖 Documentation

- **[COMPLETE-DEPLOYMENT-GUIDE.md](./COMPLETE-DEPLOYMENT-GUIDE.md)** - Detailed step-by-step deployment instructions
- **[Microsoft Bicep Docs](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)** - Bicep reference
- **[Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/)** - App Service documentation
- **[PostgreSQL Flexible Server](https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/)** - Database documentation

## 🤝 Support

For issues or questions:
1. Check the [Troubleshooting section](#-troubleshooting)
2. Review deployment logs: `az deployment group show --resource-group RG --name deployment-name --query properties.outputs`
3. Check Application Insights for runtime diagnostics
4. Review Azure Activity Log for API errors

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-11-24 | Initial release - Complete infrastructure with auto DB initialization |

---

**Last Updated**: 2026-11-24  
**Status**: ✅ Production Ready  
**Maintainer**: Sandbox Platform Team


## First-Time Deployment

The first infrastructure test deploys:
- **PostgreSQL Flexible Server** (Standard_B1ms, 32GB storage)
- **Container Apps Environment** (with Log Analytics integration)
- **Storage Account** (for logs and backups)
- **Managed Identities** (API and Worker)
- **Log Analytics Workspace** (for monitoring)

### Step 1: Create Resource Group

```powershell
.\deploy.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "rg-hosting-test" `
  -Suffix "test" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "<secure-password>" `
  -Location "Central India" `
  -CreateResourceGroup
```

### Step 2: Validate & Preview

```powershell
.\deploy.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "rg-hosting-test" `
  -Suffix "test" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "<secure-password>"
```

This runs:
1. Bicep template validation
2. What-if preview of changes

### Step 3: Apply Deployment

```powershell
.\deploy.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "rg-hosting-test" `
  -Suffix "test" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "<secure-password>" `
  -Apply
```

This:
1. Validates the template
2. Shows what-if preview
3. Creates resources

### Step 4: Validate Deployment

```powershell
.\scripts/validate-deployment.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "rg-hosting-test" `
  -PostgresServerName "psql-test" `
  -ContainerAppsEnvName "cae-test" `
  -StorageAccountName "sttestlogs"
```

## Parameters

### deploy.ps1

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| SubscriptionId | Yes | string | Azure subscription ID |
| ResourceGroup | Yes | string | Resource group name |
| Suffix | Yes | string | Suffix for resource names (3-8 lowercase alphanumeric) |
| DbAdminUser | Yes | string | PostgreSQL admin username |
| DbAdminPassword | Yes | string | PostgreSQL admin password (secure) |
| Location | No | string | Azure region (default: 'Central India') |
| ImageTag | No | string | Container image tag (default: yyyyMMddHHmmss) |
| DeployerPrincipalId | No | string | Deployer's principal ID (auto-detected if omitted) |
| CreateResourceGroup | No | switch | Create resource group and exit |
| Apply | No | switch | Apply deployment (otherwise preview only) |
| Validate | No | switch | Run post-deployment validation |

## Bicep Modules

### postgresql.bicep
Deploys PostgreSQL Flexible Server with:
- Configurable SKU and storage
- Database creation
- Optional firewall rules for public access
- Backup configuration
- Connection pooling settings

**Outputs:**
- serverId, serverName, serverFqdn
- databaseName, administratorLogin
- connectionString

### container-apps.bicep
Deploys Container Apps environment with:
- Log Analytics workspace
- Container Apps managed environment
- Storage blob integration

**Outputs:**
- environmentId, environmentName
- logAnalyticsWorkspaceId, logAnalyticsCustomerId

### managed-identity.bicep
Deploys user-assigned managed identity.

**Outputs:**
- id, principalId, clientId

### storage.bicep
Deploys storage account with blob containers.

**Outputs:**
- id, name, blobEndpoint, connectionString

## Deployment Outputs

After successful deployment, outputs include:
- API and Worker managed identity IDs
- PostgreSQL server name and FQDN
- Container Apps environment details
- Storage account information

Example output:
```
API Identity Principal ID: 11111111-1111-1111-1111-111111111111
Worker Identity Principal ID: 22222222-2222-2222-2222-222222222222
PostgreSQL Server: psql-test
PostgreSQL FQDN: psql-test.postgres.database.azure.com
Container Apps Environment: cae-test
Storage Account: sttestlogs
```

## Cleanup

To delete all resources and the resource group:

```powershell
.\scripts/cleanup.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "rg-hosting-test"
```

You'll be prompted to confirm by typing 'DELETE'.

For non-interactive cleanup:

```powershell
.\scripts/cleanup.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "rg-hosting-test" `
  -Force
```

## Image Import (Future)

When container images are ready in your ACR:

```powershell
.\scripts/import-images.ps1 `
  -SourceAcrName "yourregistry" `
  -SourceAcrUsername "<username>" `
  -SourceAcrPassword "<password>" `
  -DestinationAcrName "customerregistry" `
  -ImageTag "20240101120000"
```

## Best Practices

1. **Parameter files**: Store sensitive parameters outside the repository
2. **Naming**: Follow Azure naming conventions (suffix should be 3-8 characters)
3. **Regions**: Choose regions close to your users for better latency
4. **Testing**: Always use `-CreateResourceGroup` with a test suffix first
5. **Backups**: Enable geo-redundant backups for production PostgreSQL
6. **Monitoring**: Use Log Analytics outputs to set up alerts

## Troubleshooting

### Deployment Validation Fails
```
Check Bicep syntax errors:
az bicep build --file main.bicep
```

### Cannot Connect to PostgreSQL
- Verify firewall rules if public access is enabled
- Check network connectivity from your client
- Ensure username/password are correct

### Container Apps Environment Issues
- Check Log Analytics workspace is reachable
- Verify storage account credentials
- Review Container Apps diagnostics in Azure Portal

## Security Notes

- Database passwords should be generated and stored securely (e.g., Azure Key Vault)
- PostgreSQL public access is disabled by default
- Use managed identities for all application authentication
- Storage accounts use TLS 1.2 minimum
- All resources are tagged for cost tracking and automation

## Next Steps

1. Deploy and validate the infrastructure
2. Configure PostgreSQL public access (if needed) with firewall rules
3. Set up managed identities for applications
4. Deploy Container Apps with application images
5. Configure monitoring and alerts via Log Analytics
