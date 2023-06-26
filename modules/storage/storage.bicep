@description('Provide a name for the deployment. Optionally, leave an \'{rtype}\' placeholder, which will be replaced with the common resource abbreviation for storage.')
param deploymentNameStructure string
param location string
param tags object = {}
param subnetDefs object
param privateDnsZones object
param uniqueStorageName string
param storageType string
@description('Name of the container used to store backing files in the new storage account. This container is created automatically during deployment.')
param storageContainerName string

// This will sort the subnets alphabetically by name
var subnetDefsArray = items(subnetDefs)
var privateDnsZonesArray = items(privateDnsZones)

resource storageAccountBlob 'Microsoft.Storage/storageAccounts@2022-09-01' = {
    name: uniqueStorageName
    location: location
    sku: {
      name: storageType
    }
    tags: {
      displayName: 'BackingStorage'
    }
    kind: 'StorageV2'
  }


resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  name: 'default'
  parent: storageAccountBlob
}

resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
  name: storageContainerName
  parent: blobServices
}

resource privateLinkSubnetRes 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' existing = {
  name: subnetDefsArray[3].key
}

resource privateDnsZoneBlobRes 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZonesArray[0].key
}

resource privateEndpointBlob 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: '${uniqueStorageName}-pe'
  location: location
  properties: {
    subnet: {
      id: privateLinkSubnetRes.id
    }
    privateLinkServiceConnections: [
      {
        name: '${uniqueStorageName}-pe'
        properties: {
          privateLinkServiceId: storageAccountBlob.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroupsBlob 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  name: 'privatednsgroupblob'
  parent: privateEndpointBlob
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob'
        properties: {
          privateDnsZoneId: privateDnsZoneBlobRes.id
        }
      }
    ]
  }
}
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 



// // File Share region
// resource fileShareStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
//   name: uniqueFileShareStorageAccountName
//   location: location
//   sku: {
//     name: 'Premium_LRS'
//   }
//   tags: {
//     displayName: 'FileStorage'
//   }
//   kind: 'FileStorage'
//   properties: {
//     accessTier: 'Hot'
//     networkAcls: {
//       bypass: 'Logging,Metrics,AzureServices'
//       defaultAction: 'Deny'
//       // TODO data.http.ifconfig.body
//       // ipRules: [
//       //   {
//       //     action: 'Allow'
//       //     value: 'string'
//       //   }
//       // ]
//       virtualNetworkRules: [
//         {
//           action: 'Allow'
//           id: redcapPrivateLinkSubnet.id
//         }
//         {
//           action: 'Allow'
//           id: redcapComputeSubnet.id
//         }
//         {
//           action: 'Allow'
//           id: redcapIntegrationSubnet.id
//         }
//         {
//           action: 'Allow'
//           id: redcapSqlSubnet.id
//         }
//         // TODO Devops subnet id
//         // {
//         //   action: 'Allow'
//         //   id: ''
//         // }
//       ]
//     }
//   }
//   dependsOn: []
// }

// resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
//   name: 'default'
//   parent: fileShareStorageAccount
// }

// resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
//   name: storageContainerName
//   parent: fileServices
//   properties: {
//     accessTier: 'Premium'
//     shareQuota: 100
//   }
// }

// resource privateEndpointFileShare 'Microsoft.Network/privateEndpoints@2022-07-01' = {
//   name: '${uniqueFileShareStorageAccountName}-pe'
//   location: location
//   properties: {
//     subnet: {
//       id: redcapPrivateLinkSubnet.id
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${uniqueFileShareStorageAccountName}-pe'
//         properties: {
//           privateLinkServiceId: fileShareStorageAccount.id
//           groupIds: [
//             'file'
//           ]
//         }
//       }
//     ]
//   }
// }

// resource privateDnsZoneGroupsFileShare 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
//   name: 'privatednszonegroupfile'
//   parent: privateEndpointFileShare
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'privatelink-file'
//         properties: {
//           privateDnsZoneId: privateDnsZoneFileShare.id
//         }
//       }
//     ]
//   }
// }
