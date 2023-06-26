
$startTime=Get-Date
Write-Host "Beginning deployment at $starttime"

Import-Module Azure -ErrorAction SilentlyContinue
$version = 0;

#DEPLOYMENT OPTIONS
#Please review the azuredeploy.bicep file for available options
$RGName        = "rg-redcapbicep41"
$DeployRegion  = "eastus"

$parms = @{

    #Alternative to the zip file above, you can use REDCap Community credentials to download the zip file.
    "redcapCommunityUsername"     = "rcuser";
    "redcapCommunityPassword"     = "pass@word";
    "redcapAppZipVersion"         = "version1";

    #Mail settings
    "fromEmailAddress"            = "m@m.com";
    "smtpFQDN"                    = "smtpfqdn"
    "smtpUser"                    = "smtpuser"
    "smtpPassword"                = "smtpuserpass@word"

    #Azure Web App
    "siteName"                    = "rcsite";
    "skuName"                     = "S1";
    "skuCapacity"                 = 1;

    #MySQL
    "administratorLogin"          = "sqladmin";
    "administratorLoginPassword"  = "sqladminpass@word";

    # "databaseForMySqlCores"       = 2;
    # "databaseForMySqlFamily"      = "Gen5";
    # "databaseSkuSizeMB"           = 5120;
    # "databaseForMySqlTier"        = "GeneralPurpose";
    "mysqlVersion"                = "5.7";
    
    #Azure Storage
    "storageType"                 = "Standard_LRS";
    "storageContainerName"        = "redcap";

    #GitHub
    "repoURL"                     = "https://github.com/vanderbilt-redcap/redcap-azure.git";
    "branch"                      = "master";

    #AVD session hosts
    "vmAdminUserName"             = "vmvmadmin"
    "vmAdminPassword"             = "vmPass@word1234"

    #Domain join
    "domainJoinUsername"          = "domainuser"
    "domainJoinPassword"          = "domainpass@word"
    "adDomainFqdn"                = "adFQDN"


}
#END DEPLOYMENT OPTIONS

#ensure we're logged in
Get-AzContext -ErrorAction Stop

try {
    Get-AzResourceGroup -Name $RGName -ErrorAction Stop
    Write-Host "Resource group $RGName exists, updating deployment"
}
catch {
    $RG = New-AzResourceGroup -Name $RGName -Location $DeployRegion
    Write-Host "Created new resource group $RGName."
}
$version ++
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $RGName -TemplateParameterObject $parms -TemplateFile ".\azuredeploysecure.bicep" -Name "RedCAPDeploy$version"  -Force -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    $siteName = $deployment.Outputs.webSiteFQDN.Value
    start "https://$($siteName)/AzDeployStatus.php"
    Write-Host "---------"
    $deployment.Outputs | ConvertTo-Json

} else {
    $deperr = Get-AzResourceGroupDeploymentOperation -DeploymentName "RedCAPDeploy$version" -ResourceGroupName $RGName
    $deperr | ConvertTo-Json
}

$endTime=Get-Date

Write-Host ""
Write-Host "Total Deployment time:"
New-TimeSpan -Start $startTime -End $endTime | Select Hours, Minutes, Seconds
