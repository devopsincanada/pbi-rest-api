
# [string]$TenantId = [System.Environment]::GetEnvironmentVariable("PBI_TENANT_ID"),
# [string]$AppId = [System.Environment]::GetEnvironmentVariable("PBI_APP_ID"),
# [SecureString]$AppSecret = (ConvertTo-SecureString -String ([System.Environment]::GetEnvironmentVariable("PBI_APP_SECRET")) -AsPlainText -Force),
# [string]$Filter = "",
# [string]$StartDate = "2023-06-23",
# [string]$EndDate = "2100-01-01",
# [int]$maxDatasets = 500,
# [int]$maxRefreshes = 500,
# [string]$OutputJsonPath = "activityevents.json",
# [switch]$OutputConsole = $true,
# [switch]$OutputGrid = $false,
# [ref]$RefreshHistory

$RefreshHistory = @()
./Get-RefreshHistory.ps1 -RefreshHistory ([ref]$RefreshHistory)

$i = 0
