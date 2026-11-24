@description('Azure region for resource deployment')
param location string

@description('App Service Plan name')
param planName string

@description('API App Service name')
param apiAppServiceName string

@description('UI App Service name')
param uiAppServiceName string

@description('API Docker image URL (from source ACR)')
param apiImageUrl string

@description('UI Docker image URL (from source ACR)')
param uiImageUrl string

@description('ACR registry URL')
param acrUrl string

@description('ACR token username')
param acrUsername string

@description('ACR token password')
@secure()
param acrPassword string

@description('Resource tags')
param tags object = {}

// Deploy shared App Service Plan (Basic B1)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'B1'
    tier: 'Basic'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Deploy API App Service (Python - pulls from source ACR)
resource apiAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: apiAppServiceName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${apiImageUrl}'
      minTlsVersion: '1.2'
      http20Enabled: true
      numberOfWorkers: 1
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrUrl}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acrUsername
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acrPassword
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'
        }
      ]
    }
  }
}

// Deploy UI App Service (Node.js - pulls from source ACR)
resource uiAppService 'Microsoft.Web/sites@2023-01-01' = {
  name: uiAppServiceName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${uiImageUrl}'
      minTlsVersion: '1.2'
      http20Enabled: true
      numberOfWorkers: 1
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrUrl}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acrUsername
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acrPassword
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name

output apiAppServiceId string = apiAppService.id
output apiAppServiceName string = apiAppService.name
output apiAppServicePrincipalId string = apiAppService.identity.principalId
output apiAppServiceHostname string = apiAppService.properties.defaultHostName

output uiAppServiceId string = uiAppService.id
output uiAppServiceName string = uiAppService.name
output uiAppServicePrincipalId string = uiAppService.identity.principalId
output uiAppServiceHostname string = uiAppService.properties.defaultHostName
