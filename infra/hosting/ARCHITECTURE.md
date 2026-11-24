# Infrastructure Architecture

## Deployment Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   Azure Subscription                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            Resource Group: rg-hosting-{env}            │ │
│  │                                                        │ │
│  │  ┌────────────────────────────────────────────────┐  │ │
│  │  │          PostgreSQL Flexible Server            │  │ │
│  │  │  ┌──────────────────────────────────────────┐  │  │ │
│  │  │  │  psql-{env}                             │  │  │ │
│  │  │  │  • SKU: Standard_B1ms (Burstable)       │  │  │ │
│  │  │  │  • Storage: 32GB                        │  │  │ │
│  │  │  │  • Version: PostgreSQL 15               │  │  │ │
│  │  │  │  • Database: sandbox_db                 │  │  │ │
│  │  │  │  • Public Access: Disabled (default)    │  │  │ │
│  │  │  │  • Backups: 7 days (configurable)       │  │  │ │
│  │  │  └──────────────────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────┘  │ │
│  │                        ↓                               │ │
│  │  ┌────────────────────────────────────────────────┐  │ │
│  │  │          Container Apps Environment           │  │ │
│  │  │  ┌──────────────────────────────────────────┐  │  │ │
│  │  │  │  cae-{env}                              │  │  │ │
│  │  │  │  • Managed Environment                  │  │  │ │
│  │  │  │  • Zone Redundancy: Disabled            │  │  │ │
│  │  │  │  • Min Replicas: 1                      │  │  │ │
│  │  │  │  • Max Replicas: 3                      │  │  │ │
│  │  │  │  • Container Port: 3000                 │  │  │ │
│  │  │  └──────────────────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────┘  │ │
│  │                        ↓                               │ │
│  │  ┌────────────────────────────────────────────────┐  │ │
│  │  │            Log Analytics Workspace            │  │ │
│  │  │  ┌──────────────────────────────────────────┐  │  │ │
│  │  │  │  law-{uniqueString}                     │  │  │ │
│  │  │  │  • SKU: PerGB2018                       │  │  │ │
│  │  │  │  • Retention: 30 days                   │  │  │ │
│  │  │  │  • Monitoring Container Apps            │  │  │ │
│  │  │  └──────────────────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────┘  │ │
│  │                                                        │ │
│  │  ┌────────────────────────────────────────────────┐  │ │
│  │  │            Managed Identities                 │  │ │
│  │  │  ┌──────────────────────────────────────────┐  │  │ │
│  │  │  │  id-api-{env}                           │  │  │ │
│  │  │  │  • Principal ID: {guid}                 │  │  │ │
│  │  │  │  • Used by: API Container App           │  │  │ │
│  │  │  └──────────────────────────────────────────┘  │  │ │
│  │  │  ┌──────────────────────────────────────────┐  │  │ │
│  │  │  │  id-worker-{env}                        │  │  │ │
│  │  │  │  • Principal ID: {guid}                 │  │  │ │
│  │  │  │  • Used by: Worker Container App        │  │  │ │
│  │  │  └──────────────────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────┘  │ │
│  │                                                        │ │
│  │  ┌────────────────────────────────────────────────┐  │ │
│  │  │             Storage Account                    │  │ │
│  │  │  ┌──────────────────────────────────────────┐  │  │ │
│  │  │  │  st{env}logs                            │  │  │ │
│  │  │  │  • SKU: Standard_LRS                    │  │  │ │
│  │  │  │  • Tier: Hot (configurable)             │  │  │ │
│  │  │  │  • TLS: 1.2 minimum                     │  │  │ │
│  │  │  │  • Containers:                          │  │  │ │
│  │  │  │    - container-apps-backup              │  │  │ │
│  │  │  └──────────────────────────────────────────┘  │  │ │
│  │  └────────────────────────────────────────────────┘  │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Component Interactions

```
┌──────────────────────┐
│   Container Apps     │
│   Environment        │
└──────────┬───────────┘
           │
      ┌────┴──────────┬────────────────┐
      │               │                │
      ▼               ▼                ▼
┌───────────┐  ┌──────────────┐  ┌────────────┐
│   API     │  │   Worker     │  │  Storage   │
│Container  │  │  Container   │  │  Account   │
│   App     │  │     App      │  │  (Logs)    │
└─────┬─────┘  └──────┬───────┘  └────────────┘
      │               │
      └───────┬───────┘
              │
         ┌────▼─────────┐
         │  PostgreSQL  │
         │   Database   │
         │  (Shared)    │
         └──────────────┘
```

## Network Architecture

```
┌─────────────────────────────────────────────────┐
│          Azure Subscription Network             │
│                                                 │
│  Container Apps Environment:                   │
│  • Private by default                          │
│  • No VNet injection (managed)                 │
│                                                 │
│  PostgreSQL:                                   │
│  • Public access: DISABLED (first test)        │
│  • For public access: requires firewall rules  │
│                                                 │
│  Storage Account:                              │
│  • HTTPS only (TLS 1.2+)                       │
│  • Private endpoints: Optional                 │
│                                                 │
│  Managed Identities:                           │
│  • No passwords/keys needed                    │
│  • RBAC-based authentication                   │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Deployment Flow

```
┌──────────────────────────────────────────────────────────────┐
│  deploy.ps1 -CreateResourceGroup -Location "Central India"   │
└──────┬───────────────────────────────────────────────────────┘
       │
       ▼
   ┌───────────────────┐
   │  Verify auth to   │
   │  Azure subscription│
   └────────┬──────────┘
            │
            ▼
   ┌───────────────────┐
   │  Create Resource  │
   │  Group (RG)       │
   └────────┬──────────┘
            │
            └─────────── EXIT & Run Step 2

┌──────────────────────────────────────────────────────────────┐
│  deploy.ps1 (without -CreateResourceGroup)                   │
└──────┬───────────────────────────────────────────────────────┘
       │
       ▼
   ┌───────────────────┐
   │  Validate RG      │
   │  exists           │
   └────────┬──────────┘
            │
            ▼
   ┌───────────────────┐
   │  Validate Bicep   │
   │  template         │
   └────────┬──────────┘
            │
            ▼
   ┌───────────────────┐
   │  Show what-if     │
   │  preview          │
   └────────┬──────────┘
            │
            └─────────── EXIT & Review OR Run Step 3 with -Apply

┌──────────────────────────────────────────────────────────────┐
│  deploy.ps1 -Apply                                           │
└──────┬───────────────────────────────────────────────────────┘
       │
       ├──► Validate (same as above)
       │
       ├──► Show what-if preview
       │
       ├──► Confirm to proceed (or use -Apply)
       │
       ▼
   ┌─────────────────────────────────────────────────┐
   │  Deploy Template (1-2 minutes)                   │
   │  ├─ Managed Identities (10 sec)                │
   │  ├─ Storage Account (20 sec)                   │
   │  ├─ Log Analytics Workspace (30 sec)           │
   │  ├─ Container Apps Environment (30 sec)        │
   │  └─ PostgreSQL Server (40 sec)                 │
   └────────────────────┬──────────────────────────┘
                        │
                        ▼
           ┌───────────────────────────────┐
           │  Retrieve & Display Outputs   │
           │  • Resource IDs               │
           │  • FQDN (PostgreSQL)          │
           │  • Principal IDs (Identities) │
           │  • Connection Details        │
           └────────────────────┬──────────┘
                                │
                                ▼
                        ✅ DEPLOYMENT COMPLETE
```

## Resource Lifecycle

```
CREATE          │  RUNNING               │  DELETE
                │                        │
                │                        │
Managed Identity│  Used for auth         │  Auto-cleanup
   ✓ Created   │  to resources          │  when RG deleted
                │                        │
                │                        │
Storage Account │  Logs accumulated      │  Can take 2-3min
   ✓ Created   │  Container backups      │  to fully delete
   ✓ Containers│  Auto-managed           │
                │                        │
                │                        │
PostgreSQL      │  Running 24/7          │  Auto-backup
   ✓ Created   │  Backups retained       │  Deleted after
   ✓ Database  │  (7 days default)       │  RG deletion
   ✓ User      │                        │
                │                        │
                │                        │
Container Apps  │  Environment ready     │  Clean shutdown
   ✓ Created   │  for app deployments    │  
   ✓ Workspace │  Monitoring active      │
```

## Scaling Configuration

```
Container Apps: Min 1 → Max 3 Replicas
├─ Minimum: 1 replica (cost optimization)
├─ Maximum: 3 replicas (handle traffic)
└─ Scaling: CPU/Memory-based

PostgreSQL: Standard_B1ms (Burstable)
├─ CPU: Up to 2 vCores (burstable)
├─ Memory: 2 GB RAM
├─ Storage: 32GB (expandable to 16TB)
└─ Connections: 100 (configurable)

Storage: Standard LRS (Locally Redundant)
├─ Single region only
├─ 3 copies within region
└─ No geographic redundancy
```

## Security Model

```
Application          │  Database          │  Storage
                     │                     │
Managed Identity     │  Managed Identity   │  TLS 1.2+
  ↓                 │    ↓                │   ↓
No secrets needed    │  SQL Auth           │  HTTPS only
                     │  PostgreSQL roles   │  Private containers
                     │  Advisory locks     │  No public access
                     │                     │
                     │  Firewall           │
                     │  (Optional)         │
                     │  Public access OFF  │
                     │  by default         │
```

## Cost Estimation (First Test)

| Resource | Tier | Est. Daily Cost |
|----------|------|---|
| PostgreSQL Flexible Server | Standard_B1ms | $5-10 |
| Container Apps Environment | Managed | $1-3 |
| Log Analytics | PerGB2018 | $1-2 |
| Storage Account | Standard LRS | $0.50 |
| Managed Identities | Free | $0 |
| **Total** | | **~$7-15/day** |

> *Actual costs depend on usage, region, data transfer, and promotion eligibility*

## Deployment Checklist

Before deploying:
- [ ] Azure subscription access verified
- [ ] Azure CLI installed and authenticated
- [ ] PowerShell 5.1+ available
- [ ] Resource group naming convention followed
- [ ] Secure password generated
- [ ] Region selected (Central India default)

After deployment:
- [ ] Resource group created in portal
- [ ] PostgreSQL server appears in resources
- [ ] Container Apps environment ready
- [ ] Managed identities assigned
- [ ] Log Analytics workspace logging
- [ ] Storage account accessible

## Troubleshooting Matrix

| Issue | Cause | Solution |
|-------|-------|----------|
| Validation fails | Bicep syntax | `az bicep build --file main.bicep` |
| RG not found | Not created yet | Run with `-CreateResourceGroup` first |
| Deployment timeout | Azure busy | Retry after 5 minutes |
| Permission denied | Insufficient RBAC | Ensure Contributor/Owner role |
| PostgreSQL unreachable | Public access off | Add firewall rule or enable public access |
| Storage auth failure | Credentials | Verify account key in connection string |

---

**Last Updated**: Current Date
**Version**: 1.0
**Status**: Ready for Testing
