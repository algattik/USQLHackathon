$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

#region Create ADLS and ADLA resources
Write-Host "Create a Data Lake Saccount ..."  -ForegroundColor Green
New-AzureRmDataLakeStoreAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $dataLakeStoreName `
    -Location $location

#wait for provisioning completed
assertWithTimeout -block {
    Get-AzureRmDataLakeStoreAccount | ? {$_.Name -eq $dataLakeStoreName -and $_.Properties.State -eq "Active"}
}


Write-Host "Create a Data Lake Analytics account ..."  -ForegroundColor Green
New-AzureRmDataLakeAnalyticsAccount `
    -Name $dataLakeAnalyticsName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -DefaultDataLake $dataLakeStoreName

#wait for provisioning completed
assertWithTimeout -block {
    Get-AzureRmDataLakeAnalyticsAccount | ? {$_.Name -eq $dataLakeAnalyticsName -and $_.Properties.State -eq "Active"}
}

Write-Host "The newly created Data Lake Analytics account ..."  -ForegroundColor Green
Get-AzureRmDataLakeAnalyticsAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $dataLakeAnalyticsName  

assertWithTimeout -block {
       $acc=Get-AzureRmDataLakeAnalyticsAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAnalyticsName
       Write-Host ( Out-String -InputObject $acc.Properties)
       $acc.Properties.State -eq 'Active'
}
#endregion


#region - upload sample source data
# Upload the file to the default Data Lake Store account    
Import-AzureRmDataLakeStoreItem -AccountName $dataLakeStoreName -Path "$scriptDir\..\Samples" -Destination "/Samples" -Force -Recurse
Write-Host "List the source data ..."  -ForegroundColor Green
Get-AzureRmDataLakeStoreChildItem -Account $dataLakeStoreName -Path  "/Samples/Data/"
#endregion

# Upload and register assemblies
$assemblyDir="$scriptDir\..\Resources\ADLA-JSON-Assembly"
Import-AzureRmDataLakeStoreItem -AccountName $dataLakeStoreName -Path $assemblyDir -Destination "/Assemblies" -Force -Recurse

$j=Submit-AzureRmDataLakeAnalyticsJob -Account $dataLakeAnalyticsName `
    -Name "register assemblies" `
    -Script 'USE DATABASE [master];
CREATE ASSEMBLY [Newtonsoft.Json] FROM @"/Assemblies/Newtonsoft.Json/Newtonsoft.Json.dll";
CREATE ASSEMBLY [Microsoft.Analytics.Samples.Formats] FROM @"/Assemblies/Microsoft.Analytics.Samples.Formats/Microsoft.Analytics.Samples.Formats.dll";
'
waitAdlaJob $j

#endregion

#region Add additional storage account
# Obtain the Storage Account authentication keys
$Key = getStorageKey
Add-AzureRmDataLakeAnalyticsDataSource -ResourceGroupName $resourceGroupName -Account $dataLakeAnalyticsName -AzureBlob $storageAccountName -AccessKey $Key
#endregion





