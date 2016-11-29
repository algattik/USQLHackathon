$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

$clusterName="algattikhdi"
$storageContext = getStorageContext
$storageKey = getStorageKey

#region Create ADLS and ADLA resources
New-AzureRmHDInsightCluster `
    -ClusterName $clusterName `
    -ResourceGroupName $resourceGroupName `
    -HttpCredential $adminCredentials `
    -DefaultStorageAccountName "$storageAccountName.blob.core.windows.net" `
    -DefaultStorageAccountKey $storageKey `
    -DefaultStorageContainer hdinsight `
    -Location $location `
    -ClusterSizeInNodes 1 `
    -ClusterType Hadoop `
    -OSType Linux `
    -Version "3.4" `
    -SshCredential $adminCredentials
#endregion

