# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"

Write-Host "Version 5.0"



#Enumerators and object to wrap the objects
$pageArray = @()
$output = @()
$msgarray = @()

#add-type -assemblyName "Microsoft.Azure.Storage.Queue"

#Sign in Parameters

$clientID = "TODO TO ADD"
$clientSecret = "TODO TO ADD"
$loginURL = "https://login.windows.net"
$tenantdomain = "TODO" #
$tenantGUID = "TODO TO ADD"
$resource = "https://manage.office.com"


#Workloads and end time default is on start
$workloads = @("Audit.AzureActiveDirectory", "Audit.SharePoint", "Audit.Exchange", "Audit.General", "DLP.All")
#$workloads = @( "DLP.All")
#$endTime = Get-date -format "yyyy-MM-ddTHH:mm:ss.fffZ" 

<#
$numberOfDays2Add = -6
$endTimeDt   = Get-Date
$endTimeDt   = $endTimeDt.AddDays($numberOfDays2Add)
$endTime     = $endTimeDt.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
#>
$endTime = Get-date -format "yyyy-MM-ddTHH:mm:ss.fffZ"
$StoredTime  = $null
<#
$startTimeDt = Get-Date
$startTimeDt = $startTimeDt.AddDays(-5)
$StoredTime  = $startTimeDt.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
#>

#Storage Account Settings, this is needed to access the storage queue
$storageAccountName = "storageaccountdlprg84fe"
$storageAccountKey = "TODO TO ADD"
$storageQueue = 'outputqueue'



#Load the Storage Queue
$storeAuthContext = New-AzStorageContext $StorageAccountName -StorageAccountKey $StorageAccountKey
$myQueue = Get-AzStorageQueue -Name $storageQueue -Context $storeAuthContext
$messageSize = 10


foreach ($workload in $workloads) {
    
    $Tracker = "D:\home\LogFiles\$workload.log" # change to location of choise this is the root.
    <#
    #$Tracker = "C:\dlp\$workload.log"
    Write-Host "Working on workload: $workload"
    if ( $StoredTime.Length -le 0 )
    {
        $StoredTime = Get-content $Tracker 
    }

    #If events are longer apart than 24 hours
    while ($true)
    {
        $adjustTime = New-TimeSpan -start $Storedtime -End $endTime
        if ($adjustTime.TotalHours -gt 24) 
        {
            #$StoredTime = (get-date $endTime).AddDays(-1).ToUniversalTime()
        
            $hours = $adjustTime.TotalHours - 23.9
            Write-Host "Number of extra hrs : $hours"
            $StoredTime = (get-date $StoredTime).AddHours($hours).ToUniversalTime()
        }
        else
        {
            break
        }
        $StoredTime  = $StoredTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    #>
    $StoredTime = (get-date $endTime).AddHours(-23.999).ToUniversalTime()
    $StoredTime  = $StoredTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

    Write-Host "StoredTime: $StoredTime"
    Write-Host "endTime   : $endTime"
    #$StoredTime = $startTimeStr
    # Get an Oauth 2 access token based on client id, secret and tenant domain
    $body = @{grant_type = "client_credentials"; resource = $resource; client_id = $ClientID; client_secret = $ClientSecret }
    #oauthtoken in the header
    $oauth = Invoke-RestMethod -Method Post -Uri $loginURL/$tenantdomain/oauth2/token?api-version=1.0 -Body $body 
    $headerParams = @{'Authorization' = "$($oauth.token_type) $($oauth.access_token)" }

    $url2Call = "https://manage.office.com/api/v1.0/$tenantGUID/activity/feed/subscriptions/content?contenttype=$workload&startTime=$Storedtime&endTime=$endTime&PublisherIdentifier=$TenantGUID"
    #Make the request
    Write-Host "url2Call: $url2Call"

    $rawRef = Invoke-WebRequest -Headers $headerParams -Uri $url2Call -UseBasicParsing
    Write-Host "rawRef: $rawRef"
    
    #If more than one page is returned capture and return in pageArray
    if ($rawRef.Headers.NextPageUri) 
    {
        $pageTracker = $true
        $pagedReq = $rawRef.Headers.NextPageUri
        while ($pageTracker -ne $false)
        {   
            $pageuri = $pagedReq + "?PublisherIdentifier=" + $TenantGUID  
            $CurrentPage = Invoke-WebRequest -Headers $headerParams -Uri $pageuri -UseBasicParsing
            $pageArray += $CurrentPage
            if ($CurrentPage.Headers.NextPageUri)
            {
                $pageTracker = $true    
            }
            Else
            {
                $pageTracker = $false
            }
            $pagedReq = $CurrentPage.Headers.NextPageUri
        }
    } 
    $pageArray += $rawref
    if ($pagearray.RawContentLength -gt 3) {
        foreach ($page in $pageArray)
        {
            $request = $page.content | convertfrom-json
            $runs = $request.Count / ($messageSize + 1)
            $writeSize = $messageSize
            $i = 0
            while ($runs -ge 1) { 
                $rawmessage = $request[$i..$writeSize].contenturi 
                foreach ($msg in $rawmessage) { 
                    $msgarray += @($msg) 
                    $message = $msgarray | convertto-json
                }                     
                        
                Write-Host "Create a new message using a constructor of the CloudQueueMessage class: at Line 109"

                # Create a new message using a constructor of the CloudQueueMessage class
                $queueMessage = [Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new($message)
                # Add a new message to the queue
                $myqueue.CloudQueue.AddMessageAsync($queueMessage)

                $runs -= 1
                $i += $messageSize + 1
                $writeSize += $messageSize + 1 
               
                Clear-Variable -Name "msgarray" -ErrorAction Ignore
                Clear-Variable -Name "message" -ErrorAction Ignore
                Clear-Variable -Name "rawMessage" -ErrorAction Ignore
            }   
         
            if ($runs -gt 0) {

                if ($request.Count -eq 1)
                {
                    $message = $request[0].contenturi
                }
                elseif ($request.Count -gt 1)
                {
                    $rawMessage = $request[$i..$writeSize].contenturi 
                    Write-Host "rawMessage Count: $($rawMessage.Count)"

                    if ($rawMessage.Count -gt 0) {

                        foreach ($msg in $rawMessage) {  
                            #Write-Host "msg at line 142: $msg"
                            $msgarray += @($msg)
                            $message = $msgarray | convertto-json                                                        
                        }                                                           

                        $runs -= 1                                   

                    }
                } 
                if ( $message -ne $null )
                {
                    Write-Host "Create a new message using a constructor of the CloudQueueMessage class: at Line 149"

                    # Create a new message using a constructor of the CloudQueueMessage class
                    $queueMessage = [Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new($message)
                    # Add a new message to the queue
                    $myqueue.CloudQueue.AddMessageAsync($queueMessage)
                }

            }

            Clear-Variable -Name "rawMessage" -ErrorAction Ignore
            Clear-Variable -Name "message" -ErrorAction Ignore
            Clear-Variable -Name "msgarray" -ErrorAction Ignore 
        }
        $time = $pagearray[0].Content | convertfrom-json
        $Lastentry = $time[$Time.contentcreated.Count - 1].contentCreated 
        if ($Lastentry -ge $storedTime) { out-file -FilePath $Tracker -NoNewline -InputObject (get-date $lastentry).Addseconds(1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ") } 
    } 

    Clear-Variable -Name "pagearray" -ErrorAction Ignore
    Clear-Variable -Name "rawref" -ErrorAction Ignore
    Clear-Variable -Name "page" -ErrorAction Ignore


}
