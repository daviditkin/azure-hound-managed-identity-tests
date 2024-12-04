az login

az group create --name myResourceGroup --location eastus

# Get the resource ID of the resource group
RG_ID=$(az group show --name myResourceGroup --query id --output tsv)

# Create container with system assigned managed identity
az container create \
  --resource-group myResourceGroup \
  --name mycontainer \
  --image mcr.microsoft.com/azure-cli \
  --assign-identity  --scope $RG_ID \
  --command-line "tail -f /dev/null"

# first law of engineering, don't turn anything on you don't know how to turn off
# az container delete --resource-group myResourceGroup --name mycontainer

az container show \
  --resource-group myResourceGroup \
  --name mycontainer

az container exec \
  --resource-group myResourceGroup \
  --name mycontainer \
  --exec-command "/bin/bash"
