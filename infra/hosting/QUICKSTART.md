# Quick Start Guide - Sandbox Hosting Infrastructure

## 🚀 Fast Track: 3 Minutes

### Prerequisites
```bash
az login
az account list  # Find your subscription ID
```

### Deploy in 3 Steps

**Step 1: Create Resource Group** (1 minute)
```powershell
cd infra/hosting
.\deploy.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroup "rg-hosting-dev" `
  -Suffix "dev" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "YourSecurePassword123!" `
  -Location "Central India" `
  -CreateResourceGroup
```

**Step 2: Validate & Preview** (1 minute)
```powershell
.\deploy.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroup "rg-hosting-dev" `
  -Suffix "dev" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "YourSecurePassword123!"
```

Review the what-if output. When ready:

**Step 3: Apply Deployment** (1-2 minutes)
```powershell
.\deploy.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroup "rg-hosting-dev" `
  -Suffix "dev" `
  -DbAdminUser "dbadmin" `
  -DbAdminPassword "YourSecurePassword123!" `
  -Apply
```

✅ Done! Resources are deployed.

---

## 📋 What Gets Deployed

| Resource | Name | Details |
|----------|------|---------|
| **PostgreSQL** | `psql-dev` | Flexible Server, Standard_B1ms, 32GB |
| **Container Apps Environment** | `cae-dev` | With Log Analytics workspace |
| **Storage Account** | `stdevlogs` | Standard LRS for logs/backups |
| **Managed Identities** | `id-api-dev`, `id-worker-dev` | For app authentication |
| **Log Analytics Workspace** | Auto-generated | Monitoring and diagnostics |

---

## 🔍 Verify Deployment

```powershell
.\scripts/validate-deployment.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroup "rg-hosting-dev" `
  -PostgresServerName "psql-dev" `
  -ContainerAppsEnvName "cae-dev" `
  -StorageAccountName "stdevlogs"
```

Expected output:
```
✓ PostgreSQL Server exists
✓ Container Apps Environment exists
✓ Storage Account exists
✓ All resources validated successfully!
```

---

## 🗑️ Cleanup

Delete everything when done testing:

```powershell
.\scripts/cleanup.ps1 `
  -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
  -ResourceGroup "rg-hosting-dev"
```

Enter `DELETE` when prompted.

---

## 🐛 Troubleshooting

### "Resource group does not exist"
Run Step 1 first with `-CreateResourceGroup` flag.

### "Template validation failed"
Check Bicep syntax:
```powershell
az bicep build --file main.bicep
```

### "Cannot connect to PostgreSQL"
1. Wait 2-3 minutes after deployment
2. Check firewall rules if public access enabled
3. Verify username/password in deployment

### "Docker command not found"
Install Docker Desktop for your OS.

---

## 📊 Deployment Timeline

| Step | Time | Action |
|------|------|--------|
| 1 | 10 sec | Create resource group |
| 2 | 30 sec | Validate Bicep template |
| 2 | 15 sec | Show what-if preview |
| 3 | 1-2 min | Deploy resources |
| 3 | 10 sec | Retrieve outputs |
| **Total** | **~2-3 min** | Complete infrastructure |

---

## 💡 Tips

1. **Test First**: Always run Steps 1-2 before -Apply
2. **Use Descriptive Suffix**: Use "dev", "test", "staging" not random strings
3. **Secure Password**: Use strong passwords, change after first deployment
4. **Keep Parameters Safe**: Don't commit passwords to git
5. **Monitor Costs**: Container Apps and PostgreSQL have per-minute charges

---

## 📖 Full Documentation

See [README.md](README.md) for complete documentation including:
- Detailed parameter reference
- Module descriptions
- Best practices
- Advanced configuration

---

## ✨ What's Included

- ✅ Modular Bicep templates (easy to extend)
- ✅ PowerShell orchestration scripts
- ✅ Automatic resource validation
- ✅ Safe cleanup with confirmation
- ✅ Detailed error messages
- ✅ Colored console output

## 🎯 Next: Deploy Applications

After infrastructure is ready:
1. Build container images (GitHub Actions)
2. Use `import-images.ps1` to push to customer ACR
3. Deploy Container Apps with your images
4. Configure environment variables

See [IMPLEMENTATION.md](IMPLEMENTATION.md) for technical details.
