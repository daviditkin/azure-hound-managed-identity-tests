az login

RG_NAME=ditkin-test-rg
VAULT_NAME=ditkin-test-keyvault1
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
USER_IDENTITY_NAME=myACIId

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

  az role assignment create \
    --role "Key Vault Data Access Administrator" \
    --assignee $MY_ID \
    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$VAULT_NAME

  az role assignment create \
      --role "Resource Policy Contributor" \
      --assignee $MY_ID \
      --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$VAULT_NAME

# Create a secret
az keyvault secret set --vault-name $VAULT_NAME --name SampleSecret --value "secret squirrel"

# Create user identity
az identity create --resource-group $RG_NAME --name $USER_IDENTITY_NAME

# Get service principal ID of the user-assigned identity
SP_ID=$(az identity show --resource-group $RG_NAME --name $USER_IDENTITY_NAME --query principalId --output tsv)

# Get resource ID of the user-assigned identity
RESOURCE_ID=$(az identity show --resource-group $RG_NAME --name $USER_IDENTITY_NAME --query id --output tsv)

# Grant the identity access to the key vault
 az keyvault set-policy \
    --name $VAULT_NAME \
    --resource-group $RG_NAME \
    --object-id $SP_ID \
    --secret-permissions get list set

# Create a secret
az keyvault secret set --vault-name $VAULT_NAME --name SampleSecret --value "secret squirrel"

# Create container with system assigned managed identity
az container create \
  --resource-group $RG_NAME \
  --name mycontainer \
  --image mcr.microsoft.com/azure-cli \
  --assign-identity  --scope $RG_ID \
  --command-line "tail -f /dev/null"

# first law of engineering, don't turn anything on you don't know how to turn off
# az container delete --resource-group $RG_NAME --name mycontainer

az container show \
  --resource-group $RG_NAME \
  --name mycontainer

az container exec \
  --resource-group $RG_NAME \
  --name mycontainer \
  --exec-command "/bin/bash"
