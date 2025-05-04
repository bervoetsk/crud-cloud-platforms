// Definieer het Virtuele Netwerk (VNet) voor de applicatie
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
    name: 'vnet-flask'  // Naam van het virtuele netwerk
    location: resourceGroup().location  // Locatie van het netwerk, gebaseerd op de resourcegroep
    properties: {
      addressSpace: {
        addressPrefixes: ['10.0.0.0/16']  // Definieer het adresbereik voor het netwerk
      }
      subnets: [  // Definieer de subnets binnen het virtuele netwerk
        {
          name: 'subnet-flask'  // Naam van het eerste subnet
          properties: {
            addressPrefix: '10.0.1.0/24'  // Het adresbereik voor dit subnet
            delegations: [  // Delegaties voor dit subnet
              {
                name: 'delegatie'  // Naam van de delegatie
                properties: {
                  serviceName: 'Microsoft.ContainerInstance/containerGroups'  // De service waarvoor dit subnet gedelegeerd is (Container Instance)
                }
              }
            ]
          }
        }
        {
          name: 'subnet-appgw'  // Naam van het tweede subnet (voor de Application Gateway)
          properties: {
            addressPrefix: '10.0.2.0/24'  // Het adresbereik voor dit subnet
          }
        }
      ]
    }
  }
  
  // Referentie naar het Flask-subnet binnen het virtuele netwerk
  resource subnetFlask 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
    parent: vnet  // Verbind met het eerder gedefinieerde virtuele netwerk
    name: 'subnet-flask'  // Naam van het Flask-subnet
  }
  
  // Referentie naar het subnet voor de Application Gateway
  resource subnetAppGw 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
    parent: vnet  // Verbind met het virtuele netwerk
    name: 'subnet-appgw'  // Naam van het subnet voor de Application Gateway
  }
  
  // Definieer de Container Groep voor de Flask-applicatie
  resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
    name: 'flask-container'  // Naam van de container groep
    location: resourceGroup().location  // Locatie van de container groep
    properties: {
      containers: [  // Container definities binnen de groep
        {
          name: 'flask-app'  // Naam van de container
          properties: {
            image: 'acrs6amnrp4ma7qw.azurecr.io/flask-app:v1'  // Docker-image van de Flask-app
            ports: [
              {
                protocol: 'TCP'  // Gebruik TCP voor de verbinding
                port: 80  // Poort 80 voor toegang
              }
            ]
            resources: {
              requests: {
                cpu: 1  // Verzoek om 1 CPU-kern voor de container
                memoryInGB: 2  // Verzoek om 2 GB geheugen voor de container
              }
            }
          }
        }
      ]
      osType: 'Linux'  // Het besturingssysteem voor de container (Linux)
      ipAddress: {
        type: 'Private'  // Gebruik een privé IP-adres
        ports: [
          {
            protocol: 'TCP'  // Gebruik TCP voor de verbinding
            port: 80  // Poort 80 voor toegang
          }
        ]
      }
      subnetIds: [
        {
          id: subnetFlask.id  // Verbind de container groep met het Flask-subnet
          name: 'default'  // Standaardnaam voor het subnet
        }
      ]
      imageRegistryCredentials: [  // Inloggegevens voor de Docker-registry
        {
          server: 'acrs6amnrp4ma7qw.azurecr.io'  // Server van de Docker-registry
          username: 'acrs6amnrp4ma7qw'  // Gebruikersnaam voor de registry
          password: 'FP66smGvfkSjjrHuMS6JKbo/hwcR3M1Eedt7LyrfIs+ACRAdS30e'  // Wachtwoord voor de registry (zorg ervoor dat deze veilig wordt behandeld)
        }
      ]
    }
  }
  
  // Definieer een Public IP voor de Application Gateway
  resource publicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
    name: 'appgw-pip'  // Naam van het publieke IP-adres
    location: resourceGroup().location  // Locatie van het publieke IP
    sku: {
      name: 'Standard'  // Type SKU voor het publieke IP
    }
    properties: {
      publicIPAllocationMethod: 'Static'  // Het IP-adres is statisch
      dnsSettings: {
        domainNameLabel: 'flask-app-${uniqueString(resourceGroup().id)}'  // DNS-label voor de publieke IP, uniek per resourcegroep
      }
    }
  }
  
  // Definieer de Application Gateway
  resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
    name: 'flask-appgw'  // Naam van de Application Gateway
    location: resourceGroup().location  // Locatie van de Application Gateway
    properties: {
      sku: {
        name: 'Standard_v2'  // SKU van de gateway
        tier: 'Standard_v2'  // Het type niveau van de gateway
        capacity: 2  // Capaciteit van de gateway (aantal instanties)
      }
      gatewayIPConfigurations: [
        {
          name: 'appGatewayIpConfig'  // Naam van de IP-configuratie van de gateway
          properties: {
            subnet: {
              id: subnetAppGw.id  // Verbind de gateway met het subnet van de Application Gateway
            }
          }
        }
      ]
      frontendIPConfigurations: [
        {
          name: 'appGwPublicFrontendIp'  // Naam van de frontend IP-configuratie
          properties: {
            publicIPAddress: {
              id: publicIP.id  // Verbind met het eerder gedefinieerde publieke IP
            }
          }
        }
      ]
      frontendPorts: [
        {
          name: 'port_80'  // Naam van de frontendpoort
          properties: {
            port: 80  // Poort 80 voor HTTP-verkeer
          }
        }
      ]
      backendAddressPools: [
        {
          name: 'flaskBackendPool'  // Naam van de backend-pool voor de Flask-app
          properties: {
            backendAddresses: [
              {
                ipAddress: containerGroup.properties.ipAddress.ip  // Het IP-adres van de container (de Flask-app)
              }
            ]
          }
        }
      ]
      backendHttpSettingsCollection: [
        {
          name: 'flaskHttpSettings'  // Naam van de HTTP-instellingen voor de backend
          properties: {
            port: 80  // Poort 80 voor backend communicatie
            protocol: 'Http'  // HTTP-protocol
            cookieBasedAffinity: 'Disabled'  // Schakel cookie-gebaseerde affiniteit uit
            requestTimeout: 30  // Verzoektime-out van 30 seconden
            pickHostNameFromBackendAddress: false  // Gebruik geen hostnaam van het backendadres
          }
        }
      ]
      httpListeners: [
        {
          name: 'flaskHttpListener'  // Naam van de HTTP-luisteraar
          properties: {
            frontendIPConfiguration: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'flask-appgw', 'appGwPublicFrontendIp')  // Verbind met de frontend IP-configuratie
            }
            frontendPort: {
              id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'flask-appgw', 'port_80')  // Verbind met de frontendpoort
            }
            protocol: 'Http'  // HTTP-protocol
          }
        }
      ]
      requestRoutingRules: [
        {
          name: 'flaskRoutingRule'  // Naam van de routeringsregel
          properties: {
            ruleType: 'Basic'  // Basis routeringsregel
            priority: 100  // Prioriteit van de regel
            httpListener: {
              id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'flask-appgw', 'flaskHttpListener')  // Verbind met de HTTP-luisteraar
            }
            backendAddressPool: {
              id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'flask-appgw', 'flaskBackendPool')  // Verbind met de backend-pool
            }
            backendHttpSettings: {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'flask-appgw', 'flaskHttpSettings')  // Verbind met de backend HTTP-instellingen
            }
          }
        }
      ]
    }
  }
  
  // Toon de URL voor toegang tot de Flask-app
  output flaskAppUrl string = 'http://${publicIP.properties.dnsSettings.fqdn}'  // Publiceer de volledige URL van de Flask-app via het publieke IP
