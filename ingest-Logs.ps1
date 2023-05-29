Add-Type -AssemblyName System.Web

##############################################

#region declaration
$tenantId = "1770995e-5f7b-4556-9117-6a573af0a0c2"; #the tenant ID in which the Data Collection Endpoint resides
$appId = "00ed48e8-7694-4fd9-92cb-d9a3ee21977c"; #the app ID created and granted permissions
$appSecret = "ffb2194e-31d3-4bba-9f98-f75cea463d76"; #the secret created for the above app - never store your secrets in the source code
$DcrImmutableId = "dcr-6c477a14-5151-464d-89ef-304305165ce8"; #the unique id of the Data collection rule
$DceURI = "https://windows-telemetry.eastus-1.ingest.monitor.azure.com"; #the data collection endpoint URL
$Table = "telemetry_CL"; #the Azure Monitor table name with _CL
#endregion

##############################################

## Obtain a bearer token used to authenticate against the data collection endpoint
$scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
$body = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials";
$headers = @{"Content-Type" = "application/x-www-form-urlencoded" };
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$bearerToken = (Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers).access_token

## Generate and send some data
$hwDetails = Get-WmiObject Win32_PnPEntity | ?{$_.PNPClass -like "*biometric*"}

foreach ($line in $hwDetails) {
    $log_entry = @{
        # Define the structure of log entry, as it will be sent
        SystemName = $line.SystemName
        PSComputerName = $line.PSComputerName
        Status = $line.Status
        Present = $line.Present
        PNPDeviceID = $line.PNPDeviceID
        PNPClass = $line.PNPClass
        Name = $line.Name
        Manufacturer = $line.Manufacturer
        HardwareID = $line.HardwareID
        Description = $line.Description
        ClassGuid = $line.ClassGuid
        Caption = $line.Caption
    }

    # Sending the data to Log Analytics via the DCR!
    $bodyConv = $log_entry | ConvertTo-Json
    $body = "[" + $bodyConv + "]"
    $headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
    $uri = "$DceURI/dataCollectionRules/$DcrImmutableId/streams/Custom-$Table"+"?api-version=2021-11-01-preview";
    $uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers;

    # Let's see how the response looks
    Write-Output $uploadResponse
    Write-Output "---------------------"

    # Pausing for 1 second before processing the next entry
    Start-Sleep -Seconds 1
}