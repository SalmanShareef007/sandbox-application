@description('Azure region for resource deployment')
param location string

@description('Managed identity name')
param name string

@description('Resource tags')
param tags object = {}

// Deploy user-assigned managed identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

output id string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
