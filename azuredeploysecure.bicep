param environment string
param workloadName string
param namingConvention string = '{wloadname}-{env}-{rtype}-{loc}-{seq}'
param deploymentTime string = utcNow()
param location string = resourceGroup().location
param sequence int = 1

param baseTime string = utcNow('u')
@description('Name of the virtual network to be created. If blank, the name will be generated from the namingStructure parameter.')
param vNetName string = ''

@description('Name of azure web app')
param siteName string

@description('Stack settings')
param linuxFxVersion string = 'php|7.4'

@description('Database administrator login name')
@minLength(1)
param administratorLogin string = 'redcap_app'

@description('Database administrator password')
@minLength(8)
@secure()
param administratorLoginPassword string

@description('REDCap zip file URI.')
param redcapAppZip string = ''

@description('REDCap Community site username for downloading the REDCap zip file.')
param redcapCommunityUsername string

@description('REDCap Community site password for downloading the REDCap zip file.')
@secure()
param redcapCommunityPassword string

@description('REDCap zip file version to be downloaded from the REDCap Community site.')
param redcapAppZipVersion string = 'latest'

@description('Email address configured as the sending address in REDCap')
param fromEmailAddress string

@description('Fully-qualified domain name of your SMTP relay endpoint')
param smtpFQDN string

@description('Login name for your SMTP relay')
param smtpUser string

@description('Login password for your SMTP relay')
@secure()
param smtpPassword string

@description('Port for your SMTP relay')
param smtpPort string = '587'

@description('Describes plan\'s pricing tier and capacity - this can be changed after deployment. Check details at https://azure.microsoft.com/en-us/pricing/details/app-service/')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
  'P1v3'
  'P2v3'
  'P3v3'
])
param skuName string = 'S1'

@description('Describes plan\'s instance count (how many distinct web servers will be deployed in the farm) - this can be changed after deployment')
@minValue(1)
param skuCapacity int = 1

@description('Initial MySQL database storage size in GB ')
param databaseStorageSizeGB int = 32

@description('Initial MySQL databse storage IOPS')
param databaseStorageIops int = 396

@allowed([
  'Enabled'
  'Disabled'
])
param databaseStorageAutoGrow string = 'Enabled'

@allowed([
  'Enabled'
  'Disabled'
])
param databseStorageAutoIoScaling string = 'Enabled'

@description('MySQL version')
@allowed([
  '5.6'
  '5.7'
])
param mysqlVersion string = '5.7'

@description('The default selected is \'Locally Redundant Storage\' (3 copies in one region). See https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy for more information.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Premium_LRS'
])
param storageType string = 'Standard_LRS'

@description('Name of the container used to store backing files in the new storage account. This container is created automatically during deployment.')
param storageContainerName string = 'redcap'

param vmAdminUserName string
@secure()
param vmAdminPassword string
param vmSku string = 'Standard_D4s_v4'
param vmDiskType string = 'Standard_LRS'
param vmDiskCachingType string = 'ReadWrite'

@description('The path to the deployment source files on GitHub')
param repoURL string = 'https://github.com/microsoft/azure-redcap-paas.git'

@description('The main branch of the application repo')
param branch string = 'main'

@description('The username of a domain user or service account to use to join the Active Directory domain.')
param domainJoinUsername string
@secure()
@description('The password of the domain user or service account to use to join the Active Directory domain.')
param domainJoinPassword string

@description('The fully qualified DNS name of the Active Directory domain to join.')
param adDomainFqdn string
@description('Optional. The OU path in LDAP notation to use when joining the session hosts.')
param adOuPath string = ''

// Optional parameters
var virtualNetworkName = !empty(vNetName) ? vNetName : replace(namingStructure, '{rtype}', 'vnet')
param tags object = {}
var deploymentNameStructure = '${workloadName}-${environment}-{rtype}-${deploymentTime}'
var sequenceFormatted = format('{0:00}', sequence)
// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)
param vnetAddressPrefix string = '10.0.{octet3}.0'
param vnetCidr string = '16'
param subnetCidr string = '24'
var siteNameCleaned = replace(siteName, ' ', '')
var databaseName = '${siteNameCleaned}_db'
var uniqueServerName = '${siteNameCleaned}${uniqueString(resourceGroup().id)}'
var hostingPlanNameCleaned = '${siteNameCleaned}_serviceplan'
var uniqueWebSiteName = '${siteNameCleaned}${uniqueString(resourceGroup().id)}'
var uniqueStorageName = 'storage${uniqueString(resourceGroup().id)}'
var uniqueFileShareStorageAccountName = 'fsrc${uniqueString(resourceGroup().id)}'
var keyVaultName = 'kv${uniqueString(resourceGroup().id)}'
// Assumed to be the same between both cloud environments
// Latest as of 2023-05-10
var configurationFileName = 'Configuration_01-19-2023.zip'

var artifactsLocation = 'https://wvdportalstorageblob.blob.${az.environment().suffixes.storage}/galleryartifacts/${configurationFileName}'

/*
  Object Schema
  NameOfSubnet: {
    addressPrefix: string (required)
    serviceEndpoints: array (optional)
    securityRules: array (optional; if ommitted, no NSG will be created. If [], a default NSG will be created.)
    routes: array (optional; if ommitted, no route table will be created. If [], an empty route table will be created.)
    delegation: string (optional, can be ommitted or be empty string)
  }
*/
var subnetsToDeploy = {
  ComputeSubnet: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '0')}/${subnetCidr}'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ]
    // Specify an empty array of security rules. Network security group for this subnet will be created, but only contain default rules.
    securityRules: []
    // Omit the delegation property here
    //delegation: ''
    // Create an empty route table
    routes: []
  }
  IntegrationSubnet: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '1')}/${subnetCidr}'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.Web'
        locations: [
          location
        ]
      }
    ]
    // Specify an empty array of security rules. Network security group for this subnet will be created, but only contain default rules.
    securityRules: []
    // Delegate this subnet to App Service
    delegation: 'Microsoft.Web/serverFarms'
    // Omit the routes property here
    // routes: []
  }
  MySqlSubnet: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '3')}/${subnetCidr}'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
    ]
    // Specify an empty array of security rules. Network security group for this subnet will be created, but only contain default rules.
    securityRules: []
    delegation: 'Microsoft.DBforMySQL/flexibleServers'
    // Create an empty route table
    routes: []
  }
  PrivateLinkSubnet: {
    addressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '2')}/${subnetCidr}'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
        locations: [
          location
        ]
      }
      {
        service: 'Microsoft.KeyVault'
        locations: [
          location
        ]
      }
    ]
    // Specify an empty array of security rules. Network security group for this subnet will be created, but only contain default rules.
    securityRules: []
    // Omit the delegation property here
    //delegation: ''
    // Create an empty route table
    routes: []
  }
}

var privateDnsZones = {
  BlobDnsZone: {
    name: 'privatelink.blob.${az.environment().suffixes.storage}'
    // Global location is the only option available
    location: 'global'
  }
  FileShareDnsZone: {
    name: 'privatelink.files.${az.environment().suffixes.storage}'
    // Global location is the only option available
    location: 'global'
  }
  KeyVaultDnsZone: {
    // Unable to leverage the az.environment().suffixes here
    name: 'privatelink.vaultcore.azure.net'
    // Global location is the only option available
    location: 'global'
  }
}

var mySqlSecretName = 'mysql-password'
var storageSecretName = 'storage-key'
var connectionStringSecretName = 'connection-string'
var redcaAppZipSecretName = 'redcap-zipfile'
var redcapUsernameSecretName = 'redcap-username'
var redcapPasswordSecretName = 'redcap-password'

var avdRegistrationExpiriationDate = dateTimeAdd(baseTime, 'PT24H')
var AVDnumberOfInstances = 1

module networkModule 'modules/networking/network.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'network'), 64)
  scope: resourceGroup()
  params: {
    vnetName: virtualNetworkName
    deploymentNameStructure: deploymentNameStructure
    namingStructure: namingStructure
    location: location
    tags: tags
    subnetDefs: subnetsToDeploy
    privateDnsZones: privateDnsZones
    vnetAddressPrefix: '${replace(vnetAddressPrefix, '{octet3}', '0')}/${vnetCidr}'
  }
}

module storageModule 'modules/storage/storage.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'storage'), 64)
  scope: resourceGroup()
  params: {
    deploymentNameStructure: deploymentNameStructure
    location: location
    tags: tags
    subnetDefs: subnetsToDeploy
    storageContainerName: storageContainerName
    storageType: storageType
    uniqueStorageName: uniqueStorageName
    privateDnsZones: privateDnsZones
  }
  dependsOn:[
    networkModule
  ]
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
// 




// // App Service region

// resource hostingPlanName 'Microsoft.Web/serverfarms@2022-09-01' = {
//   name: hostingPlanNameCleaned
//   location: location
//   tags: {
//     displayName: 'HostingPlan'
//   }
//   sku: {
//     name: skuName
//     capacity: skuCapacity
//   }
//   kind: 'linux'
//   properties: {
//     name: hostingPlanNameCleaned
//     reserved: true
//   }
// }

// resource webSiteName 'Microsoft.Web/sites@2022-09-01' = {
//   name: uniqueWebSiteName
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
//   tags: {
//     displayName: 'WebApp'
//   }
//   properties: {
//     name: uniqueWebSiteName
//     serverFarmId: hostingPlanNameCleaned
//     virtualNetworkSubnetId: redcapIntegrationSubnet.id
//     siteConfig: {
//       linuxFxVersion: linuxFxVersion
//       alwaysOn: true
//       appCommandLine: '/home/startup.sh'
//       appSettings: [
//         {
//           name: 'StorageContainerName'
//           value: storageContainerName
//         }
//         {
//           name: 'StorageAccount'
//           value: uniqueStorageName
//         }
//         {
//           name: 'StorageKey'
//           value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${storageSecretName})'
//         }
//         {
//           name: 'redcapAppZip'
//           value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${redcaAppZipSecretName})'
//         }
//         {
//           name: 'redcapCommunityUsername'
//           value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${redcapUsernameSecretName})'
//         }
//         {
//           name: 'redcapCommunityPassword'
//           value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${redcapPasswordSecretName})'
//         }
//         {
//           name: 'redcapAppZipVersion'
//           value: redcapAppZipVersion
//         }
//         {
//           name: 'DBHostName'
//           value: '${uniqueServerName}.mysql.database.azure.com'
//         }
//         {
//           name: 'DBName'
//           value: databaseName
//         }
//         {
//           name: 'DBUserName'
//           value: administratorLogin
//         }
//         {
//           name: 'DBPassword'
//           value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${mySqlSecretName})'
//         }
//         {
//           name: 'DBSslCa'
//           value: '/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem'
//         }
//         {
//           name: 'PHP_INI_SCAN_DIR'
//           value: '/usr/local/etc/php/conf.d:/home/site'
//         }
//         {
//           name: 'from_email_address'
//           value: fromEmailAddress
//         }
//         {
//           name: 'smtp_fqdn_name'
//           value: smtpFQDN
//         }
//         {
//           name: 'smtp_port'
//           value: smtpPort
//         }
//         {
//           name: 'smtp_user_name'
//           value: smtpUser
//         }
//         {
//           name: 'smtp_password'
//           value: smtpPassword
//         }
//         {
//           name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
//           value: '1'
//         }
//       ]
//       defaultDocuments: [
//         'index.php'
//         'Default.htm'
//         'Default.html'
//         'Default.asp'
//         'index.htm'
//         'index.html'
//         'iisstart.htm'
//         'default.aspx'
//         'hostingstart.html'
//       ]
//       ipSecurityRestrictions: [
//         // TODO
//         // {
//         //   name: 'AllowClientIp'
//         //   action: 'Allow'
//         //   priority: 050
//         //   ipAddress: '\${data.http.ifconfig.body}/32'
//         // }
//         // TODO - AzureFrontDoor.Backend service tag
//         // {
//         //     name: 'AllowFrontDoor'
//         //     action: 'Allow'
//         //     priority: 100
//         //     tag: 'ServiceTag'
//         //     ipAddress: ''
//         // }
//         {
//           name: 'AllowIntegrationSubnet'
//           action: 'Allow'
//           priority: 200
//           vnetSubnetResourceId: redcapIntegrationSubnet.id
//         }
//         {
//           name: 'AllowComputeSubnet'
//           action: 'Allow'
//           priority: 300
//           vnetSubnetResourceId: redcapComputeSubnet.id
//         }
//       ]
//       scmIpSecurityRestrictions: [
//         // TODO
//         // {
//         //   name: 'AllowClientIp'
//         //   action: 'Allow'
//         //   priority: 050
//         //   ipAddress: '\${data.http.ifconfig.body}/32'
//         // }
//         {
//           name: 'AllowVNET'
//           action: 'Allow'
//           priority: 100
//           vnetSubnetResourceId: redcapComputeSubnet.id
//         }
//       ]
//       connectionStrings: [
//         {
//           name: 'defaultConnection'
//           type: 'MySql'
//           connectionString: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${connectionStringSecretName})'
//         }
//       ]
//     }
//   }
//   dependsOn: [
//     hostingPlanName
//     storageName
//   ]
// }

// resource websiteConfigLog 'Microsoft.Web/sites/config@2022-03-01' = {
//   name: 'logs'
//   parent: webSiteName
//   properties: {
//     applicationLogs: {
//       fileSystem: {
//         level: 'Off'
//       }
//     }
//     detailedErrorMessages: {
//       enabled: true
//     }
//     failedRequestsTracing: {
//       enabled: true
//     }
//     httpLogs: {
//       fileSystem: {
//         enabled: true
//         retentionInDays: 7
//         retentionInMb: 100
//       }
//     }
//   }
// }

// resource webSiteName_web 'Microsoft.Web/sites/sourcecontrols@2022-09-01' = {
//   parent: webSiteName
//   name: 'web'
//   location: location
//   tags: {
//     displayName: 'CodeDeploy'
//   }
//   properties: {
//     repoUrl: repoURL
//     branch: branch
//     isManualIntegration: true
//   }
//   dependsOn: [
//     serverName
//   ]
// }

// // Key Vault and secrets region
// resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
//   name: keyVaultName
//   location: location
//   properties: {
//     enabledForDiskEncryption: true
//     enabledForTemplateDeployment: true
//     tenantId: tenant().tenantId
//     enableSoftDelete: true
//     softDeleteRetentionInDays: 90
//     sku: {
//       name: 'standard'
//       family: 'A'
//     }
//     accessPolicies: [
//       {
//         // TODO pass in current user principal ID via deployment script
//         tenantId: tenant().tenantId
//         objectId: webSiteName.identity.principalId
//         permissions: {
//           certificates: [
//             'all'
//           ]
//           keys: [
//             'backup'
//             'create'
//             'decrypt'
//             'delete'
//             'encrypt'
//             'get'
//             'import'
//             'list'
//             'purge'
//             'recover'
//             'restore'
//             'sign'
//             'unwrapKey'
//             'update'
//             'verify'
//             'wrapKey'
//           ]
//           secrets: [
//             'backup'
//             'delete'
//             'get'
//             'list'
//             'purge'
//             'recover'
//             'restore'
//             'set'
//           ]
//           storage: [
//             'backup'
//             'delete'
//             'deletesas'
//             'get'
//             'getsas'
//             'list'
//             'listsas'
//             'purge'
//             'recover'
//             'regeneratekey'
//             'restore'
//             'set'
//             'setsas'
//             'update'
//           ]
//         }
//       }
//       {
//         tenantId: tenant().tenantId
//         objectId: webSiteName.identity.principalId
//         permissions: {
//           certificates: [
//             'get'
//             'list'
//           ]
//           secrets: [
//             'get'
//             'list'
//           ]
//         }
//       }
//     ]
//     networkAcls: {
//       defaultAction: 'Allow'
//       bypass: 'AzureServices'
//       // TODO data.http.ifconfig.body
//       // ipRules: [
//       //   {
//       //     value: 'string'
//       //   }
//       // ]
//       virtualNetworkRules: [
//         {
//           id: redcapPrivateLinkSubnet.id
//         }
//         {
//           id: redcapComputeSubnet.id
//         }
//         {
//           id: redcapIntegrationSubnet.id
//         }
//         {
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
// }

// resource secretMySql 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: mySqlSecretName
//   properties: {
//     value: administratorLoginPassword
//   }
//   dependsOn: []
// }

// resource secretStorage 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: storageSecretName
//   properties: {
//     value: storageName.listKeys().keys[0].value
//   }
//   dependsOn: []
// }

// resource secretConnectionString 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: connectionStringSecretName
//   properties: {
//     value: 'Database=${databaseName};Data Source=${uniqueServerName}.mysql.database.azure.com;User Id=${administratorLogin}@mysql-${uniqueServerName};Password=${administratorLoginPassword}'
//   }
//   dependsOn: []
// }

// resource secretRCZip 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: redcaAppZipSecretName
//   properties: {
//     value: redcapAppZip
//   }
//   dependsOn: []
// }

// resource secretRCUser 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: redcapUsernameSecretName
//   properties: {
//     value: redcapCommunityUsername
//   }
//   dependsOn: []
// }

// resource secretRCPass 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
//   parent: keyVault
//   name: redcapPasswordSecretName
//   properties: {
//     value: redcapCommunityPassword
//   }
//   dependsOn: []
// }

// resource privateEndpointKeyVault 'Microsoft.Network/privateEndpoints@2022-07-01' = {
//   name: '${keyVaultName}-pe'
//   location: location
//   properties: {
//     subnet: {
//       id: redcapPrivateLinkSubnet.id
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${keyVaultName}-pe'
//         properties: {
//           privateLinkServiceId: keyVault.id
//           groupIds: [
//             'vault'
//           ]
//         }
//       }
//     ]
//   }
// }

// resource privateDnsZoneGroupsKeyVault 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
//   name: 'privatednszonegroupkeyvault'
//   parent: privateEndpointKeyVault
//   properties: {
//     privateDnsZoneConfigs: [
//       {
//         name: 'privatelink-keyvault'
//         properties: {
//           privateDnsZoneId: privateDnsZoneKeyVault.id
//         }
//       }
//     ]
//   }
// }

// // MySql Flex Region

// resource serverName 'Microsoft.DBforMySQL/flexibleServers@2021-12-01-preview' = {
//   location: location
//   name: uniqueServerName
//   tags: {
//     displayName: 'MySQLAzure'
//   }
//   properties: {
//     version: mysqlVersion
//     administratorLogin: administratorLogin
//     administratorLoginPassword: administratorLoginPassword
//     storage: {
//       storageSizeGB: databaseStorageSizeGB
//       iops: databaseStorageIops
//       autoGrow: databaseStorageAutoGrow
//       autoIoScaling: databseStorageAutoIoScaling
//     }
//     network: {
//       delegatedSubnetResourceId: redcapSqlSubnet.id
//     }
//     backup: {
//       backupRetentionDays: 7
//       geoRedundantBackup: 'Disabled'
//     }
//     highAvailability: {
//       mode: 'Disabled'
//     }
//     replicationRole: 'None'
//   }
//   sku: {
//     name: 'Standard_B1ms'
//     tier: 'Burstable'
//   }
//   dependsOn: []
// }

// resource serverName_AllowAzureIPs 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2021-12-01-preview' = {
//   parent: serverName
//   name: 'AllowAzureIPs'
//   properties: {
//     startIpAddress: '0.0.0.0'
//     endIpAddress: '0.0.0.0'
//   }
//   dependsOn: [
//     serverName_databaseName
//   ]
// }

// resource serverName_databaseName 'Microsoft.DBforMySQL/flexibleServers/databases@2021-12-01-preview' = {
//   parent: serverName
//   name: databaseName
//   properties: {
//     charset: 'utf8'
//     collation: 'utf8_general_ci'
//   }
// }

// // Azure Virtual Desktop and Session Hosts region

// resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' = {
//   name: 'hp-${siteNameCleaned}'
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
//   managedBy: 'string'
//   properties: {
//     preferredAppGroupType: 'Desktop'
//     description: 'REDCap AVD host pool for remote app and remote desktop services'
//     friendlyName: 'REDCap Host Pool'
//     hostPoolType: 'Pooled'
//     loadBalancerType: 'BreadthFirst'
//     maxSessionLimit: 999999
//     registrationInfo: {
//       expirationTime: avdRegistrationExpiriationDate
//     }
//     validationEnvironment: false
//   }
// }

// resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2022-10-14-preview' = {
//   name: 'dag-${siteNameCleaned}'
//   location: location
//   properties: {
//     applicationGroupType: 'Desktop'
//     description: 'Windpws 10 Desktops'
//     friendlyName: 'REDCap Workstation'
//     hostPoolArmPath: hostPool.id
//   }
// }

// resource avdWorkspace 'Microsoft.DesktopVirtualization/workspaces@2022-10-14-preview' = {
//   name: 'ws-${siteNameCleaned}'
//   location: location
//   properties: {
//     applicationGroupReferences: [
//       applicationGroup.id
//     ]
//     description: 'Session desktops'
//     friendlyName: 'REDCAP Workspace'
//   }
// }

// resource nic 'Microsoft.Network/networkInterfaces@2020-06-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'nic-redcap-${i}'
//   location: location
//   properties: {
//     ipConfigurations: [
//       {
//         name: 'ipconfig'
//         properties: {
//           privateIPAllocationMethod: 'Dynamic'
//           subnet: {
//             id: redcapComputeSubnet.id
//           }
//         }
//       }
//     ]
//   }
// }]

// resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'vm-redcap-${i}'
//   location: location
//   properties: {
//     licenseType: 'Windows_Client'
//     hardwareProfile: {
//       vmSize: vmSku
//     }
//     osProfile: {
//       computerName: 'vm-redcap-${i}'
//       adminUsername: vmAdminUserName
//       adminPassword: vmAdminPassword
//       windowsConfiguration: {
//         enableAutomaticUpdates: false
//         patchSettings: {
//           patchMode: 'Manual'
//         }
//       }
//     }
//     storageProfile: {
//       osDisk: {
//         name: 'vm-OS-${i}'
//         caching: vmDiskCachingType
//         managedDisk: {
//           storageAccountType: vmDiskType
//         }
//         osType: 'Windows'
//         createOption: 'FromImage'
//       }
//       // TODO Turn into params
//       imageReference: {
//         publisher: 'microsoftwindowsdesktop'
//         offer: 'office-365'
//         sku: '20h2-evd-o365pp'
//         version: 'latest'
//       }
//       dataDisks: []
//     }
//     networkProfile: {
//       networkInterfaces: [
//         {
//           id: nic[i].id
//         }
//       ]
//     }
//   }
//   dependsOn: [
//     nic[i]
//   ]
// }]

// // Reference https://github.com/Azure/avdaccelerator/blob/e247ec5d1ba5fac0c6e9f822c4198c6b41cb77b4/workload/bicep/modules/avdSessionHosts/deploy.bicep#L162
// // Needed to get the hostpool in order to pass registration info token, else it comes as null when usiung
// // registrationInfoToken: hostPool.properties.registrationInfo.token
// // Workaround: reference https://github.com/Azure/bicep/issues/6105
// // registrationInfoToken: reference(getHostPool.id, '2021-01-14-preview').registrationInfo.token - also does not work
// resource getHostPool 'Microsoft.DesktopVirtualization/hostPools@2019-12-10-preview' existing = {
//   name: hostPool.name
// }

// // Deploy the AVD agents to each session host
// resource avdAgentDscExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'AvdAgentDSC'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Powershell'
//     type: 'DSC'
//     typeHandlerVersion: '2.73'
//     autoUpgradeMinorVersion: true
//     settings: {
//       modulesUrl: artifactsLocation
//       configurationFunction: 'Configuration.ps1\\AddSessionHost'
//       properties: {
//         hostPoolName: hostPool.name
//         registrationInfoToken: getHostPool.properties.registrationInfo.token
//         aadJoin: false
//       }
//     }
//   }
//   dependsOn: [
//     getHostPool
//   ]
// }]

// resource domainJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'DomainJoin'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'JsonADDomainExtension'
//     typeHandlerVersion: '1.3'
//     autoUpgradeMinorVersion: true
//     settings: {
//       name: adDomainFqdn
//       ouPath: adOuPath
//       user: domainJoinUsername
//       restart: 'true'
//       options: '3'
//     }
//     protectedSettings: {
//       password: domainJoinPassword
//     }
//   }
//   dependsOn: [
//     avdAgentDscExtension[i]
//   ]
// }]

// resource dependencyAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'DAExtension'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
//     type: 'DependencyAgentWindows'
//     typeHandlerVersion: '9.5'
//     autoUpgradeMinorVersion: true
//   }
// }]

// resource antiMalwareExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'IaaSAntiMalware'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Azure.Security'
//     type: 'IaaSAntimalware'
//     typeHandlerVersion: '1.5'
//     autoUpgradeMinorVersion: true
//     settings: {
//       AntimalwareEnabled: true
//     }
//   }
// }]

// resource ansibleExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = [for i in range(0, AVDnumberOfInstances): {
//   name: 'AnsibleWinRM'
//   parent: vm[i]
//   location: location
//   properties: {
//     publisher: 'Microsoft.Compute'
//     type: 'CustomScriptExtension'
//     typeHandlerVersion: '1.10'
//     autoUpgradeMinorVersion: true
//     settings: {
//       fileUris: [ 'https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1' ]
//     }
//     protectedSettings: {
//       commandToExecute: 'powershell.exe -Command \'./ConfigureRemotingForAnsible.ps1; exit 0;\''
//     }
//   }
// }]

// output MySQLHostName string = '${uniqueServerName}.mysql.database.azure.com'
// output MySqlUserName string = '${administratorLogin}@${uniqueServerName}'
// output webSiteFQDN string = '${uniqueWebSiteName}.azurewebsites.net'
// output storageAccountName string = uniqueStorageName
// output storageContainerName string = storageContainerName
