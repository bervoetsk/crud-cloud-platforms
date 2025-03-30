// Define Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-flask'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'subnet-flask'
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
      {
        name: 'subnet-appgw'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// Reference to the subnets
resource subnetFlask 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'subnet-flask'
}

resource subnetAppGw 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'subnet-appgw'
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
        id: subnetFlask.id
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

// Public IP for Application Gateway
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'appgw-pip'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: 'flask-app-${uniqueString(resourceGroup().id)}'
    }
  }
}

// Application Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: 'flask-appgw'
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetAppGw.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'flaskBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: containerGroup.properties.ipAddress.ip
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'flaskHttpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
        }
      }
    ]
    httpListeners: [
      {
        name: 'flaskHttpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'flask-appgw', 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'flask-appgw', 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'flaskRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'flask-appgw', 'flaskHttpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'flask-appgw', 'flaskBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'flask-appgw', 'flaskHttpSettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    containerGroup
  ]
}

// Output the URL to access the Flask app
output flaskAppUrl string = 'http://${publicIP.properties.dnsSettings.fqdn}'
