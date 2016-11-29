$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

#region
$dbSecret = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList SQLSECRET, $password
Remove-AzureRmDataLakeAnalyticsCatalogSecret -Account $dataLakeAnalyticsName -DatabaseName "master" -Name SQLSECRET -ErrorAction Ignore -Force
New-AzureRmDataLakeAnalyticsCatalogSecret -Account $dataLakeAnalyticsName -DatabaseName "master" -Secret $dbSecret -Host "$sqlName.database.windows.net" -Port 1433

New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $sqlName -FirewallRuleName ("Allow ADLA hosts " + (New-Guid)) -StartIpAddress "25.75.0.0" -EndIpAddress "25.75.255.255"

$j=Submit-AzureRmDataLakeAnalyticsJob -Account $dataLakeAnalyticsName `
    -Name "create credential and data source" `
    -Script "
DROP DATA SOURCE IF EXISTS Purchase;
DROP CREDENTIAL IF EXISTS sqldbc;
CREATE CREDENTIAL sqlc WITH USER_NAME =""$username"", IDENTITY = ""SQLSECRET"";
CREATE DATA SOURCE SqlDw FROM AZURESQLDW WITH (
   PROVIDER_STRING = ""Database='$dwName';Trusted_Connection=False;Encrypt=True"",
   CREDENTIAL = sqlc,
   REMOTABLE_TYPES = (bool, byte, sbyte, short, ushort, int, uint, long, ulong, decimal, float, double, string, DateTime)
);
"
waitAdlaJob $j

$temp=New-TemporaryFile
substituteInTemplate "$scriptDir\..\Resources\adla-sqldw-to-blob.usql" @{
    '$storageAccountName' = $storageAccountName;
    } | Out-File $temp

$j=Submit-AzureRmDataLakeAnalyticsJob -Account $dataLakeAnalyticsName `
    -Name "export SQL DW data to blob" `
    -Script (Get-Content $temp -Raw) `
    -DegreeOfParallelism 1

waitAdlaJob $j

#endregion
