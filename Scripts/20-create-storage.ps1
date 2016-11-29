$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

#region - create storage account
New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $location -SkuName Standard_LRS
#endregion

#region - create storage containers
# Create a storage authentication context
$storageContext = getStorageContext

# Create Blob Containers in the Storage Account
New-AzureStorageContainer -Context $storageContext -Name from-ciam
New-AzureStorageContainer -Context $storageContext -Name from-db
New-AzureStorageContainer -Context $storageContext -Name to-ciam
New-AzureStorageContainer -Context $storageContext -Name to-sqldw
New-AzureStorageContainer -Context $storageContext -Name to-azureml
New-AzureStorageContainer -Context $storageContext -Name sql-dump
New-AzureStorageContainer -Context $storageContext -Name adf-resources
#endregion

