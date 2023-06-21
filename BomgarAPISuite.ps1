function Invoke-APIEndpoint {
    [CmdletBinding()]
    param (
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [System.Collections.Hashtable]$header,
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [System.Uri]$baseUrl,
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [String]$endpoint,
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [ValidateSet("Get","Put","Post","Delete","Patch")]
    [String]$method,
    [Parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [System.Collections.Hashtable]$queryParameter,
    [Parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [String]$pathParameter,
    [Parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [String]$filePath
    )
    
    DynamicParam {
        # If the method is POST or PUT or PATCH we'll create a dynamic parameter called Body
        if ($method -like 'P*') {
            $BodyAttribute = New-Object -TypeName System.Management.Automation.ParameterAttribute
            $BodyAttribute.Mandatory = $true
            $BodyAttribute.HelpMessage = "Supply a correctly formed Body"
            $attributeCollection = New-Object -TypeName 'System.Collections.ObjectModel.Collection[System.Attribute]'
            $attributeCollection.Add($BodyAttribute)
            $BodyParam = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter('Body',[String],$attributeCollection)
            $paramDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('Body', $BodyParam)
            return $paramDictionary
        }
    } # DynamicParam
    
    BEGIN {} # BEGIN
    PROCESS {
        Write-Verbose "Invoke-APIEndpoint"
        # If there are query or path parameters add them to the url
        if ($pathParameter) {
            $url = "$($baseUrl)$($endpoint)/$($pathParameter)"
            Write-Verbose "$url"
        }
        elseif ($queryParameter) {
            $iteration = 0
            foreach ($query in $queryParameter.GetEnumerator()) {
                if ($iteration -gt 0) {
                    <# Only after the first iteration will this line run - on the first iteration we want to add '?queryParameter=Value',
                     on subsequent iterations we want to add '&queryParameter=Value' #>
                    $url = "$url&$($query.Name)=$($query.Value)"
                } else {
                    $url = "$baseUrl$($endpoint)?$($query.Name)=$($query.Value)"
                    $iteration ++
                }
            }
            Write-Verbose "$url"
        } else {
            # If there are no query or path parameters this is the url
            $url = "$($baseUrl)$($endpoint)"
            Write-Verbose "$url"
        }
        try {
            # If the method is POST or PUT or PATCH we need to include a Body
            if ($method -like 'P*') {
                if ($filePath) {
                    $result = Invoke-RestMethod -Method $method -Headers $header -Uri $url -Body $Body -OutFile $filePath
                    Write-Verbose "OK: $($result.count) record/s"
                    $result
                } else {
                    $result = Invoke-RestMethod -Method $method -Headers $header -Uri $url -Body $Body
                    Write-Verbose "OK: $($result.count) record/s"
                    $result
                }
            } else {
                if ($filePath) {
                    $result = Invoke-RestMethod -Method $method -Headers $header -Uri $url -OutFile $filePath
                    Write-Verbose "OK: $($result.count) record/s"
                    $result                
                } else {
                    $result = Invoke-RestMethod -Method $method -Headers $header -Uri $url
                    Write-Verbose "OK: $($result.count) record/s"
                    $result
                }          
            }
        }
        catch {
            Write-Verbose "ERROR: $($_.Exception.Message)"
            # Output the error object
            $PSItem.Exception | Select-Object @{n='Exception_Message';e={$_.Message}}
        }
    } # PROCESS
    END {} # END
    } # Invoke-APIEndpoint

function New-BomgarAPIHeader {
    [cmdletbinding()]
    param(
    [parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [System.Uri]$baseUrl="",
    [parameter(Mandatory=$true)]
    [string]$clientId,
    [parameter(Mandatory=$true)]
    [string]$secret
    )
    BEGIN {
    Write-Verbose "New-BomgarAPIHeader"
    # Take supplied clientId and secret and base64 encode to include in Basic Auth header (used to generate Bearer Token)
    $text = "$($clientId):$($secret)"
    $bytes = [System.Text.Encoding]::UTF8.getBytes($text)
    $encoded = [Convert]::ToBase64String($bytes)
    # Create the header for Basic auth call
    $header = @{
        'Content-Type' = 'application/json'
        'Accept' = 'application/json'
        'Authorization' = "Basic $encoded"
    }
    # The required POST body
    $body = @{
        'grant_type'='client_credentials'
    } | ConvertTo-Json
    # All the parameters we'll supply to make the API call
    $Params = @{
        'baseUrl' = $baseUrl
        'endpoint' = 'oauth2/token'
        'Method' = 'Post'
        'header' = $header
        'Body' = $body
    }
    } # BEGIN
    PROCESS {
        # Invoke-APIEndpoint is another custom function
        $result = Invoke-APIEndpoint @Params
        if ($result.access_token) {
            $BearerToken = $result.access_token
        # The header with Bearer token for further API calls
            @{
                'Content-Type' = 'application/json'
                'Accept' = 'application/json'
                'Authorization' = "Bearer $BearerToken"            
            }
        } else {
            $result
        }
    } # PROCESS
} # New-BomgarAPIHeader

function Get-BomgarJumpClient {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [System.Collections.Hashtable]$header,
    [parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [System.Uri]$baseUrl="",
    [parameter(Mandatory=$false)]
    [System.Collections.Hashtable]$queryParameter,
    [parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [Int64]$id
    )
    BEGIN {} # BEGIN
    PROCESS {
        Write-Verbose "Get-BomgarJumpClient"
        $endpoint = 'api/config/v1/jump-client'
        if ($id) {
            $Params = @{
                'baseUrl' = $baseUrl
                'header' = $header
                'method' = 'Get'
                'endpoint' = $endpoint
                'pathParameter' = $id
            }            
        }
        elseif ($queryParameter) {
            $Params = @{
                'baseUrl' = $baseUrl
                'header' = $header
                'method' = 'Get'
                'endpoint' = $endpoint
                'queryParameter' = $queryParameter
            }
        } else {
            $Params = @{
                'baseUrl' = $baseUrl
                'header' = $header
                'method' = 'Get'
                'endpoint' = $endpoint
            }
        }
        $result = Invoke-APIEndpoint @Params
        $result
    } # PROCESS
} # Get-BomgarJumpClient

function New-BomgarJumpClient {
    [Cmdletbinding()]
    param(
    [parameter(Mandatory=$true)]
    [System.Collections.Hashtable]$header,
    [parameter(Mandatory=$false)]
    [System.Uri]$baseUrl="",
    [parameter(Mandatory=$false)]
    [Int32]$jumpGroupID = 1,
    [parameter(Mandatory=$false)]
    [Int32]$validDuration = 30,
    [parameter(Mandatory=$false)]
    [Int32]$attendedPolicyID = 8,
    [parameter(Mandatory=$false)]
    [Int32]$unattendedPolicyID = 8,
    [parameter(Mandatory=$false)]
    [String]$comments = $null   
    )
    BEGIN {
        Write-Verbose "New-BomgarJumpClient"
        $endpoint = "api/config/v1/jump-client/installer"
        # The post body for the creation of the jump client - the jump_group_id 1 refers to the 'Workplace' jump group
        $body = @{
            "name" = ""
            "jump_group_id" = $jumpGroupID
            "jump_policy_id" = $null
            "jump_group_type" = "shared"
            "connection_type" = "active"
            "attended_session_policy_id" = $sttendedPolicyID
            "unattended_session_policy_id" = $unattendedPolicyID
            "comments" = $comments
            "valid_duration" = $validDuration
            "elevate_install" = $true
            "elevate_prompt" = $true
            "is_quiet" = $true
            "allow_override_jump_group" = $false
            "allow_override_jump_policy" = $false
            "allow_override_name" = $false
            "allow_override_comments" = $false
        } | ConvertTo-Json
    }
    PROCESS {
        $Params = @{
            'header' = $header
            'baseUrl' = $baseUrl
            'endpoint' = $endpoint
            'method' = 'Post'
            'body' = $body
        }
        $result = Invoke-APIEndpoint @Params
        $result
    }
} # New-BomgarJumpClient

function Remove-BomgarJumpClient {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [System.Collections.Hashtable]$header,
    [parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [System.Uri]$baseUrl="",
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [System.Int64]$id
    )

    BEGIN {} # BEGIN
    PROCESS {
        Write-Verbose "Remove-BomgarJumpClient"
        $Params = @{
            'baseUrl' = $baseUrl
            'header' = $header
            'method' = 'Delete'
            'endpoint' = "api/config/v1/jump-client/$id"
        }
        $result = Invoke-APIEndpoint @Params
        $result
    } # PROCESS

}

function Get-BomgarJumpClientInstaller {
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [System.Collections.Hashtable]$header,
    [parameter(Mandatory=$false,
               ValueFromPipelineByPropertyName=$true)]
    [System.Uri]$baseUrl="",
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [ValidateSet('linux-64','linux-64-headless','raspberry-pi-32-headless','mac-dmg','mac-zip','windows-64','windows-64-msi','windows-32','windows32-msi')]
    [String]$platform,
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [String]$Installer_Id,
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [String]$Key_Info,
    [parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true)]
    [String]$filePath
    )
    BEGIN {} # BEGIN
    PROCESS {
        Write-Verbose "Get-BomgarJumpClientInstaller"
        $endpoint = "api/config/v1/jump-client/installer/$Installer_Id/$platform"
        $Params = @{
            'header' = $header
            'baseUrl' = $baseUrl
            'endpoint' = $endpoint
            'method' = 'Get'
            'filePath' = $filePath
        }
        $result = Invoke-APIEndpoint @Params
        $result
    } # PROCESS
} # Get-BomgarJumpClientInstaller
