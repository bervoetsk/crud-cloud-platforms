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

// Define Subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: 'subnet-flask'
  parent: vnet
  properties: {
    addressPrefix: '10.0.1.0/24'
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.ContainerInstance/containerGroups'
        }
      }
    ]
  }
}

// Define Container Group (Flask App)
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
      type: 'Private'
      ports: [
        {
          protocol: 'TCP'
          port: 80
        }
      ]
    }
    subnetIds: [
      {
        id: subnet.id
        name: 'default'
      }
    ]
    imageRegistryCredentials: [
      {
        server: 'acrwlkiu3z7gd3m6.azurecr.io'
        username: 'acrwlkiu3z7gd3m6'
        password: 'cWCgp9/jkpJU2pJBky0ZXghkASeU3p7Ra06XgOYhfj+ACRCMuST9'
      }
    ]
  }
}
