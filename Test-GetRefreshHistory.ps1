<#
  ----------------------------------------------------------------------------------
  Copyright (c) Microsoft Corporation.
  Licensed under the MIT license.
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
  EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
  OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
  ----------------------------------------------------------------------------------
#>

# TEST VALUES / pbispapp with no permissions
$TenantId = [System.Environment]::GetEnvironmentVariable("PBI_TENANT_ID")
$AppId = [System.Environment]::GetEnvironmentVariable("PBI_APP_ID")
$AppSecret = (ConvertTo-SecureString -String ([System.Environment]::GetEnvironmentVariable("PBI_APP_SECRET")) -AsPlainText -Force)

$RefreshHistory = @()
./Get-RefreshHistory.ps1 `
  -TenantId $TenantId `
  -AppId $AppId `
  -AppSecret $AppSecret `
  -OutputJsonPath "refresh-history.json" `
  -OutputConsole:$true `
  -OutputCsvPath "refresh-history.csv" `
  -maxDatasets 500 `
  -maxRefreshes 500 `
  -StartDate "2023-06-23" `
  -EndDate "2200-01-01" `
  -RefreshHistory ([ref]$RefreshHistory)

Write-Output "Refresh history count: $($RefreshHistory.Count)"
