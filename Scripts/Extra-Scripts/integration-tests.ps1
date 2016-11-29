$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

$storageContext = getStorageContext

#clear blob containers
Get-AzureStorageBlob -Context $storageContext -Container from-ciam | foreach { Remove-AzureStorageBlob -Context $storageContext -Blob $_.Name -Container from-ciam }
Get-AzureStorageBlob -Context $storageContext -Container from-db | foreach { Remove-AzureStorageBlob -Context $storageContext -Blob $_.Name -Container from-db }
Get-AzureStorageBlob -Context $storageContext -Container to-sqldw | foreach { Remove-AzureStorageBlob -Context $storageContext -Blob $_.Name -Container to-sqldw }

#write sample file to CIAM output
Set-AzureStorageBlobContent -Container "from-ciam" -File "..\Test-Resources\Customer\customers.json.gz" -Context $storageContext -Force

#write sample reference file to reference input
Set-AzureStorageBlobContent  -Container "from-db" -File "$scriptDir\..\Test-Resources\Reference\customers.tsv" -Context $storageContext -Force

Write-Host "Submitting ADLA job..." -ForegroundColor Green

#submit ADLA job - should write out CSV to to-sqldw container
$job=Submit-AzureRmDataLakeAnalyticsJob -Account $dataLakeAnalyticsName `
    -Name "integration test: CIAM to SQL DW" `
    -ScriptPath "..\VS-Solution\USQLApplication\ciam-to-sqldw.usql"

waitAdlaJob $job

#assert ADLA job produced expected output
$outFile=New-TemporaryFile
Get-AzureStorageBlobContent -Blob "from-adla/data.csv" -Container "to-sqldw" -Context $storageContext -Destination $outFile -Force
assertFilesEqual ..\Test-Resources\expected-sqldw-input.tsv $outFile

#load with polybase
Write-Host "Resuming SQL DW if paused..." -ForegroundColor Green
Resume-AzureRmSqlDatabase –ResourceGroupName $resourceGroupName –ServerName $sqlName –DatabaseName $dwName

try {
    Write-Host "Clearing any result of previous test run. Ignore errors if any appear." -ForegroundColor Yellow
    callSql $dwName "DROP TABLE [dbo].IntegrationTestInt" -ignoreErrors
    callSql $dwName "DROP EXTERNAL TABLE [dbo].IntegrationTestExt" -ignoreErrors
    callSql $dwName "DROP EXTERNAL FILE FORMAT IntegrationTestFile" -ignoreErrors

    $template=substituteInTemplate "$scriptDir\..\Test-Resources\load-polybase.sql" @{
        '$storageAccountKey' = (getStorageKey);
        '$storageAccountName' = $storageAccountName;
        }
    callSql $dwName $template
    callSql $dwName (Get-Content  -Raw)
    callSql $dwName "SELECT * FROM [dbo].[IntegrationTestInt] ORDER BY [customerId]" | Out-File $outFile
    assertFilesEqual ..\Test-Resources\expected-sqldw-content.tsv $outFile

    Write-Host "Integration test successful." -ForegroundColor Green
}
finally {
    Write-Host "Pausing SQL DW..." -ForegroundColor Green
    Suspend-AzureRmSqlDatabase –ResourceGroupName $resourceGroupName –ServerName $sqlName –DatabaseName $dwName
}



#region tests with Hive
$storageContext = getStorageContext
Set-AzureStorageBlobContent -File "$scriptDir\..\Resources\JSON-SerDe\json-serde-1.1.9.9-Hive1.2-jar-with-dependencies.jar" -Container hdinsight -Blob json-serde.jar -Context $storageContext -Force
Use-AzureRmHDInsightCluster -ClusterName $clusterName -HttpCredential $adminCredentials
$query = substituteInTemplate $scriptDir\..\Resources\hive-ciam-to-sqldw.sql @{
    '$storageAccountName' = "$storageAccountName";
    }
Invoke-AzureRmHDInsightHiveJob -Query $query

#assert ADLA job produced expected output
$outFile=New-TemporaryFile
Get-AzureStorageBlobContent -Blob "from-hive/000000_0" -Container "to-sqldw" -Context $storageContext -Destination $outFile -Force
assertFilesEqual ..\Test-Resources\expected-sqldw-input.tsv $outFile







