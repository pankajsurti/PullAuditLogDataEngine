# Input bindings are passed in via param block.
param([string] $queueitem, $TriggerMetadata)



# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $queueitem"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"


#Sign in Parameters
$clientID = "TODO TO ADD"
$clientSecret = "TODO TO ADD"
$loginURL = "https://login.windows.net"
$tenantdomain = "TODO" #
$tenantGUID = "TODO TO ADD"
$resource = "https://manage.office.com"
   
   
# Get an Oauth 2 access token based on client id, secret and tenant domain
$body = @{grant_type = "client_credentials"; resource = $resource; client_id = $ClientID; client_secret = $ClientSecret }

#oauthtoken in the header
$oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body 
$headerParams = @{'Authorization' = "$($oauth.token_type) $($oauth.access_token)" }



$queueitem.count

Write-Host "Queue item count: $($queueitem.count)"

if ($queueitem.count -eq "1") 
{
    Write-Host "Before doing convert from JSON: $($queueitem.GetType())"
    #$items = $queueitem | convertfrom-json 
    $items = $queueitem.Split(" ")
    Write-Host "Total uris to call : $($items.Count)"
    foreach ( $item in $items) {
        #$uri = $item + "?PublisherIdentifier=" + $TenantGUID  
        $uri = $item 
        Write-Host "Call uri : $uri"
        $records = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $uri
        #Write-Host "records : $records"
        Push-OutputBinding -Name outputDocument -value $records.content -clobber
    }
}
elseif ($queueitem.count -gt "1") {
    foreach ( $content in $queueitem) {
        $uri = $content + "?PublisherIdentifier=" + $TenantGUID  
        $records = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $uri
        Push-OutputBinding -Name outputDocument -value $records.content -clobber
    }
}
