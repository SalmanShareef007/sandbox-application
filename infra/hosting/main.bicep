targetScope = 'resourceGroup'

@description('Azure region for resource deployment')
param location string = resourceGroup().location

@description('Environment name suffix (3-8 lowercase alphanumeric)')
param suffix string

@description('Image tag for container deployments (yyyyMMddHHmmss format)')
param imageTag string = '20261125'

@description('Database administrator username')
param dbAdminUser string

@description('Database administrator password')
@secure()
param dbAdminPassword string

@description('Source ACR registry URL (your ACR where images are stored)')
param sourceAcrUrl string = 'acrsbxdev7e76e808.azurecr.io'

@description('ACR token username (read-only access)')
param acrTokenUsername string

@description('ACR token password (read-only access)')
@secure()
param acrTokenPassword string

@description('Container Apps: Minimum replicas')
@minValue(1)
@maxValue(30)
param minReplicas int = 1

@description('Container Apps: Maximum replicas')
@minValue(1)
@maxValue(30)
param maxReplicas int = 3

var tags = {
  Application: 'sandbox'
  Environment: 'dev'
  ManagedBy: 'Bicep'
}

var storageAccountName = 'stgsbxprod'
var postgresServerName = 'psql-sbx-prod'
var containerAppsEnvName = 'app-sbx-worker-prod'
var appServicePlanName = 'asp-sbx-prod'
var apiAppServiceName = 'app-sbx-api-prod'
var uiAppServiceName = 'app-sbx-ui-prod'
var containerRegistryName = 'acrsbxprod'
var keyVaultName = 'kv-sbx-prod'
var postgresDatabaseName = 'sandboxDB'

// API image: sandbox-api:latest from source ACR
var apiImageUrl = '${sourceAcrUrl}/sandbox-api:${imageTag}'
// UI image: sandbox-ui:latest from source ACR
var uiImageUrl = '${sourceAcrUrl}/sandbox-ui:${imageTag}'

// Deploy managed identities for API and Worker
module apiIdentity './modules/managed-identity.bicep' = {
  name: 'api-identity-${uniqueString(resourceGroup().id)}'
  params: {
    name: 'id-api-${suffix}'
    location: location
    tags: tags
  }
}

module workerIdentity './modules/managed-identity.bicep' = {
  name: 'worker-identity-${uniqueString(resourceGroup().id)}'
  params: {
    name: 'id-worker-${suffix}'
    location: location
    tags: tags
  }
}

// Deploy storage account for logs
module storageAccount './modules/storage.bicep' = {
  name: 'storage-${uniqueString(resourceGroup().id)}'
  params: {
    name: storageAccountName
    location: location
    tags: tags
  }
}

// Deploy PostgreSQL Flexible Server with restricted public access
module postgresDatabase './modules/postgresql.bicep' = {
  name: 'postgres-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    serverName: postgresServerName
    databaseName: postgresDatabaseName
    adminUsername: dbAdminUser
    adminPassword: dbAdminPassword
    tags: tags
  }
}

// Deploy Container Apps environment
module containerAppsEnvironment './modules/container-apps.bicep' = {
  name: 'cae-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    envName: containerAppsEnvName
    storageAccountName: storageAccount.outputs.name
    tags: tags
  }
}

// Deploy Container Registry
module containerRegistry './modules/acr.bicep' = {
  name: 'acr-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    registryName: containerRegistryName
    tags: tags
  }
}

// Deploy App Service Plan and App Services (API + UI)
module appService './modules/app-service.bicep' = {
  name: 'appservice-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    planName: appServicePlanName
    apiAppServiceName: apiAppServiceName
    uiAppServiceName: uiAppServiceName
    apiImageUrl: apiImageUrl
    uiImageUrl: uiImageUrl
    acrUrl: sourceAcrUrl
    acrUsername: acrTokenUsername
    acrPassword: acrTokenPassword
    tags: tags
  }
}

// Deploy role assignments for managed identities
module roleAssignments './modules/role-assignments.bicep' = {
  name: 'roles-${uniqueString(resourceGroup().id)}'
  params: {
    apiIdentityPrincipalId: apiIdentity.outputs.principalId
    workerIdentityPrincipalId: workerIdentity.outputs.principalId
  }
}

// Deploy Key Vault for storing secrets
module keyVault './modules/key-vault.bicep' = {
  name: 'keyvault-${uniqueString(resourceGroup().id)}'
  params: {
    location: location
    vaultName: keyVaultName
    tags: tags
    dbAdminUsername: dbAdminUser
    dbAdminPassword: dbAdminPassword
    apiAppServicePrincipalId: appService.outputs.apiAppServicePrincipalId
    uiAppServicePrincipalId: appService.outputs.uiAppServicePrincipalId
  }
}

// Initialize PostgreSQL database (create tables and seed data)
module databaseInit './modules/database-init.bicep' = {
  name: 'db-init-${uniqueString(resourceGroup().id)}'
  params: {
    postgresServerFqdn: postgresDatabase.outputs.serverFqdn
    postgresServerName: postgresDatabase.outputs.serverName
    postgresDatabaseName: postgresDatabaseName
    dbAdminUser: dbAdminUser
    dbAdminPassword: dbAdminPassword
    location: location
  }
}

output apiIdentityId string = apiIdentity.outputs.id
output apiIdentityPrincipalId string = apiIdentity.outputs.principalId
output workerIdentityId string = workerIdentity.outputs.id
output workerIdentityPrincipalId string = workerIdentity.outputs.principalId
output storageAccountId string = storageAccount.outputs.id
output storageAccountName string = storageAccount.outputs.name
output postgresServerId string = postgresDatabase.outputs.serverId
output postgresServerName string = postgresDatabase.outputs.serverName
output postgresServerFqdn string = postgresDatabase.outputs.serverFqdn
output postgresDatabaseName string = postgresDatabaseName
output containerAppsEnvId string = containerAppsEnvironment.outputs.environmentId
output containerAppsEnvName string = containerAppsEnvironment.outputs.environmentName
output containerRegistryId string = containerRegistry.outputs.registryId
output containerRegistryName string = containerRegistry.outputs.registryName
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output appServicePlanId string = appService.outputs.appServicePlanId
output appServicePlanName string = appService.outputs.appServicePlanName
output apiAppServiceId string = appService.outputs.apiAppServiceId
output apiAppServiceName string = appService.outputs.apiAppServiceName
output apiAppServiceHostname string = appService.outputs.apiAppServiceHostname
output apiAppServicePrincipalId string = appService.outputs.apiAppServicePrincipalId
output uiAppServiceId string = appService.outputs.uiAppServiceId
output uiAppServiceName string = appService.outputs.uiAppServiceName
output uiAppServiceHostname string = appService.outputs.uiAppServiceHostname
output uiAppServicePrincipalId string = appService.outputs.uiAppServicePrincipalId
output keyVaultId string = keyVault.outputs.keyVaultId
output keyVaultName string = keyVault.outputs.keyVaultName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output databaseInitStatus string = databaseInit.outputs.initStatus
