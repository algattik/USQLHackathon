$ErrorActionPreference = "Stop"
$scriptDir=($PSScriptRoot, '.' -ne "")[0]
. "$scriptDir\Include\common.ps1"

#begin

$storageKey = getStorageKey

Write-Host "Paste this into your VS-Solution\CIAMEmulator\App.config :" -ForegroundColor Green
Write-Host "
  <appSettings>
    <add key=""StorageConnectionString"" value=""DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$storageKey""/>
    <add key=""AdvWorksConnectionString"" value=""Server=tcp:$sqlName.database.windows.net;Initial Catalog=$dbname;Persist Security Info=False;User ID='$username';Password='$passwordString';MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;""/>
  </appSettings>
" -ForegroundColor Cyan


