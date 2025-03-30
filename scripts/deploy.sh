```sh
#!/bin/bash

RESOURCE_GROUP="flask-app-rg"
LOCATION="eastus"

# Create the resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Deploy the Bicep template
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file bicep/main.bicep \
  --parameters location=$LOCATION
```