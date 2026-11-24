# Cross-Tenant Deployment Guide - ACR Token Authentication

**Status**: ✅ READY  
**Architecture**: Your ACR → Customer's Tenant  
**Authentication**: Read-Only ACR Token  
**Security**: No permanent credentials exposed

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────┐
│   YOUR TENANT (acrsbxdev7e76e808)   │
│   ┌─────────────────────────────┐   │
│   │  Azure Container Registry   │   │
│   │  - sandbox-api:latest       │   │
│   │  - sandbox-ui:latest        │   │
│   │  - sandbox-worker:latest    │   │
│   └─────────────────────────────┘   │
└──────────────┬──────────────────────┘
               │
        ACR Token Auth
        (Read-only)
               │
┌──────────────▼──────────────────────┐
│   CUSTOMER TENANT                   │
│   ┌─────────────────────────────┐   │
│   │  App Service: API           │   │
│   │  - Pulls sandbox-api:latest │   │
│   │  - From your ACR (token)    │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │  App Service: UI            │   │
│   │  - Pulls sandbox-ui:latest  │   │
│   │  - From your ACR (token)    │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │  PostgreSQL                 │   │
│   │  - 18 tables auto-created   │   │
│   └─────────────────────────────┘   │
│   ┌─────────────────────────────┐   │
│   │  Key Vault                  │   │
│   │  - Stores ACR token         │   │
│   │  - Stores DB credentials    │   │
│   └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## 📋 What You (Provider) Do - One Time Setup

### Step 1: Create ACR Token in Your ACR

```bash
# Create a scope map for read-only access
az acr scope-map create \
  --registry acrsbxdev7e76e808 \
  --name sandbox-pull-only \
  --actions "repositories/*/read"

# Create the token
az acr token create \
  --registry acrsbxdev7e76e808 \
  --name sandbox-pull-token \
  --scope-map sandbox-pull-only

# Get the token password (save this!)
az acr token credential show \
  --registry acrsbxdev7e76e808 \
  --name sandbox-pull-token \
  --suffix password
```

### Step 2: Provide Customer with These Credentials

```
✓ ACR URL:              acrsbxdev7e76e808.azurecr.io
✓ Token Username:       sandbox-pull-token
✓ Token Password:       (from step 1 - keep secure!)
✓ Image Names:
  - sandbox-api:latest
  - sandbox-ui:latest
  - sandbox-worker:latest (optional)
✓ Database Credentials:
  - Username: sandboxadmin
  - Password: (you decide - share securely)
```

---

## 🚀 What Customer Does - Deployment

### Prerequisites
```powershell
# 1. Install Azure CLI 2.50+
az --version

# 2. Login to their Azure subscription
az login

# 3. Verify subscription
az account show
```

### Deployment Command
```powershell
cd infra/hosting

# Interactive (prompts for passwords)
./deploy-cross-tenant.ps1

# Or provide all parameters
./deploy-cross-tenant.ps1 `
  -ResourceGroupName "sandbox-sbx-prod" `
  -Location "East US" `
  -DbAdminPassword "08fpIz3EHYoW6b7Q" `
  -SourceAcrUrl "acrsbxdev7e76e808.azurecr.io" `
  -AcrTokenUsername "sandbox-pull-token" `
  -AcrTokenPassword "TOKEN_PASSWORD_HERE" `
  -ImageTag "latest"
```

### What Happens Automatically
```
1. Creates resource group in customer's subscription
2. Validates Bicep template
3. Verifies ACR token (can read your images)
4. Deploys infrastructure:
   ✓ App Service Plan (B1 Basic)
   ✓ 2 App Services (API + UI)
   ✓ PostgreSQL (Burstable B2MS)
   ✓ Key Vault
   ✓ Storage Account
5. App Services pull images from your ACR
6. Database auto-initializes (18 tables)
7. Validation tests run
8. Success summary displayed with endpoints
```

---

## 🔐 Security Details

### ACR Token (Read-Only)
```bicep
✓ Scope: Can only READ repositories
✓ Cannot: Push, delete, or modify images
✓ Revocable: Can be disabled anytime
✓ Token-based: No shared service principals
```

**Why this is secure:**
- Read-only access - customer can't push malicious code
- Token, not credentials - can be rotated
- Stored in customer's Key Vault - not in code
- Each customer gets same token (you control images)

### How App Services Authenticate

```bicep
App Service Configuration:
  DOCKER_REGISTRY_SERVER_URL: https://acrsbxdev7e76e808.azurecr.io
  DOCKER_REGISTRY_SERVER_USERNAME: sandbox-pull-token
  DOCKER_REGISTRY_SERVER_PASSWORD: (token password)

Flow:
  1. App Service needs sandbox-api:latest
  2. Contacts your ACR with token
  3. Your ACR validates token
  4. If valid, pulls image
  5. App Service runs image
```

---

## 📊 Cost for Customer

| Component | Tier | Cost/Month |
|-----------|------|-----------|
| App Service Plan | B1 Basic | $7.50 |
| PostgreSQL | Burstable B2MS | $42.50 |
| Storage | 5 GB | $1.00 |
| Key Vault | Standard | <$1.00 |
| Container Apps | Minimal | $5.00 |
| **Total** | | **~$67/month** |

---

## 🎯 Customer Checklist

After deployment completes:

- [ ] API endpoint is accessible: `https://app-sbx-api-prod.azurewebsites.net`
- [ ] UI endpoint is accessible: `https://app-sbx-ui-prod.azurewebsites.net`
- [ ] PostgreSQL is running with 18 tables
- [ ] App Services are pulling images from your ACR
- [ ] Environment variables are configured (if needed)
- [ ] Database connectivity verified

---

## 🔄 Image Updates (How to Redeploy)

**If you update images in your ACR:**

```bash
# 1. Rebuild and push new images
docker build -t acrsbxdev7e76e808.azurecr.io/sandbox-api:v2 .
docker push acrsbxdev7e76e808.azurecr.io/sandbox-api:v2

# 2. Customer redeploys with new tag
./deploy-cross-tenant.ps1 -ImageTag "v2"

# Or they can restart App Services to pull latest tag
az webapp restart -n app-sbx-api-prod -g sandbox-sbx-prod
```

---

## 🛡️ Token Management

### Monitor Token Usage
```bash
# List all tokens
az acr token list --registry acrsbxdev7e76e808

# Check token details
az acr token show --registry acrsbxdev7e76e808 --name sandbox-pull-token
```

### Revoke Token (if compromised)
```bash
# Disable token
az acr token update --registry acrsbxdev7e76e808 --name sandbox-pull-token --status disabled

# Or delete entirely
az acr token delete --registry acrsbxdev7e76e808 --name sandbox-pull-token
```

### Create New Token (after revoke)
```bash
# Create new token with same scope
az acr token create \
  --registry acrsbxdev7e76e808 \
  --name sandbox-pull-token-v2 \
  --scope-map sandbox-pull-only
```

---

## 📞 Troubleshooting

### "Cannot pull image from ACR"
```
Possible causes:
1. Token password incorrect
2. Token disabled/revoked
3. Image tag doesn't exist
4. ACR URL typo

Solution:
  - Verify token: az acr token show ...
  - Verify image exists: az acr repository list ...
  - Verify token password
  - Redeploy with correct credentials
```

### "App Service stays in 'starting' state"
```
Possible causes:
1. Image can't be pulled (token issue)
2. Image doesn't exist at tag
3. App Service port mismatch

Solution:
  - Check App Service logs
  - Verify ACR token access
  - Verify image tag is correct
```

### "PostgreSQL connection fails"
```
Possible causes:
1. Database password incorrect
2. Connection string malformed
3. Network access blocked

Solution:
  - Check DATABASE_URL environment variable
  - Verify password in Key Vault
  - Check PostgreSQL firewall rules
```

---

## 🎓 Customer Documentation to Provide

Create these files for customer:

1. **DEPLOYMENT-GUIDE.md**
   - Step-by-step deployment instructions
   - Parameter explanations
   - What to expect

2. **QUICK-REFERENCE.md**
   - Quick lookup table
   - Common commands
   - Troubleshooting tips

3. **AFTER-DEPLOYMENT.md**
   - Configuration steps
   - Testing procedures
   - Support contacts

---

## ✨ Key Advantages of This Approach

✅ **Secure**
- Read-only token access
- No service principals needed
- Customer stays in their tenant

✅ **Simple**
- One deployment command
- Automatic everything
- No manual image copying

✅ **Scalable**
- Same token works for all customers
- Each customer isolated in their tenant
- No cross-tenant resource sharing

✅ **Maintainable**
- Update images once in your ACR
- Customers redeploy with new tag
- Revoke access anytime

---

## 📋 Deployment Template

**What to give customer:**

```
📁 sandbox-deployment-package/
├── 📄 deploy-cross-tenant.ps1          ← Main deployment script
├── 📄 main.bicep                        ← Infrastructure code
├── 📁 modules/                          ← Bicep modules
├── 📄 parameters-prod.json              ← Configuration template
├── 📄 DEPLOYMENT-GUIDE.md               ← Instructions
├── 📄 QUICK-REFERENCE.md                ← Quick lookup
└── 📄 CREDENTIALS.md                    ← What you provided
    ├── ACR URL
    ├── Token username
    ├── Token password
    └── Database credentials
```

---

**Status**: ✅ CROSS-TENANT DEPLOYMENT READY

This approach delivers:
- 🏢 Multi-tenant isolation
- 🔐 Secure cross-tenant access
- 📦 One-command deployment
- 🎯 Images from your ACR
- ⚡ Automatic database setup
