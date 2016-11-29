#region - used for creating Azure service names
$namePrefix = [Environment]::UserName
#endregion

#region - service names
$resourceGroupName = "USQLHackathon"
$location = "East US 2"
$dataFactoryLocation = "East US"
#endregion

#region - service names
$dataLakeStoreName = $namePrefix + "adls"
$dataLakeAnalyticsName = $namePrefix + "adla"
$storageAccountName = $namePrefix + "was"
#endregion

$sqlName = $namePrefix + "sql"
$dwName = $namePrefix + "dw"
$dbName = $namePrefix + "db"

$dataFactoryName = $namePrefix + "df"


$username = "zeus"

#region - Connect to Azure subscription
Write-Host "`nConnecting to your Azure subscription ..." -ForegroundColor Green
try{Get-AzureRmContext}
catch{Login-AzureRmAccount}
#endregion

