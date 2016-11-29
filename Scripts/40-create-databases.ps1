$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

#begin

#region - create server and set firewall rule
New-AzureRmSqlServer -ResourceGroupName $resourceGroupName -ServerName $sqlName -Location $location -SqlAdministratorCredentials $adminCredentials -ServerVersion 12.0
$myExternalIP = (Invoke-WebRequest ifcfg.me/ip).Content.Trim()
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $sqlName -FirewallRuleName ("Client " + (New-Guid)) -StartIpAddress $myExternalIP -EndIpAddress $myExternalIP
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $sqlName -AllowAllAzureIPs
#endregion

#region - create and configure SQL DW and immediately pause it

#Create DW
New-AzureRmSqlDatabase -RequestedServiceObjectiveName "DW100" -DatabaseName $dwName -ServerName $sqlName -ResourceGroupName $resourceGroupName -Edition "DataWarehouse"

#Setup Customer table
callSql $dwName (Get-Content "$scriptDir\..\Resources\create-customer-table.sql" -Raw)

#Pause SQL DW (to save money until we need it)
Suspend-AzureRmSqlDatabase –ResourceGroupName $resourceGroupName –ServerName $sqlName –DatabaseName $dwName
#endregion

#region - create SQL DB
$advWorksBlob = "AdventureWorksLT-V12.bacpac"
$StorageUri = "http://$storageAccountName.blob.core.windows.net/sql-dump/$advWorksBlob"
$storageContext = getStorageContext
$storageKey = getStorageKey

Set-AzureStorageBlobContent -File "$scriptDir\..\Resources\AdventureWorksLT-V12.bacpac" -Container sql-dump -Blob $advWorksBlob -Context $storageContext

$importRequest = New-AzureRmSqlDatabaseImport –ResourceGroupName $resourceGroupName –ServerName $sqlName –DatabaseName $dbName -StorageUri $StorageUri -StorageKeyType StorageAccessKey –StorageKey $storageKey –AdministratorLogin $adminCredentials.UserName –AdministratorLoginPassword $adminCredentials.Password –Edition Standard –ServiceObjectiveName S0 -DatabaseMaxSizeBytes 5000000

assertWithTimeout -sleep (New-TimeSpan -Seconds 10) -block {
    $status = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
    Write-Host ( Out-String -InputObject $status)
    $status.Status -eq "Succeeded"
}
#endregion



