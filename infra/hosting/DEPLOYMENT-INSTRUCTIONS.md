# 🚀 Deployment Instructions (One-Command Flow)

## Quick Start - Customer Deployment

### **ONE COMMAND DEPLOYS EVERYTHING:**

```powershell
cd infra\hosting

.\deploy-one-flow.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroup "rg-hosting-prod" `
  -Suffix "prod" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "P@ssw0rd123!"
```

## What Gets Deployed?

✓ **Resource Group** - Container for all resources  
✓ **PostgreSQL Flexible Server** - Database  
✓ **Container Apps Environment** - For worker services  
✓ **App Service** - For API hosting  
✓ **Storage Account** - For logs  
✓ **Managed Identities** - Secure authentication  
✓ **Role Assignments** - RBAC permissions  

**Time Required:** 2-3 minutes

---

## Prerequisites

Before running the deployment, ensure:

### 1. **Azure CLI Installed**
```powershell
az --version
```
If not installed, download from [Azure CLI docs](https://learn.microsoft.com/cli/azure/install-azure-cli)

### 2. **Logged In to Azure**
```powershell
az login
# This opens a browser window to authenticate
```

### 3. **Correct Subscription Selected**
```powershell
# View all subscriptions
az account list --output table

# Set to your subscription (copy ID from output above)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 4. **Sufficient Permissions**
Your Azure account needs:
- `Contributor` or `Owner` role on the subscription (to create resources)
- Ability to create resource groups, App Service, Container Apps, PostgreSQL, Storage accounts

---

## Step-by-Step: First Time Setup

### Step 1: Get Your Subscription ID
```powershell
az account list --output table
```
Copy the `SubscriptionId` value from the output.

### Step 2: Navigate to Hosting Folder
```powershell
cd C:\path\to\Azure-Sandbox\infra\hosting
```

### Step 3: Run Deployment
```powershell
.\deploy-one-flow.ps1 `
  -SubscriptionId "PASTE_YOUR_SUB_ID_HERE" `
  -ResourceGroup "rg-hosting-prod" `
  -Suffix "prod" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "P@ssw0rd123!"
```

**Expected Output:**
```
╔════════════════════════════════════════════════════════════════╗
║          AUTOMATED INFRASTRUCTURE DEPLOYMENT                   ║
╚════════════════════════════════════════════════════════════════╝

Configuration:
  Subscription: 9dd38a25-a50b-4f30-be0c-ea1ac7b44bdb
  Resource Group: rg-hosting-prod
  Suffix: prod
  Location: Central India

▶ STEP 1: Creating resource group...
✓ Resource group created/verified

▶ STEP 2: Deploying infrastructure...
✓ Infrastructure deployed successfully

▶ STEP 3: Validating resources...
✓ All resources validated

╔════════════════════════════════════════════════════════════════╗
║                  ✅ DEPLOYMENT COMPLETE!                       ║
╚════════════════════════════════════════════════════════════════╝
```

---

## Parameter Explanation

| Parameter | Required | Example | Notes |
|-----------|----------|---------|-------|
| `SubscriptionId` | ✓ | `9dd38a25-a50b-4f30-be0c-ea1ac7b44bdb` | From `az account list` |
| `ResourceGroup` | ✓ | `rg-hosting-prod` | Azure naming rules apply |
| `Suffix` | ✓ | `prod` | 3-8 lowercase alphanumeric chars |
| `DbAdminUser` | ✓ | `dbadmin` | PostgreSQL admin username |
| `DbAdminPassword` | ✓ | `P@ssw0rd123!` | 12+ chars, mix of upper/lower/numbers/special |
| `Location` | Optional | `Central India` | Default: `Central India` |

---

## Troubleshooting

### **Error: "CONNECTIVITY_REFRESH_TOKEN_ERROR"**
**Solution:** Re-authenticate with Azure
```powershell
az logout
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### **Error: "Access to registry was denied (401)"**
**Solution:** This is expected during infra-only deployment. Ignore if deploying infra only.

### **Error: "Resource group not found"**
**Solution:** Deployment script creates the resource group if it doesn't exist. Run the command again.

### **Error: "Insufficient permissions"**
**Solution:** Contact your Azure admin to grant `Contributor` role on the subscription.

### **Timeout during deployment**
**Solution:** Some resources take 3-5 minutes to provision. Check Azure Portal for resource status while waiting.

---

## What Happens After Deployment?

1. ✓ Infrastructure is deployed and ready
2. ✓ All resources are validated
3. Next: Deploy application code (APIs, workers)
4. Next: Configure environment variables
5. Next: Deploy container images

---

## Support

For detailed logs, check:
```powershell
# View resource group events
az monitor activity-log list -g rg-hosting-prod --max-events 20

# View specific resource details
az resource list -g rg-hosting-prod --output table
```

---

## Command Reference

| Task | Command |
|------|---------|
| View all resources deployed | `az resource list -g rg-hosting-prod --output table` |
| View PostgreSQL details | `az postgres flexible-server show -g rg-hosting-prod -n psql-prod` |
| View Container Apps Environment | `az containerapp env show -g rg-hosting-prod -n cae-prod` |
| View App Service | `az appservice plan list -g rg-hosting-prod --output table` |
| Delete all resources | `az group delete -g rg-hosting-prod` |
