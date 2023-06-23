param privateDnsZones object
param deploymentNameStructure string
param vnetName string


// This will sort the DNS zones alphabetically by name
var privateDnsZonesArray = items(privateDnsZones)

resource privateDnsZonesRes 'Microsoft.Network/privateDnsZones@2020-06-01' = [for privateDns in privateDnsZonesArray: {
  name: privateDns.value.name
  location: privateDns.value.location
}]

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
}

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' =  [for (privateDns,i) in privateDnsZonesArray: {
  name: take(replace(deploymentNameStructure, '{rtype}', 'dns-$(privateDns.key)'), 64)
  location: 'global'
  parent: privateDnsZonesRes[i]
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}]
