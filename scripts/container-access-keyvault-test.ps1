# To run this script, you need to have the Az PowerShell module installed.
# You can install it by running `Install-Module -Name Az -AllowClobber -Scope CurrentUser` in PowerShell.
# You also need to be logged in to your Azure account by running `Connect-AzAccount`.

# Define variables
$RG_NAME = "ditkin-test-user-identity-rg4"
$VAULT_NAME = "ditkin-test-keyvault4"
$USER_IDENTITY_NAME = "ditkin-test-user-identity4"
$CONTAINER_NAME = "ditkin-test-container4"
$location = "EastUS"

# Get default subscription details
$subscription = Get-AzSubscription | Where-Object { $_.IsDefault -eq $true }
$SUBSCRIPTION_ID = $subscription.Id

# Create a resource group
New-AzResourceGroup -Name $RG_NAME -Location "EastUS"

# Retrieve the resource group object to get ResourceId if needed
$rg = Get-AzResourceGroup -Name $RG_NAME
$RG_ID = $rg.ResourceId

# Create Key Vault
New-AzKeyVault -Name $VAULT_NAME -ResourceGroupName $RG_NAME -Location "EastUS" | Out-Null
$kv = Get-AzKeyVault -VaultName $VAULT_NAME

# (Optional) Assign yourself "Key Vault Administrator" so you can set secrets 
# This step is typically only needed for initial setup, not in a CI/CD script
$myUpn = (Get-AzContext).Account
$myUser = Get-AzADUser -UserPrincipalName $myUpn
$MY_ID = $myUser.Id

New-AzRoleAssignment -ObjectId $MY_ID `
                     -RoleDefinitionName "Key Vault Administrator" `
                     -Scope $kv.ResourceId

# Create a secret in the Key Vault
$secureString = ConvertTo-SecureString -String "secret squirrel" -AsPlainText
Set-AzKeyVaultSecret -VaultName $VAULT_NAME -Name "SampleSecret" -SecretValue $secureString

# Create user-assigned managed identity
$identity = New-AzUserAssignedIdentity -ResourceGroupName $RG_NAME -Name $USER_IDENTITY_NAME -Location $location
$SP_ID = $identity.PrincipalId
$RESOURCE_ID = $identity.Id

# Assign "Key Vault Secrets User" role to the identity for the Key Vault
New-AzRoleAssignment -ObjectId $SP_ID `
                     -RoleDefinitionName "Key Vault Secrets User" `
                     -Scope $kv.ResourceId


# New-AzContainerGroup -ResourceGroupName test-rg -Name test-cg -Location eastus -Container $container -IdentityType "SystemAssigned, UserAssigned" -IdentityUserAssignedIdentity @{"/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{identityName}" = @{}}

# define the container
$container = New-AzContainerInstanceObject `
    -Name $CONTAINER_NAME `
    -Image "mcr.microsoft.com/azure-cli" `
    -Command "tail", "-f", "/dev/null" 


# Create an Azure Container Instance with user-managed identity
New-AzContainerGroup -ResourceGroupName $RG_NAME  -Name $CONTAINER_NAME `
                     -Container $container `
                     -Location $location `
                     -OsType Linux `
                     -IdentityType UserAssigned `
                     -IdentityUserAssignedIdentity @{$RESOURCE_ID = @{}}
      
function Get-ContainerGroupStatus {
    param (
        [string]$resourceGroupName,
        [string]$containerGroupName
    )
    $containerGroup = Get-AzContainerGroup -ResourceGroupName $resourceGroupName -Name $containerGroupName
    return $containerGroup.ProvisioningState
}

# Wait for the container to be provisioned
$status = Get-ContainerGroupStatus -resourceGroupName $RG_NAME -containerGroupName $CONTAINER_NAME
while ($status -ne "Succeeded") {
    Write-Host "Container group status: $status"
    Start-Sleep -s 10
    $status = Get-ContainerGroupStatus -resourceGroupName $RG_NAME -containerGroupName $CONTAINER_NAME
}

# Show container details
Get-AzContainerGroup -ResourceGroupName $RG_NAME -Name $CONTAINER_NAME

# Exec into container
# Use same AZ commands

az container exec `
  --resource-group $RG_NAME `
  --name $CONTAINER_NAME `
  --exec-command "/bin/bash"

## From within the container
## GET THE ACCESS TOKEN
ACCESS_TOKEN=$(curl "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" -H Metadata:true -s | jq -r .access_token)
EXPIRES_IN=$(curl "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" -H Metadata:true -s | jq -r .expires_in)
## Get the secret

# Run this outside
echo curl https://$VAULT_NAME.vault.azure.net/secrets/SampleSecret/?api-version=7.4 -H \"Authorization: Bearer \$ACCESS_TOKEN\"
# should return something like 
 curl https://ditkin-test-keyvault4.vault.azure.net/secrets/SampleSecret/?api-version=7.4 -H "Authorization: B
bearer $ACCESS_TOKEN"
