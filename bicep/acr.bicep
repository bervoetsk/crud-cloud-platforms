// Definieer een parameter voor de naam van de Azure Container Registry (ACR)
// De naam moet globaal uniek zijn, met een minimale lengte van 5 tekens en een maximale lengte van 50 tekens
@minLength(5)  // Minimum lengte van de naam
@maxLength(50)  // Maximale lengte van de naam
@description('Provide a globally unique name of your Azure Container Registry')  // Beschrijving van de parameter
param acrflask string = 'acr${uniqueString(resourceGroup().id)}'  // Genereer een unieke naam voor de ACR door de resourcegroep ID te gebruiken

// Definieer een parameter voor de locatie van de Azure Container Registry
@description('Provide a location for the registry.')  // Beschrijving van de parameter
param location string = resourceGroup().location  // Standaardlocatie is de locatie van de resourcegroep

// Definieer een parameter voor het tier (niveau) van de Azure Container Registry
@description('Provide a tier of your Azure Container Registry.')  // Beschrijving van de parameter
param acrSku string = 'Basic'  // Standaardinstelling voor het tier is 'Basic'

// Maak de Azure Container Registry aan met de opgegeven naam, locatie en tier
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrflask  // Gebruik de opgegeven naam voor de ACR
  location: location  // Gebruik de opgegeven locatie voor de ACR
  sku: {
    name: acrSku  // Gebruik het opgegeven tier voor de ACR
  }
  properties: {
    adminUserEnabled: false  // Admin-gebruikersaccount is uitgeschakeld voor deze registry
  }
}

// Toon de loginServer (de URL van de ACR) als uitvoer, zodat deze later kan worden gebruikt
@description('Output the login server property for later use')  // Beschrijving van de uitvoer
output loginServer string = acrResource.properties.loginServer  // Geef de loginServer URL van de ACR weer als uitvoer
