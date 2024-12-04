# Testing Managed Identity Authentication

## Purpose
Few purposes:
1) Understand how to authenticate with a managed identity from a container instance
2) Experiment with AzureHound `config` and `rest` modifications that add support for managed identity authentication.
3) Provide a scaffold that holds documentation, code and tests.

## Setup
- We will test this with a container instance running golang code.
- However we could have just as easily set up a container instance and then
run [bash / curl commands](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-managed-identity#use-user-assigned-identity-to-get-secret-from-key-vault)
to test the managed identity authentication.


## Notes / Finding


## Resources

[Container Instance Managed Identity](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-managed-identity)

  - Uses same authentication mechanism as with a VM
  - [GOLANG Example using REST API](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/how-to-use-vm-token#get-a-token-using-go)

### Az cli stuff

[create resource group](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-cli)

[container stuff](https://learn.microsoft.com/en-us/cli/azure/container?view=azure-cli-latest)
