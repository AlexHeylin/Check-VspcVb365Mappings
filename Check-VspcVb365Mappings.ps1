[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Server = "https://localhost:1280",
    [pscredential]
    $Credential,
    [decimal]
    $CostPerPoint = 1.23
)
[System.IO.FileInfo]$BasePath = "$env:LOCALAPPDATA\AlexHeylin\Check-VspcVb365Mappings"
[System.IO.FileInfo]$LogFile  = "$BasePath\Check-VspcVb365Mappings.log"

# Install and import logging module
if (-not (Get-InstalledModule -Name PoShLog -MinimumVersion 2.1.1)) {
    Install-Module PoShLog -Scope CurrentUser -Force 
}
try {
    # Deal with "bug" in Visual Studio Code's PowerShell that breaks PoShLog
    Import-Module PoShLog
} catch {
    Write-Error "Unable to initalise logging using PoshLog. If you're running Visual Studio Code, read https://github.com/PoShLog/PoShLog/issues/3 `
            and open an admin PoSh window, run Import-Module PoShLog then the code snippet from the issue.  The quit and restart VSC and it should work."
    $Error[0]
}

# Create new logger
try {
    # This is where you customize, when and how to log
    New-Logger | 
        Set-MinimumLevel -Value Verbose | # You can change this value later to filter log messages
        # Here you can add as many sinks as you want - see https://github.com/PoShLog/PoShLog/wiki/Sinks for all available sinks
        Add-SinkConsole  -RestrictedToMinimumLevel Error|   # Tell logger to write log messages to console
        Add-SinkFile -Path $LogFile -RollingInterval Day -RetainedFileCountLimit 65  |
            Start-Logger
    
        # Test all log levels
        Write-VerboseLog 'Logging initialised'
    <#
        Write-DebugLog 'Test debug message'
        Write-InfoLog 'Test info message'
        Write-WarningLog 'Test warning message'
        Write-ErrorLog 'Test error message'
        Write-ErrorLog -ErrorRecord $_
        Write-ErrorLog 'Error occurred while doing some business! {SomeNumber}' -ErrorRecord $_ -PropertyValues 123
        Write-ErrorLog 'Error occurred while doing some business!' -Exception $_.Exception
        Write-FatalLog 'Test fatal message'

        ## DO NOT forget to close the logger!!
        Close-Logger 
    #>

} catch {
    #Write-Error "Unable to initalise logging using PoshLog"
    $Error[0]
}



$ApiEndpoint = $Server + '/api/v3'
Write-VerboseLog 'ApiEndpoint = {ApiEndpoint}' -PropertyValues $ApiEndpoint

# Get Bearer Token 
try {
    $result = Invoke-RestMethod -Method Post -Uri "$ApiEndpoint/token" -Body "grant_type=password&username=$($Credential.UserName)&password=$($Credential.GetNetworkCredential().Password)" -UseBasicParsing
    $bearer_token = $result.access_token
    #$refresh_token = $result.refresh_token
} catch {
    Write-FatalLog "Failed getting authentication token.  Please check connection and credentials." -Exception $_.Exception
}
If ($null -ne $bearer_token) {
    Write-VerboseLog 'Got bearer token NOT_LOGGED'
} else {
    Write-FatalLog 'No authentication token parsed. Result was {result}' -PropertyValues $result
    throw $_ 
}


# Get all orgs in VB365
$uri = "$ApiEndpoint/infrastructure/vb365Servers/organizations?limit=100&offset=0"
$headers = @{"accept"="application/json"}
Write-VerboseLog "Requesting all VB365 orgs from {@uri} with headers: {@headers}" -PropertyValues $uri, $headers
$headers += @{"Authorization"="bearer $bearer_token"}
try {
    $orgs_result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers  -UseBasicParsing
    Write-VerboseLog 'Got result {orgs_result}' -PropertyValues $orgs_result
} catch {
    Write-FatalLog "Failed getting organisations.  Please check connection." -Exception $_.Exception
    throw $_ 
}


# Get all org-company mappings in VB365
$uri = "$ApiEndpoint/infrastructure/vb365Servers/organizations/companyMappings?limit=100&offset=0"
$headers = @{"accept"="application/json"}
Write-VerboseLog "Requesting all Vb365-Company mappings from {@uri} with headers: {@headers}" -PropertyValues $uri, $headers
$headers += @{"Authorization"="bearer $bearer_token"}
try {
    $maps_result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers  -UseBasicParsing
    Write-VerboseLog 'Got result {maps_result}' -PropertyValues $maps_result
} catch {
    Write-FatalLog "Failed getting mappings.  Please check connection." -Exception $_.Exception
    throw $_ 
}

# Get all VB365 servers
$uri = "$ApiEndpoint/infrastructure/vb365Servers?limit=100&offset=0"
$headers = @{"accept"="application/json"}
Write-VerboseLog "Requesting all VB365 servers from {@uri} with headers: {@headers}" -PropertyValues $uri, $headers
$headers += @{"Authorization"="bearer $bearer_token"}
try {
    $servers_result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers  -UseBasicParsing
    Write-VerboseLog 'Got result {servers_result}' -PropertyValues $servers_result
} catch {
    Write-FatalLog "Failed getting list of VB365 servers.  Please check connection." -Exception $_.Exception
    throw $_ 
}



$orgCounter = 0
$matchCounter = 0
$noMatchOrgs = @()
foreach ($org in $orgs_result.data){
    $orgCounter++
    Write-VerboseLog "Processing org with name {OrgName} and instanceUID {instanceUID}" -PropertyValues $($org.name), $($org.instanceUID)
    $matchingMapCompUid = $null
    foreach ($map in $maps_result.data) {
        if ($($org.instanceUID) -eq $($map.vb365OrganizationUid)) {
            Write-VerboseLog "{orgInstanceUID} matches {mapvb365OrganizationUid}, named {mapvb365OrganizationName}" -PropertyValues $($org.instanceUID), $($map.vb365OrganizationUid), $($map.vb365OrganizationName)
            $matchingMapCompUid = $($map.companyUid)
            $matchCounter++
            break
        }
        
    }
    # Add to array of non-matching orgs
    if ($null -eq $matchingMapCompUid){
        foreach ($vb365Server in $servers_result.data){
            if ($($org.vb365ServerUid) -eq $($vb365Server.instanceUid)) {
                Write-VerboseLog "Found matching VBserver {vb365ServerinstanceUid} named {vb365Servername}" -PropertyValues $($vb365Server.instanceUid), $($vb365Server.name)
                if ($($vb365Server.ownership) -eq 'Hosted') {
                    Write-VerboseLog "VBserver {vb365ServerinstanceUid} is {vb365Serverownership} and {orgvb365ServerUid} has no mapping so adding to noMatchOrgs array " -PropertyValues $($vb365Server.instanceUid), $($vb365Server.ownership), $($org.vb365ServerUid)
                    $noMatchOrgs += $org
                } 
            }
        }

    }

}
Write-InformationLog "Found {orgCounter} orgs of which {matchCounter} have matching maps" -PropertyValues $orgCounter, $matchCounter

Write-InformationLog "Processed {orgCounter} organisations" -PropertyValues $orgCounter

if ($noMatchOrgs.Count -ge 1) {
    Write-Output "CRITICAL: Found $($noMatchOrgs.Count) unmapped VB365 organisations. This WILL create billing problems!  MUST resolve by month end."
    write-output $noMatchOrgs.name
} else {
    Write-Output "OK: Found $($noMatchOrgs.Count) unmapped VB365 organisations. Checked $orgCounter orgs."
}

# Flush all logs 
Close-Logger 
