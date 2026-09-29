param(
    [Parameter(Mandatory = $true)]
    [string] $GitHubOwner,

    [Parameter(Mandatory = $true)]
    [string] $GitHubRepository,

    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,

    [string] $GitHubBranch = 'main',

    [string] $Location = 'eastus2',

    [string] $TargetResourceGroup = 'rg-bicep-dev',

    [string] $IdentityResourceGroup = 'rg-github-oidc'
)

$ErrorActionPreference = 'Stop'
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

if (-not (Test-Path $az)) {
    throw "Azure CLI was not found at $az. Install Azure CLI and open a new PowerShell session."
}

& $az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) { throw 'Could not select the requested Azure subscription.' }

& $az group create --name $TargetResourceGroup --location $Location --subscription $SubscriptionId --output none
if ($LASTEXITCODE -ne 0) { throw 'Could not create or verify the target resource group.' }

& $az group create --name $IdentityResourceGroup --location $Location --subscription $SubscriptionId --output none
if ($LASTEXITCODE -ne 0) { throw 'Could not create or verify the separate identity resource group.' }

$templatePath = Join-Path $PSScriptRoot '..\infra\pipeline-identity.bicep'
& $az deployment group create `
    --name 'github-oidc-identity' `
    --resource-group $IdentityResourceGroup `
    --subscription $SubscriptionId `
    --template-file $templatePath `
    --parameters location=$Location `
        githubOwner=$GitHubOwner `
        githubRepository=$GitHubRepository `
        githubBranch=$GitHubBranch `
        targetResourceGroupName=$TargetResourceGroup `
    --output json
if ($LASTEXITCODE -ne 0) { throw 'Pipeline identity deployment failed.' }

$identity = & $az identity list --resource-group $IdentityResourceGroup --subscription $SubscriptionId --query "[?starts_with(name, 'azmi')].{name:name,clientId:clientId,principalId:principalId,tenantId:tenantId}" --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $identity.Count -eq 0) { throw 'Could not read the deployed pipeline identity.' }

Write-Host ''
Write-Host 'Add these as repository Actions variables:'
Write-Host "AZURE_CLIENT_ID=$($identity[0].clientId)"
Write-Host "AZURE_TENANT_ID=$($identity[0].tenantId)"
Write-Host "AZURE_SUBSCRIPTION_ID=$SubscriptionId"
Write-Host "AZURE_RESOURCE_GROUP=$TargetResourceGroup"
Write-Host 'ADMIN_SSH_PUBLIC_KEY=<your OpenSSH public key>'
Write-Host 'VM_ADMIN_USERNAME=azureuser'
Write-Host ''
Write-Host "GitHub OIDC is restricted to branch '$GitHubBranch'. The identity has Contributor on the target resource group only."