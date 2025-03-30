// Main Bicep file to deploy the entire infrastructure

// Define Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-flask'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
  }
}

// Define Subnet separately
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'subnet-flask'
  parent: vnet
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
}


// Define Network Security Group (NSG) to restrict traffic
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-flask'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Associate NSG with the subnet
resource subnetNsgAssoc 'Microsoft.Network/subnets@2024-05-01' = {
  name: vnet.properties.subnets[0].name
  parent: vnet
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Deploy Log Analytics Workspace for monitoring
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'flask-app-logs'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Deploy Container Instance within the VNet and Subnet
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: 'flask-container'
  location: resourceGroup().location
  properties: {
    containers: [
      {
        name: 'flask-app'
        properties: {
          image: 'acrwlkiu3z7gd3m6.azurecr.io/flask-app:v1'
          ports: [
            {
              protocol: 'TCP'
              port: 80
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]
    }
    subnetIds: [ vnet.properties.subnets[0].id ]
    imageRegistryCredentials: [
      {
        server: 'acrwlkiu3z7gd3m6.azurecr.io'
        username: 'acrwlkiu3z7gd3m6'
        password: 'cWCgp9/jkpJU2pJBky0ZXghkASeU3p7Ra06XgOYhfj+ACRCMuST9'
      }
    ]
  }
}

// Configure diagnostic settings to send container logs to the workspace
resource containerDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'flask-container-diagnostics'
  scope: containerGroup
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'ContainerInstanceLog'
        enabled: true
      }
      {
        category: 'ContainerEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
