az login

RG_NAME=ditkin-test-user-identity-rg3
VAULT_NAME=ditkin-test-keyvault3
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
USER_IDENTITY_NAME=ditkin-test-user-identity3
CONTAINER_NAME=ditkin-test-container3

# Create a resource group
az group create --name $RG_NAME --location eastus

# Get the resource ID of the resource group
RG_ID=$(az group show --name $RG_NAME --query id --output tsv)

# Create keyvault
az keyvault create \
  --name $VAULT_NAME \
  --resource-group $RG_NAME \
  --location eastus


## Needed only to give me permission to create secrets in the keyvault
## This shouldn't be needed in the actual deployment script???
  MY_ID=$(az ad user show --id $(az account show --query user.name -o tsv) --query id -o tsv)

  az role assignment create \
    --role "Key Vault Administrator" \
    --assignee $MY_ID \
    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$VAULT_NAME

  # az role assignment create \
  #   --role "Key Vault Data Access Administrator" \
  #   --assignee $MY_ID \
  #   --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$VAULT_NAME

  # az role assignment create \
  #     --role "Resource Policy Contributor" \
  #     --assignee $MY_ID \
  #     --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$VAULT_NAME
    
# Create a secret
az keyvault secret set --vault-name $VAULT_NAME --name SampleSecret --value "secret squirrel"

# Create user identity
az identity create --resource-group $RG_NAME --name $USER_IDENTITY_NAME

# Which to use SP_ID or RESOURCE_ID

# Get service principal ID of the user-assigned identity
SP_ID=$(az identity show --resource-group $RG_NAME --name $USER_IDENTITY_NAME --query principalId --output tsv)

# Get resource ID of the user-assigned identity
RESOURCE_ID=$(az identity show --resource-group $RG_NAME --name $USER_IDENTITY_NAME --query id --output tsv)

KEYVAULT_RESOURCE_ID=$(az keyvault show --name $VAULT_NAME --query 'id' -o tsv)

az role assignment create \
    --assignee $SP_ID \
    --role "Key Vault Secrets User" \
    --scope $KEYVAULT_RESOURCE_ID

# Create container with user managed identity
az container create \
  --resource-group $RG_NAME \
  --name $CONTAINER_NAME \
  --image mcr.microsoft.com/azure-cli \
  --assign-identity  $RESOURCE_ID \
  --command-line "tail -f /dev/null"

# first law of engineering, don't turn anything on you don't know how to turn off
# az container delete --resource-group $RG_NAME --name mycontainer

# 
az container show \
  --resource-group $RG_NAME \
  --name $CONTAINER_NAME 

az container exec `
  --resource-group $RG_NAME `
  --name $CONTAINER_NAME `
  --exec-command "/bin/bash"

## From within the container
## GET THE ACCESS TOKEN
ACCESS_TOKEN=$(curl "cd bly/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" -H Metadata:true -s | jq -r .access_token)
EXPIRES_IN=$(curl "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" -H Metadata:true -s | jq -r .expires_in)
## Get the secret

# Run this outside
echo curl https://$VAULT_NAME.vault.azure.net/secrets/SampleSecret/?api-version=7.4 -H \"Authorization: Bearer \$ACCESS_TOKEN\"
# should return something like 
 curl https://ditkin-test-keyvault4.vault.azure.net/secrets/SampleSecret/?api-version=7.4 -H "Authorization: B
earer $ACCESS_TOKEN"