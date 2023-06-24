
# TEST VALUES / pbispapp with no permissions
$TenandId = "45022e30-ae24-477e-9551-367579e9c8ae"
$AppId = "4bcb07c1-2a75-4fe2-b1c3-8d48b88a86d9"
$AppSecret = ConvertTo-SecureString "zPL8Q~nVc6br.NyCkur-2FypOfyc53iX4oFWxcO4" -AsPlainText -Force


$RefreshHistory = @()
./Get-RefreshHistory.ps1 `
  -TenantId $TenantId `
  -AppId $AppId `
  -AppSecret $AppSecret `
  -OutputJsonPath "refresh-history.json" `
  -OutputConsole:$true `
  -OutputGrid:$true `
  -OutputCsvPath "refresh-history.csv" `
  -maxDatasets 500 `
  -maxRefreshes 500 `
  -StartDate "2023-06-23" `
  -EndDate "2200-01-01" `
  -RefreshHistory ([ref]$RefreshHistory)

