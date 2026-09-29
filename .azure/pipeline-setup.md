# Azure and GitHub Actions setup

This repository deploys a single Ubuntu dev VM and a private Blob Storage account. Azure resources are created in `rg-bicep-dev`; the GitHub Actions user-assigned managed identity is in the separate `rg-github-oidc` resource group. The deployment workflow is manual and uses GitHub OIDC, not a stored Azure client secret.

## Prerequisites

- Azure CLI and Bicep installed, with an account that can create resource groups and assign roles.
- A GitHub repository containing this code. The workflow and OIDC identity are restricted to the `main` branch.
- An SSH key pair. Keep the private key on your machine; only the `.pub` public key is used for VM provisioning.
- A subscription with quota for a VM size you select. `Standard_B1s` is unavailable to this subscription in `eastus2`; verify a supported region and size instead.

Check candidate sizes and quota before deployment:

```powershell
az vm list-skus --location <region> --resource-type virtualMachines --all -o table
az vm list-usage --location <region> -o table
```

## 1. Provision the deployment identity

From the repository root, run PowerShell after signing in with `az login`:

```powershell
az login
$subscriptionId = az account show --query id -o tsv
./scripts/setup-azure-auth-for-pipeline.ps1 -GitHubOwner 'toluoladejo' -GitHubRepository 'Bicep' -GitHubOwnerId '94096111' -GitHubRepositoryId '1396206059' -SubscriptionId $subscriptionId -GitHubBranch 'main'
```

The numeric GitHub owner and repository IDs are part of the OIDC subject Azure receives. For this repository the subject is `repo:toluoladejo@94096111/Bicep@1396206059:ref:refs/heads/main`. Rerun the script to update the existing federated credential to that exact subject. The script creates the target and separate identity resource groups as needed and grants the identity Contributor on the target resource group only. If your default branch is not `main`, pass its name with `-GitHubBranch` and update the workflow's branch condition to match. The signed-in Azure user needs permission to create resource groups and assign roles; an Owner or User Access Administrator role is typically required for role assignment.

## 2. Configure repository Actions variables

In the repository, open **Settings > Secrets and variables > Actions > Variables** and add these as repository variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_RESOURCE_GROUP`
- `ADMIN_SSH_PUBLIC_KEY` (contents of your `.pub` file; never upload the private key)
- `VM_ADMIN_USERNAME` (normally `azureuser`)

No Azure credential secret or GitHub Environment is used. The OIDC issuer is `https://token.actions.githubusercontent.com`, the audience is `api://AzureADTokenExchange`, and the federated subject permits only the configured branch. Copy any values currently set on the old `dev` environment to repository variables before deleting that environment.

## 3. Deploy

Open **Actions > Deploy infrastructure > Run workflow** and select the `main` branch. Enter a verified Azure region, a VM size supported in that region, and your public IPv4 address as a single CIDR, typically `x.x.x.x/32`. The workflow rejects CIDRs broader than `/16`. Dispatches from other branches will not run the deployment job.

After success, inspect the workflow run's deployment output for the VM public IP, VM name, storage account, and blob container. Connect to the VM using SSH and your private key. Blob Storage is private, shared-key access is disabled, and the VM's managed identity has blob data access. The VM is scheduled to shut down daily at 19:00 UTC.

## Remove resources

Deleting `rg-bicep-dev` removes the VM, network, private endpoint, and storage account. Export any data you need first. After disabling the workflow, delete `rg-github-oidc` to remove the GitHub deployment identity. Azure resources can incur charges; check pricing and free-service limits before deployment.