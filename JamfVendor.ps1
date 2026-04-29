<#
    .SYNOPSIS 
    Powershell Jamf Vendor. A static powershell interface for Jamf-related automations. The script can be included into any solution using the script inclusion operator. Function use examples are provided above each function.

    Created 22nd May 2025
    Developed using Powershell v2025.2.0
    Created by Marco Garzon Lara
    Created in Western Australia, Australia
    Based on both 'Jamf Classic API' and 'Jamf Pro API' references
#>
class JamfVendor {
    <#
        .SYNOPSIS 
        Function to log function output 

        .PARAMETER message
        The Message to be written to the log file

        .PARAMETER logFilePath
        The file path for the created log file.
    #>
    hidden static [void] WriteLog([string]$message, [string]$logFilePath) {
        Add-Content -Path "logs/$logFilePath" -Value $message
        Write-Host $message
    }

    <#
        .SYNOPSIS 
        Function to generate an API token. Used when current token has expired or not valid.

        .PARAMETER jssUser
        The Jamf API account username.

        .PARAMETER jssPass
        The Jamf API account password.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.
    #>
    static [String] GetToken([string]$jssUser, [string]$jssPass, [string]$jamfUrl) {
        try {
            $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($jssUser):$($jssPass)"))
            $authHeader = @{ Authorization = "Basic $base64AuthInfo" }
            $authResponse = Invoke-RestMethod -Uri "https://$jamfUrl/api/v1/auth/token" -Method Post -Headers $authHeader
            return [string]$authResponse.token
        } 
        catch {
            [JamfVendor]::WriteLog("Error: GetToken $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "TokenLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            throw $_
        }
    }

    <#
        .SYNOPSIS 
        Function to refresh the API token. Used when current token has expired or not valid.

        .PARAMETER jssUser
        The Jamf API account username.

        .PARAMETER jssPass
        The Jamf API account password.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.
    #>
    static [String] RefreshApiToken([string]$jssUser, [string]$jssPass, [string]$jamfUrl) {
        try {
            $apiToken = [JamfVendor]::GetToken($jssUser, $jssPass, $jamfUrl)
            [JamfVendor]::WriteLog("Info: RefreshApiToken complete at $(Get-Date -Format 'HH:mm:ss')", "TokenLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")

            return $apiToken
        } 
        catch {
            [JamfVendor]::WriteLog("Error: RefreshApiToken $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "TokenLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            throw $_
        }
    }

    <#
        .SYNOPSIS 
        Function to test API token validity. Returns true if valid, false if invalid.

        .PARAMETER apiToken
        The API token to assess

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.
    #>
    static [Boolean] TestApiTokenValidity ([string]$jamfUrl, [string]$apiToken) {
        try {
            Invoke-RestMethod -Uri "https://$jamfUrl/api/v1/auth/keep-alive" -Method Post -Headers @{ Authorization = "Bearer $apiToken" }
            return $true
        } 
        catch {
            return $false
        }
    }

    <#
        .SYNOPSIS 
        Function to invalidate a valid Jamf API session token. Usually used for cleanup after session.

        .PARAMETER jamfUrl
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        A valid Jamf api token.
    #>
    static [Void] InvalidateToken([String]$jamfUrl, [String]$apiToken) {
        try {
            $authHeader = @{ Authorization = "Bearer $apiToken" }
            Invoke-RestMethod -Uri "https://$jamfUrl/api/v1/auth/invalidate-token" -Method Post -Headers $authHeader
        } 
        catch {
            [JamfVendor]::WriteLog("Error: InvalidateToken $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "TokenLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            throw $_
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of available mobile device configuration profiles. List is returned as an object. Works for Apple TVs as well.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token
    #>
    static [PSCustomObject] GetMobileConfigurationProfiles([string]$jamfUrl, [string]$apiToken) {
        $fullUrl = "https://$jamfUrl/JSSResource/mobiledeviceconfigurationprofiles"
        
        if (-not $jamfUrl -or -not $apiToken) {
            Write-Error "Jamf URL or API token invalid."
        }
 
        try {`
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            Write-Host "Caught exception: $($_.Exception.Message)"
            [JamfVendor]::WriteLog("Error: GetMobileConfigurationProfiles $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of available MacOS computer configuration profiles. List is returned as an object.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token
    #>
    static [PSCustomObject] GetComputerConfigurationProfiles([String]$jamfUrl, [String]$apiToken) {
        $fullUrl = "https://$jamfUrl/JSSResource/osxconfigurationprofiles"

        if (-not $jamfUrl -or -not $apiToken) {
            Write-Error "Jamf URL or API token invalid."
        }
        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
        
            [JamfVendor]::WriteLog("Error: GetComputerConfigurationProfiles $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all apps installed iPadOS devices from a particular department and position. Works for Apple TVs as well.

        .PARAMETER department
        The department which the devices' users belongs to

        .PARAMETER position
        The position which the devices' users belongs to

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetUserMobileDeviceApps("Student", "Y07", "https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetUserMobileDeviceApps([String]$department, [String]$position, [String]$jamfUrl, [String]$apiToken) {
        $endPoint = "api/v2/mobile-devices"
        $fullUrl = "https://$jamfUrl/$endPoint/detail?section=GENERAL&section=USER_AND_LOCATION&section=HARDWARE&section=APPLICATIONS&page=0&page-size=2000&sort=displayName%3Aasc&filter=department%3D%3D%22$department%22%3Bposition%3D%3D%22$position%22"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetUserMobileDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetUserMobileDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all apps installed on individual MacOS devices from a particular department and position.

        .PARAMETER position
        The position which the devices' users belongs to

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetUserOSXApps("Y10", "https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetUserOSXApps([String]$position, [String]$jamfUrl, [String]$apiToken) {
        $endPoint = "api/v1/computers-inventory?section=USER_AND_LOCATION&section=APPLICATIONS&section=HARDWARE&page=0&page-size=2000&sort=general.name%3Aasc&filter=userAndLocation.position%3D%3D%22$position%22"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetUserOSXDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get

            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetUserOSXDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all iPadOS mobile device apps which are available in your Jamf instance. Works for Apple TVs as well.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetOrgMobileDeviceApps("https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetOrgMobileDeviceApps([String]$jamfUrl, [String]$apiToken) {
        $endPoint = "mobiledeviceapplications"
        $fullUrl = "https://$jamfUrl/JSSResource/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetOrgMobileDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetOrgMobileDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all MacOS apps which are available in your Jamf instance.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetOrgOSXApps("https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetOrgOSXApps([String]$jamfUrl, [String]$apiToken) {
        $endPoint = "macapplications"
        $fullUrl = "https://$jamfUrl/JSSResource/$endPoint"
        

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all macOS apps which are restricted in Jamf. This would be the 'Restricted Software' section on the Web interface

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetOrgOSXApps("https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetRestrictedOSXApps([String]$jamfUrl, [String]$apiToken) {
        $endPoint = "restrictedsoftware"
        $fullUrl = "https://$jamfUrl/JSSResource/$endPoint"
        

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all MacOS apps from the Jamf catalogue. This would be the 'Jamf App Catalogue' section on the Web interface

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetJamfCatalogueApps("https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetJamfCatalogueOSXApps([String]$jamfUrl, [String]$apiToken) {
        $endPoint = "patch-software-title-configurations"
        $fullUrl = "https://$jamfUrl/api/v2/$endPoint"
        
        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns inventory details for a specified OSX device.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token
        
        .PARAMETER MacbookID
        The "Jamf Pro Computer ID" for a specific OSX device.
        
        .EXAMPLE 
        $response = [JamfVendor]::GetComputerInventory("https://school.jamfcloud.com", "ABCD123", "1234")
    #>
    static [PSCustomObject] GetComputerInventory([String]$JamfUrl, [String]$apiToken, [String]$ComputerId) {
        $endpoint = "api/v1/computers-inventory-detail/$ComputerId"
        $fullUrl = "https://$JamfUrl/$endpoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetOrgOSXApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns devices within a mobile device group. Works for Apple TVs as well.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token
        
        .PARAMETER MacbookID
        The Jamf mobile device group ID
        
        .EXAMPLE 
        $response = [JamfVendor]::GetMobileDeviceGroup("https://school.jamfcloud.com", "ABCD123", "52")
    #>
    static [PSCustomObject] GetMobileDeviceGroup([String]$jamfUrl, [String]$apiToken, [String]$groupID) {
        $endPoint = "JSSResource/mobiledevicegroups/id/$groupID"
        $fullUrl = "https://$jamfUrl/$endPoint"
        
        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceGroup $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceGroup $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which pushes a Jamf command remotely to a specified iPadOS/mobile device. Works for Apple TVs as well. This function does not support parameters.
        Check 'PushMobileDeviceCommandPayload' function to see commands with parameters, and a reference for Jamf's REST API XML payload format.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token
        
        .PARAMETER deviceId
        The "Jamf Pro device ID" for a specific iPadOS/mobile device.

        .PARAMETER command
        The Command to execute on the selected device. Refer to the Jamf API references for details on what a valid command is.
        
        .EXAMPLE 
        [JamfVendor]::PushMobileDeviceCommand("https://school.jamfcloud.com", "ABCD123", "52", "RestartDevice")
    #>
    static [Void] PushMobileDeviceCommand([String]$jamfUrl, [String]$apiToken, [String]$deviceId, [String]$command) {
        $endPoint = "JSSResource/mobiledevicecommands/command/$command/id/$deviceId"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: PushMobileDeviceCommand $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken";} -Method Post -Verbose
        }
        catch {
            [JamfVendor]::WriteLog("Error: PushMobileDeviceCommand $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not push any data."
        }
    }

    <#
        .SYNOPSIS 
        Function which pushes a Jamf command remotely to a specified MacOS device. This function does not support parameters.
        Check 'PushComputerCommandPayload' function to see commands with parameters, and a reference for Jamf's REST API XML payload format.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token
        
        .PARAMETER deviceId
        The "Jamf Pro device ID" for a specific MacOS device.

        .PARAMETER command
        The Command to execute on the selected device. Refer to the Jamf API references for details on what a valid command is.
        
        .EXAMPLE 
        [JamfVendor]::PushComputerCommand("https://school.jamfcloud.com", "ABCD123", "52", "RestartDevice")
    #>
    static [Void] PushComputerCommand([String]$jamfUrl, [String]$apiToken, [String]$deviceId, [String]$command) {
        $endPoint = "JSSResource/computercommands/command/$command/id/$deviceId"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: PushComputerCommand $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken";} -Method Post
        }
        catch {
            [JamfVendor]::WriteLog("Error: PushComputerCommand $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not push any data."
        }
    }

    <#
        .SYNOPSIS 
        Function which pushes a Jamf command remotely to a specified iPadOS/mobile device. Works for Apple TVs as well. Uses parameters through an XML payload.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .PARAMETER command
        The command name for the command to be executed. It is a separate variable from the payload because the REST API URI also requires the command name.

        .PARAMETER payload
        The POST request XML payload. Contains the command name, commmand parameters and specified device to deploy it on. The payload for POST requests MUST be XML as per Jamf Legacy docs.
        GET requests can be received with both JSON or XML.
        
        .EXAMPLE 
        [JamfVendor]::PushMobileDeviceCommand("https://school.jamfcloud.com", "ABCD123", $command, $payload) 

        $command = "EnableLostMode"

        $payload = "<mobile_device_command>
                        <general>
                            <command>$command</command> #passing the command variable to avoid typing the same thing multiple times.
                            <lost_mode_message>My Message</lost_mode_message>
                            <lost_mode_phone>012345678</lost_mode_phone>
                            <lost_mode_footnote>My Footnote</lost_mode_footnote>
                            <always_enforce_lost_mode>true</always_enforce_lost_mode>
                            <lost_mode_with_sound>true</lost_mode_with_sound>
                        </general>
                        <mobile_devices>
                            <mobile_device>
                                <id>12345678</id>
                            </mobile_device>
                        </mobile_devices>
                    </mobile_device_command>"
    #>
    static [Void] PushMobileDeviceCommandPayload([String]$jamfUrl, [String]$apiToken, [String]$command, [String]$payload) {
        $endPoint = "JSSResource/mobiledevicecommands/command/$command"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: PushMobileDeviceCommandPayload $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken";} -Method Post -Body $payload -Verbose
        }
        catch {
            [JamfVendor]::WriteLog("Error: PushMobileDeviceCommandPayload $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not push any data."
        }
    }

    <#
        .SYNOPSIS 
        Function which pushes a Jamf command remotely to a specified MacOS computer.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.
        
        .PARAMETER comuterId
        The "Jamf Pro device ID" for a specific MacOS computer.

        .PARAMETER command
        The Command to execute on the selected computer. Refer to the Jamf API references for details on what a valid command is.
        
        .EXAMPLE 
        [JamfVendor]::PushComputerCommandParam("https://school.jamfcloud.com", "ABCD123", "EraseDevice/passcode/086150/id/12345")

        #Where the $command parameter contains the full parametized http query.

    #>
    static [Void] PushComputerCommandParam([String]$jamfUrl, [String]$apiToken, [String]$command) {
        $endPoint = "JSSResource/computercommands/command/$command"
        $fullUrl = "https://$jamfUrl/$endPoint"
        
        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: PushComputerCommandPayload $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken";} -Method Post -Verbose
        }
        catch {
            [JamfVendor]::WriteLog("Error: PushComputerCommandPayload $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not push any data."
        }
    }

    <#
        .SYNOPSIS 
        Function which gets a mobile device entry based on its serial number

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.
        
        .PARAMETER deviceSerial
        The serial number for a specific mobile device. Works for Apple TVs as well.
        
        .EXAMPLE 
        $mobileDevice = [JamfVendor]::GetMobileDeviceBySerial("https://school.jamfcloud.com", "ABCD123", "EFGH456")
    #>
    static [PSCustomObject] GetMobileDeviceBySerial([String]$jamfUrl, [String]$apiToken, [String]$deviceSerial) {
        $endPoint = "JSSResource/mobiledevices/serialnumber/$deviceSerial"
        $fullUrl = "https://$jamfUrl/$endPoint"

        try {
            $mobileDevice = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json"} -Method Get
            return $mobileDevice
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceBySerial $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which gets a mobile device entry based on its Jamf Device ID

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.
        
        .PARAMETER deviceId
        The "Jamf Pro device ID" for a specific mobile device. Works for Apple TVs as well.
        
        .EXAMPLE 
        $mobileDevice = [JamfVendor]::GetMobileDeviceById("https://school.jamfcloud.com", "ABCD123", "EFGH456")
    #>
    static [PSCustomObject] GetMobileDeviceById([String]$jamfUrl, [String]$apiToken, [String]$deviceId) {
        $endPoint = "JSSResource/mobiledevices/id/$deviceId"
        $fullUrl = "https://$jamfUrl/$endPoint"

        try {
            $mobileDevice = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json"} -Method Get
            return $mobileDevice
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceById $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which gets a mobile device entry based on its Wi-Fi MAC address.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.
        
        .PARAMETER macAddress
        The Wi-Fi MAC address for a specific mobile device. Works for Apple TVs as well.
        
        .EXAMPLE 
        $mobileDevice = [JamfVendor]::GetMobileDeviceByMac("https://school.jamfcloud.com", "ABCD123", "EFGH456")
    #>
    static [PSCustomObject] GetMobileDeviceByMac([String]$jamfUrl, [String]$apiToken, [String]$macAddress) {
        $endPoint = "JSSResource/mobiledevices/macaddress/$macAddress"
        $fullUrl = "https://$jamfUrl/$endPoint"

        try {
            $mobileDevice = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json"} -Method Get
            return $mobileDevice
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceByMac $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all iPadOS devices from a particular department and position. Works for Apple TVs as well.

        .PARAMETER department
        The department which the devices' users belongs to

        .PARAMETER position
        The position which the devices' users belongs to

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetMobileDevicesByUserType("Student", "Y07", "https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetMobileDevicesByUserType([String]$department, [String]$position, [String]$jamfUrl, [String]$apiToken) {
        $endPoint = "api/v2/mobile-devices"
        $fullUrl = "https://$jamfUrl/$endPoint/detail?section=GENERAL&section=USER_AND_LOCATION&section=HARDWARE&page=0&page-size=2000&sort=displayName%3Aasc&filter=department%3D%3D%22$department%22%3Bposition%3D%3D%22$position%22"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetUserMobileDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetUserMobileDeviceApps $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a 2D array of all mobile devices in your Jamf MDM instance.
        Each entry in the outer array denotes a page of devices in the Jamf instance with 1000 mobile device page size.
        Each entry within each inner array denotes json output containing device entries, represented as a PSCustomObjects. 

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.
        
        .EXAMPLE 
        $devices = [JamfVendor]::GetMobileDevices "https://school.jamfcloud.com", "ABCD123")
    #>
    static [PSCustomObject[]] GetMobileDevices([String]$jamfUrl, [String]$apiToken) {
        $pageNumber = 0
        $devices = @()
        $response = " "
        try {
            do {
                $endPoint = "api/v2/mobile-devices/detail?section=GENERAL&section=USER_AND_LOCATION&section=HARDWARE&page-size=1000&page=$pageNumber"
                $fullUrl = "https://$jamfUrl/$endPoint"
                
                $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; ContentType = "application/json"} -Method Get -Verbose
                if($response.results.Count -gt 0) {
                    $devices += $response
                    $pageNumber++
                }
            } while($response.results.Count -gt 0)
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetMobileDevices $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API request failed on page $pageNumber."
            throw $_
        }
        
        return $devices
    }

    <#
        .SYNOPSIS 
        Function which returns a 2D array of all computers in your Jamf MDM instance.
        Each entry in the outer array denotes a page of computers in the Jamf instance with 1000 computer page size.
        Each entry within each inner array denotes json output containing computer entries, represented as a PSCustomObjects. 

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.
        
        .EXAMPLE 
        $computers = [JamfVendor]::GetComputers "https://school.jamfcloud.com", "ABCD123")
    #>
    static [PSCustomObject[]] GetComputers([String]$jamfUrl, [String]$apiToken) {
        $pageNumber = 0
        $computers = @()
        $response = " "
        
        try {
            do {
                $endPoint = "api/v3/computers-inventory?section=GENERAL&section=HARDWARE&section=USER_AND_LOCATION&page-size=1000&page=$pageNumber"
                $fullUrl = "https://$jamfUrl/$endPoint"

                $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; ContentType = "application/json"} -Method Get -Verbose
                if($response.results.Count -gt 0) {
                    $computers += $response
                    $pageNumber++
                }
            } while($response.results.Count -gt 0)
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetComputers $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            throw $_
        }

        return $computers
    }

    <#
        .SYNOPSIS 
        Function which returns a list of all MacOS devices from a particular department and position.

        .PARAMETER department
        The department which the computers' users belongs to

        .PARAMETER position
        The position which the computers' users belongs to

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .EXAMPLE 
        $response = [JamfVendor]::GetComputersByUserType("Student", "Y10", "https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetComputersByUserType([String]$department, [String]$position, [String]$jamfUrl, [String]$apiToken) {
        $computers = [JamfVendor]::GetComputers($jamfUrl, $apiToken)

        $computersByType = $computers.results | Where-Object { ($_.userAndLocation.position -eq $position) -and ($_.userAndLocation.department -eq $department) }

        if($computersByType) {
            return $computersBytype
        }
        else {
            Write-Warning "No computers could be found under $department and $position"
            return "No computers found"
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a MacOS device based on serial number.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token

        .PARAMETER computerSerial
        The serial number for the MacOS device

        .EXAMPLE 
        $response = [JamfVendor]::GetComputerBySerial("https://school.jamfcloud.com", "12345ABCD", "1234ABCD")
    #>
    static [PSCustomObject] GetComputerBySerial([String]$jamfUrl, [String]$apiToken, [PSCustomObject[]]$computerList, [String]$computerSerial) {
        $computerFound = @{}
        $computerSerial
        foreach($page in $computerList) {
            $computerFound = $page.results | Where-Object { $_.hardware.serialNumber -eq $computerSerial }
            return $computerFound
        }
        Write-Warning "Computer $computerSerial could not be found by serial number."
        return $computerFound
    }
    <#
        .SYNOPSIS 
        Function which modifies the fields (name, assigned user, department, position, location, etc.) for a mobile device. 
        This data can modify any detail field.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.

        .PARAMETER jsonSchema
        The patch json data used to modify the fields on a device.

        .EXAMPLE 
        [JamfVendor]::UpdateMobileDeviceFields("https://school.jamfcloud.com", "12345ABCD", "1234", $schema)

        #Where a valid json schema example for mobile devices would be:

        $schema ='
            {
                "name": "Device Name"
                "enforceName": true
            }'
    
        ##
        #.  See 'https://your.jamf.url/api/doc/#/mobile-devices/patch_v2_mobile_devices__id_' in the v2 API reference for a full list of modifiable
        #.  fields in a schema for mobile devices.
        ##
    #>
    static [Void] UpdateMobileDeviceFields([String]$JamfUrl, [String]$apiToken, [String]$deviceId, [String]$jsonSchema) {
        $endPoint = "api/v2/mobile-devices/$deviceId"
        $fullUrl = "https://$jamfUrl/$endPoint"
        
        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: PatchMobileDevice $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            Invoke-RestMethod -Uri $fullUrl -Method PATCH -Body $jsonSchema -ContentType 'application/json' -Headers @{Authorization = "Bearer $apiToken"} -Verbose
        }  
        catch {
            [JamfVendor]::WriteLog("Error: PatchMobileDevice $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not push any data."
        }
    }
    
    <#
        .SYNOPSIS 
        Function which modifies the fields (name, assigned user, department, position, location, etc.) for a computer. 
        This data can modify any detail field.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.

        .PARAMETER jsonSchema
        The patch json data used to modify the fields on a device.

        .EXAMPLE 
        [JamfVendor]::UpdateComputerFields("https://school.jamfcloud.com", "12345ABCD", "1234", $schema)

        #Where a valid json schema example for mobile devices would be:

        $schema ='
            {
                "name": "Device Name"
                "enforceName": true
            }'
    
        ##
        #.  See 'https://your.jamf.url/api/doc/#/computer-inventory/patch_v3_computers_inventory_detail__id_ in the v2 API reference for a full list of modifiable
        #.  fields in a schema for computers.
        ##
    #>
    static [Void]UpdateComputerFields([String]$JamfUrl, [String]$apiToken, [String]$computerId, [String]$JsonSchema) {
        $endPoint = "api/v3/computers-inventory-detail/$computerId"
        $fullUrl = "https://$jamfUrl/$endPoint"
        
        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: PatchMobileDevice $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            Invoke-RestMethod -Uri $fullUrl -Method PATCH -Body $jsonSchema -ContentType 'application/json' -Headers @{Authorization = "Bearer $apiToken"} -Verbose
        }  
        catch {
            [JamfVendor]::WriteLog("Error: PatchMobileDevice $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not push any data."
        }
    }

    <#
        .SYNOPSIS 
        Function which returns a list of restricted software in your MDM instance.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.

        .EXAMPLE 
        [JamfVendor]::GetRestrictedSoftware("https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetComputerRestrictedSoftware([String]$JamfUrl, [String]$apiToken) {
        $restrictedsoftware = " "

        $endPoint = "JSSResource/restrictedsoftware"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetRestrictedSoftware $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $response = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
            return $response
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetRestrictedSoftware $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }

        return $restrictedsoftware
    }

    <#
        .SYNOPSIS 
        Function which returns a list of MacOS policies in your MDM instance.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.

        .EXAMPLE 
        [JamfVendor]::GetComputerPolicies("https://school.jamfcloud.com", "12345ABCD")
    #>
    static [PSCustomObject] GetComputerPolicies([String]$JamfUrl, [String]$apiToken) {
        $restrictedsoftware = " "

        $endPoint = "JSSResource/policies"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetComputerPolicies $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $restrictedsoftware = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetComputerPolicies $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }

        return $restrictedsoftware
    }

    <#
        .SYNOPSIS 
        Function which returns a list of the mobile device groups in your MDM instance.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.

        .EXAMPLE 
        [JamfVendor]::GetMobileDeviceGroups("https://school.jamfcloud.com", "12345ABCD")
    #>
    static[PSCustomObject] GetMobileDeviceGroups($jamfUrl, $apiToken) {
        $mobiledevicegroups = ""

        $endPoint = "JSSResource/mobiledevicegroups"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceGroups $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $mobiledevicegroups = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetMobileDeviceGroups $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }

        return $mobiledevicegroups
    }

    <#
        .SYNOPSIS 
        Function which returns a list of the mobile device groups in your MDM instance.

        .PARAMETER jamfURL
        The Jamf domain/link for your MDM instance.

        .PARAMETER apiToken
        The Jamf API token.

        .EXAMPLE 
        [JamfVendor]::GetComputerGroups("https://school.jamfcloud.com", "12345ABCD")
    #>
    static[PSCustomObject] GetComputerGroups($jamfUrl, $apiToken) {
        $computergroups = ""

        $endPoint = "JSSResource/computergroups"
        $fullUrl = "https://$jamfUrl/$endPoint"

        if (-not $jamfUrl -or -not $apiToken) {
            [JamfVendor]::WriteLog("Error: GetComputerGroups $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Error "Jamf URL or API token invalid."
        }

        try {
            $computergroups = Invoke-RestMethod -Uri $fullUrl -Headers @{Authorization = "Bearer $apiToken"; accept = "application/json" } -Method Get
        }
        catch {
            [JamfVendor]::WriteLog("Error: GetComputerGroups $($_.Exception.Message) at $(Get-Date -Format 'HH:mm:ss')", "ResponseLog-$(Get-Date -Format 'dd-MMMM-yyyy').txt")
            Write-Warning "API response did not bear any data."
            return "No response"
        }

        return $computergroups
    }

}