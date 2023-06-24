

param(
    [Parameter(HelpMessage="Azure AD tenant ID")]
    [string]$TenantId = [System.Environment]::GetEnvironmentVariable("PBI_TENANT_ID"),

    [Parameter(HelpMessage="Azure AD application ID")]
    [string]$AppId = [System.Environment]::GetEnvironmentVariable("PBI_APP_ID"),

    [Parameter(HelpMessage="Azure AD application secret")]
    [SecureString]$AppSecret = (ConvertTo-SecureString -String ([System.Environment]::GetEnvironmentVariable("PBI_APP_SECRET")) -AsPlainText -Force),

    [Parameter(HelpMessage="Earliest date to include in dataset refresh events")]
    [string]$StartDate = "1900-01-01",

    [Parameter(HelpMessage="Latest date to include in dataset refresh events")]
    [string]$EndDate = "2300-01-01",

    [Parameter(HelpMessage="Maximum number of datasets to evaluate")]
    [int]$maxDatasets = 500,

    [Parameter(HelpMessage="Maximum number of refreshes to evaluate")]
    [int]$maxRefreshes = 500,

    [Parameter(HelpMessage="Path to output JSON file")]
    [string]$OutputJsonPath = "",

    [Parameter(HelpMessage="Path to output CSV file")]
    [string]$OutputCsvPath = "",

    [Parameter(HelpMessage="Output activity events to console")]
    [switch]$OutputConsole = $true,

    [Parameter(HelpMessage="Output activity events to grid; only available interactively")]
    [switch]$OutputGrid = $false,

    [Parameter(Mandatory=$true)]
    [ref]$RefreshHistory
)

$ErrorActionPreference = "Continue"

function Get-AccessToken {
  param(
    [string]$TenantId,
    [string]$AppId,
    [SecureString]$AppSecret,
    [ref]$AccessToken
  )
  try {
    $loginUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $resourceUrl = "https://analysis.windows.net/powerbi/api"
    $body = @{
        "resource"=$resourceUrl
        "client_id"=$AppId
        "client_secret"=$(ConvertFrom-SecureString -SecureString $AppSecret -AsPlainText)
        "grant_type"="client_credentials"
    }
    $oauth = Invoke-RestMethod -Method Post -Uri $loginUrl -Body $body
    $AccessToken.Value = $oauth.access_token
  } catch {
    Write-Error "Error getting authentication token: $($_.Exception.Message)"
    Write-Error $_.ErrorDetails
    throw
  }
}

function Invoke-PowerBiRestApi {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Operation,
    [string]$Params = "",
    [Parameter(Mandatory=$true)]
    [string]$AccessToken,
    [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
    [string]$ResultField = "",
    [Parameter(Mandatory=$true)]
    [ref]$Results
  )
  try {
    $baseUrl = "https://api.powerbi.com/v1.0/myorg/"
    $fullUrl = $baseUrl + $Operation
    $header = @{
      "Authorization"="Bearer $($AccessToken)"
    }
    $continuationToken = $null
    do {
        if ($continuationToken) {
          $fullUrl = $baseUrl + $Operation + "?continuationToken='$continuationToken'"
        } elseif (!([string]::IsNullOrEmpty($Params))) {
          $fullUrl = $baseUrl + $Operation + "?" + $Params
        } else {
          $fullUrl = $baseUrl + $Operation
        }
        Write-Output "  Invoking $fullUrl"
        $result = Invoke-RestMethod -Method $Method -Uri $fullUrl -Headers $header
        if (!([string]::IsNullOrEmpty($ResultField))) {
          $Results.Value += $result.$ResultField
        } else {
          $Results.Value += $result
        }
        $continuationToken = $result.continuationToken
    } while ($continuationToken)
  } catch {
    Write-Output "  *** ERROR *** invoking $fullUrl"
    Write-Output "    $_.ErrorDetails.Message"
    # Write-Error $_.Exception.Message
    throw
  }
}

# Get the access token
$AccessToken = ""
Write-Output ""
Write-Output "Getting access token"
Get-AccessToken -TenantId $TenantId -AppId $AppId -AppSecret $AppSecret -AccessToken ([ref]$AccessToken)

# Get the datasets
$datasets = @()
Write-Output ""
Write-Output "Getting datasets"
try {
  Invoke-PowerBiRestApi `
    -Operation "admin/datasets" `
    -Params "`$top=$maxDatasets" `
    -AccessToken $AccessToken `
    -ResultField "value" `
    -Results ([ref]$datasets)
  Write-Output "  Found $($datasets.Count) datasets: $(($datasets | % { $_.name }) -join ', ')"
} catch {
  Write-Output "  *** ERROR *** getting datasets"
  Write-Output "    $_.ErrorDetails.Message"
  # Write-Error $_.Exception.Message
  throw
}

# Get the refresh history for each dataset
$RefreshHistory.Value = @()
foreach ($dataset in $datasets) {
  try {
    $refreshes = @()
    Write-Output ""
    Write-Output "Getting refresh events for dataset '$($dataset.name)' between $StartDate and $EndDate"
    Invoke-PowerBiRestApi `
      -Operation "admin/datasets/$($dataset.id)/refreshes" `
      -Params "`$top=$maxRefreshes" `
      -AccessToken $AccessToken `
      -ResultField "value" `
      -Results ([ref]$refreshes)
    $subset = $refreshes | ? { $_.startTime.ToLocalTime() -ge $StartDate -and $_.startTime.ToLocalTime() -lt $EndDate }
    Write-Output "  Found ($($subset.Count)/$($refreshes.Count))  refreshes for dataset $($dataset.name)"

    # Skip datasets with no refreshes
    if ($subset.Count -eq 0) {
      continue
    }

    # Get the workspace details for the current dataset so we can access its name
    $workspace = @()
    Write-Output "Getting workspace details for workspace '$($dataset.workspaceId)'"
    Invoke-PowerBiRestApi `
      -Operation "admin/groups/$($dataset.workspaceId)" `
      -Params "`$expand=datasets" `
      -AccessToken $AccessToken `
      -Results ([ref]$workspace)
    Write-Output "  Found workspace '$($workspace.name)' with id $($dataset.workspaceId) containing dataset '$($dataset.name)'"

    # Add the dataset and workspace ids and names to each refresh record
    $subset = $subset | `
      Add-Member -MemberType NoteProperty -Name "datasetId" -Value $dataset.id -PassThru | `
      Add-Member -MemberType NoteProperty -Name "datasetName" -Value $dataset.name -PassThru | `
      Add-Member -MemberType NoteProperty -Name "workspaceId" -Value $dataset.workspaceId -PassThru | `
      Add-Member -MemberType NoteProperty -Name "workspaceName" -Value $workspace.name -PassThru

    $RefreshHistory.Value += $subset
  } catch {
    Write-Output "  *** ERROR *** getting refresh events for dataset '$($dataset.name)'" # : $($_.Exception.Message)"
    Write-Output "    $_.ErrorDetails.Message"
    # Write-Error $_.Exception.Message
  }
}

# Output refresh  events
  if ($RefreshHistory.Value.Count -gt 0) {
    if (!([string]::IsNullOrEmpty($OutputJsonPath))) {
        Write-Output "Writing $($RefreshHistory.Value.Count) refresh events to JSON file: $($OutputJsonPath)"
        $RefreshHistory.Value | ConvertTo-Json -Depth 100 | Out-File -FilePath $OutputJsonPath -Force
    }
    if (!([string]::IsNullOrEmpty($OutputCsvPath))) {
      Write-Output "Writing $($RefreshHistory.Value.Count) refresh events to CSV file: $($OutputCsvPath)"
      $RefreshHistory.Value | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Force
    }
    if ($OutputConsole) {
        Write-Output "Writing $($RefreshHistory.Value.Count) refresh events to console"
        $RefreshHistory.Value | Format-List workspaceName, datasetName, startTime, endTime, status, refreshType
    }
    if ($OutputGrid) {
        Write-Output "Writing $($RefreshHistory.Value.Count) refresh events to window grid"
        $RefreshHistory.Value | Out-GridView
    }
} else {
    Write-Output "No refresh events found."
}
