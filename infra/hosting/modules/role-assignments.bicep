@description('API managed identity principal ID for RBAC role assignments')
param apiIdentityPrincipalId string

@description('Worker managed identity principal ID for RBAC role assignments')
param workerIdentityPrincipalId string

// Role definition IDs (for reference - actual assignments would be in app modules)
var acrPullRoleId = '7f951dda-4355-481f-80cc-630798466c7d'
var postgresFlexibleServerDatabaseUserRoleId = '1e6dd4dc-fab2-408e-9b9d-9b5177172919'

output acrPullRoleId string = acrPullRoleId
output postgresUserRoleId string = postgresFlexibleServerDatabaseUserRoleId
output apiIdentityPrincipalId string = apiIdentityPrincipalId
output workerIdentityPrincipalId string = workerIdentityPrincipalId

