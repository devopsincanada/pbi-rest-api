<#
    .SYNOPSIS
    Get activity events using service principal authentication.

    .DESCRIPTION
    ----------------------------------------------------------------------------------
    Copyright (c) Microsoft Corporation.
    Licensed under the MIT license.
    THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
    EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
    OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
    ----------------------------------------------------------------------------------

    PowerShell script to get activity events using service principal authentication.
    
    Prerequisites:
    - Register an Azure AD application and service principal that can access the Power BI service.
    - Remove all API permissions from the service principal.
      https://github.com/MicrosoftDocs/powerbi-docs/issues/3234#issuecomment-1249113930
    - Create a client secret for the service principal.
    - Create an Azure AD security group and add the service principal to the group.
    - Add the security group to the Power BI service admin portal.
      https://learn.microsoft.com/power-bi/enterprise/read-only-apis-service-principal-authentication

    Considerations:
    - How to you want to automate the running of this script?
    - Where should the output be stored?
    - What format should the output be in?
    - How do you want to visualize the output?

    .PARAMETER TenantId
    Azure AD tenant ID. Default is the value stored in the environment variable "PBI_TENANT_ID".

    .PARAMETER AppId
    Azure AD application ID Default is the value stored in the environment variable "PBI_APP_ID".

    .PARAMETER AppSecret
    Azure AD application secret. Default is the value stored in the environment variable "PBI_APP_SECRET".

    .PARAMETER DateOffset
    Number of days to offset from today. Either this parameter or the DateValue parameter must be specified.

    .PARAMETER DateValue
    Date in ISO 8601 format. Either this parameter or the DateOffset parameter must be specified.

    .PARAMETER Filter
    Filter to apply to activity events. Default is an empty string (no filter).

    .PARAMETER OutputJsonPath
    Path to output JSON file. Default is "activityevents.json".

    .PARAMETER OutputConsole
    Output activity events to console. Default is true.

    .PARAMETER OutputGrid
    Output activity events to grid. Only available interactively. Default is false.

    .EXAMPLE
    Get-ActivityEvents.ps1 -DateOffset -7 -OutputJsonPath "activityevents.json"

    .EXAMPLE
    Get-ActivityEvents.ps1 -DateValue "2021-01-01" -OutputConsole

    .EXAMPLE
    Get-ActivityEvents.ps1 -DateOffset -7 -OutputGrid

    .LINK
    https://docs.microsoft.com/rest/api/power-bi/admin/get-activity-events

    .LINK
    https://learn.microsoft.com/power-bi/admin/service-admin-portal-audit-logs

    .LINK
    https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app

    .LINK
    https://docs.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal
#>

param(
    [Parameter(HelpMessage="Azure AD tenant ID")]
    [string]$TenantId = [System.Environment]::GetEnvironmentVariable("PBI_TENANT_ID"),

    [Parameter(HelpMessage="Azure AD application ID")]
    [string]$AppId = [System.Environment]::GetEnvironmentVariable("PBI_APP_ID"),

    [Parameter(HelpMessage="Azure AD application secret")]
    [SecureString]$AppSecret = (ConvertTo-SecureString -String ([System.Environment]::GetEnvironmentVariable("PBI_APP_SECRET")) -AsPlainText -Force),

    [Parameter(Mandatory=$true, HelpMessage="Number of days to offset from today", ParameterSetName="DateByOffset")]
    [int]$DateOffset,

    [Parameter(Mandatory=$true, HelpMessage="Date in ISO 8601 format", ParameterSetName="DateByValue")]
    [string]$DateValue,

    [Parameter(HelpMessage="Filter to apply to activity events")]
    [string]$Filter = "",

    [Parameter(HelpMessage="Path to output JSON file")]
    [string]$OutputJsonPath = "activityevents.json",

    [Parameter(HelpMessage="Output activity events to console")]
    [switch]$OutputConsole = $true,

    [Parameter(HelpMessage="Output activity events to grid; only available interactively")]
    [switch]$OutputGrid = $false
)

# Make all errors terminating
$ErrorActionPreference = "Stop"

# Helper function to calculate $StartDateTime, $EndDateTime, and $Date based on $DateOffset
function Get-DateTimeRange {
    param(
        [int]$DateOffset,
        [ref]$StartDateTime,
        [ref]$EndDateTime,
        [ref]$Date
    )
    $today = Get-Date
    $calculatedDate = $today.AddDays($DateOffset)
    $Date.Value = $calculatedDate.ToString("yyyy-MM-dd")
    $StartDateTime.Value = $calculatedDate.ToString("yyyy-MM-ddT00:00:00.000Z")
    $EndDateTime.Value = $calculatedDate.ToString("yyyy-MM-ddT23:59:59.999Z")
}

# Calculate $StartDateTime, $EndDateTime, and $Date based on applicable ParameterSetName
switch ($PSCmdlet.ParameterSetName) {
    "DateByOffset" {
        Get-DateTimeRange -DateOffset $DateOffset -StartDateTime ([ref]$StartDateTime) -EndDateTime ([ref]$EndDateTime) -Date ([ref]$Date)
    }
    "DateByValue" {
        $StartDateTime = $DateValue + "T00:00:00.000Z"
        $EndDateTime = $DateValue + "T23:59:59.999Z"
        $Date = $DateValue
    }
}

# Get authentication token
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
    $header = @{
        "Authorization"="Bearer $($oauth.access_token)"
    }
} catch {
    Write-Error "Error getting authentication token: $($_.Exception.Message)"
    Write-Error $_.ErrorDetails
    throw
}

# Get activity events
try {
    $baseUrl = "https://api.powerbi.com/v1.0/myorg/admin/activityevents"
    $activityEventEntities = @()
    $continuationToken = $null
    do {
        if ($continuationToken) {
            $activityEventsUrl = $baseUrl + "?continuationToken='$continuationToken'"
        } else {
            $activityEventsUrl = $baseUrl + "?startDateTime='$StartDateTime'&endDateTime='$EndDateTime'"
        }
        if (!([string]::IsNullOrEmpty($Filter))) {
            $activityEventsUrl += "&`$filter=$Filter"
        }
        Write-Output "Getting activity events from $($activityEventsUrl)"
        $result = Invoke-RestMethod -Method Get -Uri $activityEventsUrl -Headers $header
        $activityEventEntities += $result.activityEventEntities
        $continuationToken = $result.continuationToken
    } while ($continuationToken)
} catch {
    Write-Error "Error getting activity events: $($_.Exception.Message)"
    Write-Error $_.ErrorDetails
    throw
}

# Output activity events
try {
    if ($activityEventEntities.Count -gt 0) {
        if (!([string]::IsNullOrEmpty($OutputJsonPath))) {
            Write-Output "Writing $($activityEventEntities.Count) events to file: $($OutputJsonPath)"
            $activityEventEntities | ConvertTo-Json -Depth 100 | Out-File -FilePath $OutputJsonPath -Force
        }
        if ($OutputConsole) {
            Write-Output "Writing $($activityEventEntities.Count) events to console"
            $activityEventEntities | Format-List Operation, UserId, Activity, IsSuccess, CreationTime
        }
        if ($OutputGrid) {
            Write-Output "Writing $($activityEventEntities.Count) events to window grid"
            $activityEventEntities | Out-GridView
        }
    } else {
        Write-Warning "No activity events found for date: $($Date)."
    }
} catch {
    Write-Error "Error outputting activity events: $($_.Exception.Message)"
    Write-Error $_.ErrorDetails
    throw
}
