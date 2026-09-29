targetScope = 'resourceGroup'

@description('Azure region for the pipeline identity.')
param location string = resourceGroup().location

@description('GitHub repository owner or organization.')
param githubOwner string

@description('GitHub repository name.')
param githubRepository string

@description('Target resource group where GitHub Actions will deploy infrastructure.')
param targetResourceGroupName string

@description('Git branch allowed to authenticate through GitHub OIDC.')
param githubBranch string = 'main'

var identityToken = uniqueString(subscription().id, resourceGroup().id, location, 'github')
var identityName = 'azmi${identityToken}'
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: targetResourceGroupName
  scope: subscription()
}

resource pipelineIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource githubFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: pipelineIdentity
  name: 'azfc${identityToken}'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:${githubOwner}/${githubRepository}:ref:refs/heads/${githubBranch}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

module targetGroupContributor 'role-assignment.bicep' = {
  name: 'azmod${identityToken}'
  scope: targetResourceGroup
  params: {
    principalId: pipelineIdentity.properties.principalId
    roleDefinitionId: contributorRoleId
  }
}

output identityName string = pipelineIdentity.name
output clientId string = pipelineIdentity.properties.clientId
output principalId string = pipelineIdentity.properties.principalId
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId