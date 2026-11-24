@description('Azure region for resource deployment')
param location string

@description('PostgreSQL Flexible Server name')
param serverName string

@description('PostgreSQL database name')
param databaseName string

@description('PostgreSQL administrator username')
param adminUsername string

@description('PostgreSQL administrator password')
@secure()
param adminPassword string

@description('PostgreSQL SKU name (e.g., Standard_B2ms for Burstable, Standard_D2s_v3 for GeneralPurpose)')
param skuName string = 'Standard_B2ms'

@description('Storage size in GB (must be between 32-16384 for Premium SSD, min 5 acceptable for initial setup)')
@minValue(5)
@maxValue(16384)
param storageSizeGB int = 5

@description('Backup retention days')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable geo-redundant backups')
param geoRedundantBackup bool = false

@description('Resource tags')
param tags object = {}

// Deploy PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: contains(skuName, 'Standard_B') ? 'Burstable' : 'GeneralPurpose'
  }
  properties: {
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: backupRetentionDays
      geoRedundantBackup: geoRedundantBackup ? 'Enabled' : 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: null
      privateDnsZoneArmResourceId: null
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// Create database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-12-01-preview' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Server configuration for connection pooling and performance
resource serverConfig 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-12-01-preview' = {
  parent: postgresServer
  name: 'max_connections'
  properties: {
    value: '100'
    source: 'user-override'
  }
}

output serverId string = postgresServer.id
output serverName string = postgresServer.name
output serverFqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
output administratorLogin string = adminUsername
