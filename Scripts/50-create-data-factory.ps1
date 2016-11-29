$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

#region

#if getting an error "The subscription is not registered to use namespace 'Microsoft.DataFactory'.",
#   run "Register-AzureRmResourceProvider -ProviderNamespace Microsoft.DataFactory"
New-AzureRmDataFactory -ResourceGroupName $resourceGroupName -Name $dataFactoryName -Location $dataFactoryLocation
$df=Get-AzureRmDataFactory -ResourceGroupName $resourceGroupName -Name $dataFactoryName 

#endregion

#region
$resDir="$scriptDir\..\Resources\ADF-ReferenceDataToBlob"

$temp=New-TemporaryFile

substituteInTemplate $resDir\AdvWorksLinkedService.json @{
    '$sqlName' = "$sqlName";
    '$dbName' = "$dbName";
    '$username' = "$username";
    '$password' = "$passwordString";
    } | Out-File $temp
New-AzureRmDataFactoryLinkedService -DataFactory $df -File $temp -Force
New-AzureRmDataFactoryDataset -DataFactory $df -File $resDir\AdvWorksCustomerDataset.json -Force


$storageKey = getStorageKey
substituteInTemplate $resDir\BlobLinkedService.json @{
    '$storageAccountName' = "$storageAccountName";
    '$storageKey' = "$storageKey";
    } | Out-File $temp
New-AzureRmDataFactoryLinkedService -DataFactory $df -File $temp -Force
New-AzureRmDataFactoryDataset -DataFactory $df -File $resDir\BlobCustomerDataset.json -Force

substituteInTemplate $resDir\AdvWorksToBlobPipeline.json @{
    '$today' = $today;
    }| Out-File $temp
New-AzureRmDataFactoryPipeline -DataFactory $df -File $temp -Force

#endregion

#region
$resDir2="$scriptDir\..\Resources\ADF-BlobToSqlDwInput"

$storageContext = getStorageContext
Set-AzureStorageBlobContent -Container "adf-resources" -File "$scriptDir\..\Resources\ADF-Resources\adla-ciam-to-sqldw.usql" -Context $storageContext -Force

$temp=New-TemporaryFile

$template=substituteInTemplate $resDir2\ADLALinkedService.json @{
    '$dataLakeAnalyticsName' = "$dataLakeAnalyticsName";
    }
    
Write-Host "Provision manually the following LinkedService (Go to Data Factory, Author and Deploy, ...More, New compute," -ForegroundColor Cyan
Write-Host "   Azure Data Lake Analytics, then copy-paste the JSON below, and Authorize and Deploy it): " -ForegroundColor Cyan
Write-Host $template -ForegroundColor cyan
assertWithTimeout -block {
    Get-AzureRmDataFactoryLinkedService -DataFactory $df | ? {$_.LinkedServiceName -eq "ADLALinkedService" -and $_.ProvisioningState -eq "Succeeded" }
}
Write-Host "Provisioning detected. " -ForegroundColor Cyan


New-AzureRmDataFactoryDataset -DataFactory $df -File $resDir2\BlobCIAMCustomerDataset.json -Force
New-AzureRmDataFactoryDataset -DataFactory $df -File $resDir2\SqlDwInputDataset.json -Force

# Upload and register assemblies
$assemblyDir="..\VS-Solution\USQLHackathon.Soundex\bin\Release\USQLHackathon.Soundex.dll"
Import-AzureRmDataLakeStoreItem -AccountName $dataLakeStoreName -Path $assemblyDir -Destination "/Assemblies/USQLHackathon.Soundex/USQLHackathon.Soundex.dll" -Force

$j=Submit-AzureRmDataLakeAnalyticsJob -Account $dataLakeAnalyticsName `
    -Name "register assembly" `
    -Script 'USE DATABASE [master];
CREATE ASSEMBLY [USQLHackathon.Soundex] FROM @"/Assemblies/USQLHackathon.Soundex/USQLHackathon.Soundex.dll";
'
waitAdlaJob $j


substituteInTemplate $resDir2\BlobToSqlDwInputPipeline.json @{
    '$storageAccountName' = "$storageAccountName";
    '$today' = $today;
    }| Out-File $temp
New-AzureRmDataFactoryPipeline -DataFactory $df -File $temp -Force

#endregion


#region
$resDir3="$scriptDir\..\Resources\ADF-LoadSqlDw"

$temp=New-TemporaryFile

Resume-AzureRmSqlDatabase –ResourceGroupName $resourceGroupName –ServerName $sqlName –DatabaseName $dwName

substituteInTemplate $resDir3\AzureSqlDWLinkedService.json @{
    '$sqlName' = $sqlName;
    '$dwName' = $dwName;
    '$username' = $username;
    '$password' = $passwordString;
    } | Out-File $temp
New-AzureRmDataFactoryLinkedService -DataFactory $df -File $temp -Force
New-AzureRmDataFactoryDataset -DataFactory $df -File $resDir3\SqlDwCustomerMergeDataset.json -Force
substituteInTemplate $resDir3\SqlDwLoadPipeline.json @{
    '$today' = $today;
    }| Out-File $temp
New-AzureRmDataFactoryPipeline -DataFactory $df -File $temp -Force

#endregion

