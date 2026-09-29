targetScope = 'resourceGroup'

@description('Principal receiving constrained role-assignment permissions.')
param principalId string

@description('Role definition granting role-assignment management.')
param roleDefinitionId string

@description('Condition restricting which roles and principal types can be assigned.')
param condition string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, principalId, roleDefinitionId, condition)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
    condition: condition
    conditionVersion: '2.0'
  }
}