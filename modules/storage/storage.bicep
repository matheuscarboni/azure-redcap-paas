@description('Provide a name for the deployment. Optionally, leave an \'{rtype}\' placeholder, which will be replaced with the common resource abbreviation for storage.')
param deploymentNameStructure string



// // Blob Storage region
// resource storageName 'Microsoft.Storage/storageAccounts@2022-09-01' = {
//   name: uniqueStorageName
//   location: location
//   sku: {
//     name: storageType
//   }
//   tags: {
//     displayName: 'BackingStorage'
//   }
//   kind: 'StorageV2'
//   dependsOn: []
// }

// resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
//   name: 'default'
//   parent: storageName
// }

// resource storageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
//   name: storageContainerName
//   parent: blobServices
// }

// resource privateEndpointBlob 'Microsoft.Network/privateEndpoints@2022-07-01' = {
//   name: '${uniqueStorageName}-pe'
//   location: location
//   properties: {
//     subnet: {
//       id: redcapPrivateLinkSubnet.id
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${uniqueStorageName}-pe'
//         properties: {
//           privateLinkServiceId: storageName.id
//           groupIds: [
//             'blob'
//           ]
//         }
//       }
//     ]
//   }
// }

// resource privateDnsZoneGroupsBlob 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
//   name: 'privatednsgroupblob'
//   parent: privateEndpointBlob
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'privatelink-blob'
//         properties: {
//           privateDnsZoneId: privateDnsZoneBlob.id
//         }
//       }
//     ]
//   }
// }

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
