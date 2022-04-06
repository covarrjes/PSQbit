$Script:Uri = 'http://localhost:8080'
$Script:Drive = "D:/"
function Invoke-qBittorrentWebRequest {
    <#
    .SYNOPSIS
    Invoke-WebRequest wrapper for the qBittorrent API.
    #>
    [CmdletBinding()]
    param (
        [string]
        $Uri,

        [Microsoft.PowerShell.Commands.WebRequestSession]
        $Session,

        [string]
        $Method,

        [object]
        $Body,

        [object]
        $Form,

        [hashtable]
        $Headers
    )

    $requestParams = @{
        Uri         = $Uri
        WebSession  = $Session
        Method      = $Method
        Headers     = $Headers
        Body        = $Body
    }
    # Body is used for standard POST requests
    # Form is used for form data POST requests
    if ($Body) {
        $requestParams['Body'] = $Body
    }
    elseif ($Form) {
        $requestParams['Form'] = $Form
    }

    $response = Invoke-WebRequest @requestParams
    $response
}

function Initialize-qBittorrentSession {
    <#
    .SYNOPSIS
    Initializes the session variable and sets the value through login. 
    #>
    [CmdletBinding()]
    param (
        [string]
        $Username,
    
        [string]
        $Login
    )
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $sessionParams = @{
        Session     = $session
        Username    = $Username
        Login       = $Login
    }
    $session = Invoke-qBittorrentLogin @sessionParams
    $session
}

function Invoke-qBittorrentLogin {
    <#
    .SYNOPSIS
    Logs in to API and sets the session variable. 
    #>
    [CmdletBinding()]
    param (
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $Session,

        [string]
        $Username,
    
        [string]
        $Login
    )
    $authenticationBody = @{
        username    = $Username
        password    = $Login
    }
    $headers = @{
        Referer = $Script:Uri
    }
    $loginApi = "/api/v2/auth/login"
    $loginUri = "$Script:Uri$loginApi"
    $loginRequestParams = @{
        Uri     = $loginUri
        Session = $session
        Method  = "POST"
        Body    = $authenticationBody
        Headers = $headers
    }
    $qbitLogin = Invoke-qBittorrentWebRequest @loginRequestParams
    if ($qbitLogin.StatusDescription -eq "OK") {
        Write-Warning "Valid login"
    } else {
        Write-Warning "Err: Invoke-qBittorrentLogin Failed. $statusDescription"
    }
    $session
}

function Get-TorrentsList {
    <#
    .SYNOPSIS
    Retrieves all active torrents. 
    #>
    [CmdletBinding()]
    param (
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $Session
    )
    $getApi = '/api/v2/torrents/info'
    $getUri = "$Script:Uri$getApi"

    $getParams = @{
        Uri         = $GetUri
        Session     = $Session
        Method      = "GET"
    }
    $torrents = (Invoke-qBittorrentWebRequest @getParams).Content | ConvertFrom-Json
    $torrents
}

function Initialize-TorrentObjectList {
    <#
    .SYNOPSIS
    Builds a list of torrent objects using a csv. Using attributes, builds the save directory. Depends on csv build.
    #>
    [CmdletBinding()]
    param (
        [string]
        $CsvPath
    )
    $torrents = New-Object System.Collections.Generic.List[System.Object]
    $targetsCsv = Import-Csv -Path $CsvPath
    foreach ($target in $targetsCsv) {
        $torrent = @{
            Base        = $target.Base
            Subtype     = $target.Subtype
            Name        = $target.Name
            Year        = $target.Year
            Season      = $target.Season
            MagnetUri   = $target.MagnetUri
            Directory   = $null
        }
        if ($torrent.Base -eq 'movie') {
            $directory = $Script:Drive + $torrent.Base + '/' + $torrent.Subtype + '/' + $torrent.Name + ' (' + $torrent.Year + ')'
        }
        else {
            $directory = $Script:Drive + $torrent.Base + '/' + $torrent.Subtype + '/' + $torrent.Name + '/S' + $torrent.Season
        }
        if (-not(Test-Path -Path $directory)) {
            New-Item -Path $directory -ItemType Directory
        }
        $torrent.Directory = $directory
        $torrents.Add($torrent)
    }
    $torrents
}

function Add-TorrentBody {
    <#
    .SYNOPSIS
    Creates a body object with the magnetUri and save directory for a torrent.
    #>
    [CmdletBinding()]
    param (
        [pscustomobject]
        $Torrent
    )
    $body = @{
        urls        = $Torrent.MagnetUri
        savepath    = $Torrent.Directory
        tags        = $Torrent.Subtype
    }
    $body
}

function Add-TorrentsFromList {
    <#
    .SYNOPSIS
    Using the list of torrent objects, this makes form style body POST requests to add torrents. 
    #>
    [CmdletBinding()]
    param (
        [Microsoft.PowerShell.Commands.WebRequestSession]
        $Session,

        [array]
        $TorrentList
    )
    $postApi = '/api/v2/torrents/add'
    $postUri = "$Global:Uri$postApi"
    $postParams = @{
        Uri     = $postUri
        Session = $Session
        Method  = 'POST'
        Form    = $null
    }
    foreach ($torrent in $TorrentList) {
        $postParams.Form = Add-TorrentBody -Torrent $torrent
        Invoke-qBittorrentWebRequest @postParams
        Start-Sleep -Seconds 3
    }
}
