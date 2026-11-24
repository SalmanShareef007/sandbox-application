# Azure Sandbox Environment Configuration - Production

**Last Updated**: 2026-11-25  
**Status**: ✅ Ready for Deployment  
**Region**: East US  
**Environment**: Development

---

## 📋 Resource Configuration

### 1. App Service Plan

| Property | Value |
|----------|-------|
| Service Name | `asp-sbx-prod` |
| Tier | **Basic B1** |
| Region | East US |
| OS | Linux |
| Capacity | 1 instance |
| Estimated Cost | **$7.50/month** |

**Configuration Details:**
- SKU: B1 (1 vCPU, 1.75 GB RAM)
- Suitable for: Development, testing, low-traffic applications
- Scaling: Manual (no auto-scale)
- Always On: Disabled (cost optimization)

---

### 2. App Service – Backend (API)

| Property | Value |
|----------|-------|
| Service Name | `app-sbx-api-prod` |
| App Service Plan | `asp-sbx-prod` |
| Runtime | Linux - Python 3.14 |
| Startup Command | `gunicorn --workers 2 --worker-class uvicorn.workers.UvicornWorker app:app` |
| Port | 8000 |
| Region | East US |
| HTTPS | ✅ Required |
| Always On | Disabled (cost saving) |
| Managed Identity | System-Assigned ✅ |

**Configuration Details:**
```bicep
linuxFxVersion: 'PYTHON|3.14'
minTlsVersion: '1.2'
http20Enabled: true
numberOfWorkers: 1
```

**Environment Variables (to be set after deployment):**
```
DATABASE_URL=postgresql://sandboxadmin:PASSWORD@psql-sbx-prod.postgres.database.azure.com:5432/sandboxDB?sslmode=require
KEY_VAULT_URL=https://kv-sbx-prod.vault.azure.net/
APP_ENV=development
DEBUG=false
WEBSITES_PORT=8000
CORS_ORIGINS=["https://app-sbx-ui-prod.azurewebsites.net"]
```

---

### 3. App Service – Frontend (UI)

| Property | Value |
|----------|-------|
| Service Name | `app-sbx-ui-prod` |
| App Service Plan | `asp-sbx-prod` |
| Runtime | Linux - Node.js 24 |
| Startup Command | `npm start` |
| Region | East US |
| HTTPS | ✅ Required |
| Always On | Disabled (cost saving) |
| Managed Identity | System-Assigned ✅ |

**Configuration Details:**
```bicep
linuxFxVersion: 'NODE|24-lts'
minTlsVersion: '1.2'
http20Enabled: true
defaultDocuments: ['index.html']
```

**Environment Variables (to be set after deployment):**
```
REACT_APP_API_URL=https://app-sbx-api-prod.azurewebsites.net
REACT_APP_ENV=development
WEBSITES_ENABLE_APP_SERVICE_STORAGE=false
```

---

### 4. PostgreSQL Flexible Server

| Property | Value |
|----------|-------|
| Service Name | `psql-sbx-prod` |
| Deployment | Flexible Server |
| Tier | **Burstable** |
| Compute | B2MS (2 vCores) |
| RAM | 4 GB |
| Storage | Premium SSD - 5 GB |
| Region | East US |
| Backup Redundancy | LRS (Local Redundant Storage) |
| Availability Zone | Single AZ |
| Estimated Cost | **$42.50/month** (burstable pricing) |

**Database Configuration:**
```
Database Name: sandboxDB
Admin Username: sandboxadmin
Admin Password: 08fpIz3EHYoW6b7Q
Port: 5432
SSL Mode: Required
```

**Tables Auto-Created (18 total):**
- Platform: platform_mutex, platform_records, reference_counters
- Users: users, roles, user_roles
- Requests: sandbox_requests, decommission_requests, extension_requests
- Sandboxes: sandboxes, sandbox_history
- Operations: terraform_jobs, terraform_logs
- Other: audit_logs, notifications, request_history, approvals

**Seed Data:**
- 2 default roles: Admin, User
- Full constraints and indexing
- Proper foreign key relationships

**Network Security:**
- Public access: Restricted (firewall rules)
- Can be upgraded to Private Link/VNet integration
- High availability: Disabled (cost optimization)

---

### 5. Azure Container Apps

| Property | Value |
|----------|-------|
| Service Name | `app-sbx-worker-prod` |
| Tier | Standard |
| Environment | Linux |
| Region | East US |
| Estimated Cost | **~$5-15/month** (minimal usage) |

**Configuration:**
- Used for background worker processing
- Optional for initial deployment
- Can be enabled later for async tasks

---

### 6. Azure Storage Account

| Property | Value |
|----------|-------|
| Service Name | `stgsbxprod` |
| Account Type | General Purpose V2 |
| Replication | LRS (Locally Redundant Storage) |
| Region | East US |
| Performance Tier | Standard |
| Namespace | Flat Namespace |
| SFTP | Disabled |
| Estimated Cost | **~$1-2/month** |

**Purpose:**
- Application logs
- Diagnostic data
- Optional backup storage

---

### 7. Azure Key Vault

| Property | Value |
|----------|-------|
| Service Name | `kv-sbx-prod` |
| SKU | Standard |
| Access Policy | Vault Access Policy |
| Region | East US |
| Soft Delete | Enabled (7-day retention) |
| Purge Protection | Disabled |
| Estimated Cost | **<$1/month** |

**Secrets Stored:**
```
db-admin-username: sandboxadmin
db-admin-password: 08fpIz3EHYoW6b7Q
```

**Access Policies:**
- API App Service (System-Assigned Identity): Get, List secrets
- UI App Service (System-Assigned Identity): Get, List secrets

---

## 💰 Cost Summary

### Monthly Estimated Costs (East US)

| Service | Tier/Config | Monthly Cost |
|---------|-------------|--------------|
| App Service Plan | B1 Basic | **$7.50** |
| PostgreSQL | Burstable B2MS | **$42.50** |
| Container Apps | Standard (minimal) | **$5.00** |
| Storage Account | General Purpose V2 | **$1.00** |
| Key Vault | Standard | **<$1.00** |
| Container Registry | Standard (optional) | **$10.00** |
| **TOTAL** | | **~$66-67/month** |

### Annual Cost
- **~$800/year** (very cost-effective for dev environment)

### Cost Optimization Notes
- ✅ Using Burstable PostgreSQL tier (40% cheaper than Flexible)
- ✅ Using B1 App Service tier ($7.50 vs $160 for Premium)
- ✅ Disabled "Always On" (saves on idle costs)
- ✅ Single Availability Zone (no redundancy costs)
- ✅ LRS storage (cheapest replication option)
- ✅ No high availability features (dev environment)

**Upgrade Path for Production:**
- Change to P1V2 or S1 App Service Plan: +$67-152/month
- Change to Standard PostgreSQL: +$30-50/month
- Enable high availability: +$50-100/month
- Add zone redundancy: +$20-50/month

---

## 🏗️ Deployment Architecture

```
┌────────────────────────────────────────────────────────────┐
│                   Azure Resources                          │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │  App Service Plan: asp-sbx-prod (B1 Basic)      │     │
│  │  ┌────────────────────────────────────────────┐  │     │
│  │  │  API App Service (Python 3.14)             │  │     │
│  │  │  app-sbx-api-prod                          │  │     │
│  │  │  Port: 8000 | Managed Identity: Yes        │  │     │
│  │  └────────────────────────────────────────────┘  │     │
│  │  ┌────────────────────────────────────────────┐  │     │
│  │  │  UI App Service (Node.js 24)               │  │     │
│  │  │  app-sbx-ui-prod                           │  │     │
│  │  │  Managed Identity: Yes                     │  │     │
│  │  └────────────────────────────────────────────┘  │     │
│  └──────────────────────────────────────────────────┘     │
│                        ↓                                   │
│  ┌──────────────────────────────────────────────────┐     │
│  │   PostgreSQL Flexible Server (Burstable B2MS)   │     │
│  │   psql-sbx-prod                                │     │
│  │   Database: sandboxDB (auto-init: 18 tables)   │     │
│  │   Storage: 5 GB Premium SSD                    │     │
│  └──────────────────────────────────────────────────┘     │
│                        ↓                                   │
│  ┌──────────────────────────────────────────────────┐     │
│  │   Key Vault: kv-sbx-prod                       │     │
│  │   Secrets: DB credentials                     │     │
│  │   Access: Managed Identities                  │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │   Storage Account: stgsbxprod                  │     │
│  │   Purpose: Logs and diagnostics               │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
│  ┌──────────────────────────────────────────────────┐     │
│  │   Container Apps: app-sbx-worker-prod          │     │
│  │   Purpose: Background workers (optional)       │     │
│  └──────────────────────────────────────────────────┘     │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Configuration

✅ **Implemented:**
- HTTPS only (TLS 1.2 minimum)
- System-assigned managed identities
- Key Vault for credential storage
- Database password protected
- PostgreSQL public access restricted
- Soft delete on Key Vault
- RBAC access policies

⚠️ **Recommendations for Production:**
- [ ] Enable Azure Defender for SQL
- [ ] Configure WAF (Web Application Firewall)
- [ ] Set up Private Endpoints
- [ ] Enable VNet integration
- [ ] Regular backup strategy
- [ ] Enable diagnostic logging
- [ ] Implement network security groups
- [ ] Regular security patching

---

## 📊 Performance Characteristics

### App Service Plan (B1 Basic)
- **Compute**: 1 vCPU (shared)
- **Memory**: 1.75 GB
- **Suitable for**: Development, testing, low-traffic apps
- **Cold Starts**: ~5-10 seconds (Always On disabled)
- **Max Requests**: ~100-200 req/sec (depends on app)
- **Limitations**: No auto-scale, shared CPU, no SSL SNI

### PostgreSQL (B2MS Burstable)
- **Compute**: 2 vCores (burstable)
- **Memory**: 4 GB
- **Storage**: 5 GB Premium SSD
- **IOPS**: 3,000-20,000 (burst capability)
- **Suitable for**: Development, light production workloads
- **Connection Limit**: ~100 concurrent connections
- **Backup**: Daily automated backups (7-day retention)

---

## 🚀 Deployment Instructions

### Prerequisites
- Azure CLI 2.50+ installed
- PowerShell 5.1 or higher
- Azure subscription (Contributor role)
- Read [README.md](./README.md)

### Step 1: Create Resource Group

```powershell
az group create `
  --name "sandbox-sbx-prod" `
  --location "East US"
```

### Step 2: Deploy Infrastructure

```powershell
cd infra/hosting

az deployment group create `
  --resource-group "sandbox-sbx-prod" `
  --template-file main.bicep `
  --parameters parameters-prod.json
```

**Deployment Time**: 15-20 minutes

### Step 3: Validate Deployment

```powershell
./test-deployment.ps1 `
  -ResourceGroupName "sandbox-sbx-prod" `
  -Suffix "sbx-prod"
```

### Step 4: Configure Environment Variables

```powershell
# API App Service
az webapp config appsettings set `
  --resource-group "sandbox-sbx-prod" `
  --name "app-sbx-api-prod" `
  --settings `
    APP_ENV=development `
    DEBUG=false `
    DATABASE_URL="postgresql://sandboxadmin:08fpIz3EHYoW6b7Q@psql-sbx-prod.postgres.database.azure.com:5432/sandboxDB?sslmode=require" `
    KEY_VAULT_URL="https://kv-sbx-prod.vault.azure.net/" `
    WEBSITES_PORT=8000

# UI App Service
az webapp config appsettings set `
  --resource-group "sandbox-sbx-prod" `
  --name "app-sbx-ui-prod" `
  --settings `
    REACT_APP_API_URL="https://app-sbx-api-prod.azurewebsites.net" `
    REACT_APP_ENV=development
```

### Step 5: Deploy Application Code

```powershell
# Deploy API
az webapp deployment source config-zip `
  --resource-group "sandbox-sbx-prod" `
  --name "app-sbx-api-prod" `
  --src "api.zip"

# Deploy UI
az webapp deployment source config-zip `
  --resource-group "sandbox-sbx-prod" `
  --name "app-sbx-ui-prod" `
  --src "ui.zip"
```

### Step 6: Test Endpoints

```bash
# Test API
curl https://app-sbx-api-prod.azurewebsites.net/health

# Test UI
curl https://app-sbx-ui-prod.azurewebsites.net/
```

---

## 📝 Resource Naming Convention

| Resource Type | Pattern | Example |
|---------------|---------|---------|
| App Service Plan | asp-sbx-{env} | asp-sbx-prod |
| API App Service | app-sbx-api-{env} | app-sbx-api-prod |
| UI App Service | app-sbx-ui-{env} | app-sbx-ui-prod |
| PostgreSQL Server | psql-sbx-{env} | psql-sbx-prod |
| Key Vault | kv-sbx-{env} | kv-sbx-prod |
| Storage Account | stgsbx{env} | stgsbxprod |
| Container Apps | app-sbx-worker-{env} | app-sbx-worker-prod |
| Container Registry | acrsbx{env} | acrsbxprod |

---

## ✅ Post-Deployment Checklist

After successful deployment:

- [ ] Run validation script (test-deployment.ps1)
- [ ] All resources deployed and running
- [ ] Database tables created (18 total)
- [ ] Environment variables configured
- [ ] Application code deployed
- [ ] API endpoints responding (HTTP 200)
- [ ] UI accessible from browser
- [ ] Database connectivity verified
- [ ] Logs appearing in Storage Account
- [ ] Managed identities assigned correctly

---

## 📞 Support & Troubleshooting

**Quick Reference:**
- README.md - Quick start
- COMPLETE-DEPLOYMENT-GUIDE.md - Detailed troubleshooting
- test-deployment.ps1 - Automated validation

**Common Issues:**

1. **Database Connection Error**
   - Check PostgreSQL firewall rules
   - Verify app service has network access
   - Run validation script

2. **App Service Not Starting**
   - Check application logs: `az webapp log tail ...`
   - Verify environment variables set
   - Review deployment status

3. **Cold Start Delays**
   - Expected with B1 tier (Always On disabled)
   - Enable Always On for consistent performance (+$10-20/month)
   - Or upgrade to S1 tier

---

## 📄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-11-25 | Production configuration with B1 Basic tier |

---

**Configuration Status**: ✅ READY FOR DEPLOYMENT  
**Last Updated**: 2026-11-25  
**Environment**: Development (Sandbox)  
**Cost**: ~$67/month (~$800/year)
