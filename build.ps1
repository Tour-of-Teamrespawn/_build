<#
.SYNOPSIS
    TOUR build helper script
.DESCRIPTION
    TOUR build helper script to automatically bump version, pack as PBO, upload to Tour via FTP & start local dedicated server
.NOTES
    Author: Andy455
    Version: v0.8
.LINK
    https://github.com/Tour-of-Teamrespawn/_build
.EXAMPLE
    .\build.ps1
    Runs the build script*, which will prompt for yes/no answers for the options, and will ask for more information if uploading to Tour FTP.
    
    *Assuming you are currently _in_ the mission folder. If not, first enter "cd c:\path\to\my\mission.Altis" substituting the actual path (you
    can copy and paste it from the file explorer)
.EXAMPLE
    .\build.ps1 -Update
    As above, this runs the build script but in the self-updating mode where it will check GitHub for the latest version and overwrite itself if
    there are any changes to be made.
    You will need to re-run the script after it has completed to ensure you are running the new version.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '')]

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory=$false)]
    [switch]$Update
)

###################################################################################################

# dot source variables file, works sort of like #include
# separating variables from code allows auto-update functionality
. "$PSScriptRoot\build.config.ps1"

###################################################################################################

if ($PSCmdlet.ShouldProcess('This script', 'Update script with latest version from GitHub')) {

    Write-Host "Getting and comparing GitHub script with this script..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $NewScriptContents = (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Tour-of-Teamrespawn/_build/main/build.ps1' -ErrorAction 'Stop').Content

    $CurrentScriptContents = Get-Content -Path $MyInvocation.MyCommand.Path -Raw

    if ($NewScriptContents -ne $CurrentScriptContents) {

        if ($Update) {

            Compare-Object -ReferenceObject ($CurrentScriptContents.split("`n")) -DifferenceObject ($NewScriptContents.split("`n")) | Out-String | Write-Verbose
            
            Write-Host "Updating this script with new file contents..."
            [System.IO.File]::WriteAllText($MyInvocation.MyCommand.Path, $NewScriptContents)
            
            Write-Host "Script has been updated, please re-run to use new code." -ForegroundColor 'Yellow'
            exit
        } else {
            Write-Host "There is a new version of the build script available, run '.\build.ps1 -Update' to update automatically." -ForegroundColor 'Yellow'
        }

    } else {
        Write-Host "Current script matches latest script, skipping update and continuing as normal..." -ForegroundColor 'Green'
    }
} else {
    Write-Verbose "Self-updater skipped"
}

$matches = $null
$ErrorActionPreference = 'Stop'
if (($null -eq $PSScriptRoot) -or ([System.String]::IsNullOrWhiteSpace($PSScriptRoot))) {
    # assume we are in the root of the mission folder (same as this file)
    $ProjectRoot = (Get-Location).Path
} else {
    $ProjectRoot = $PSScriptRoot
}
$MissionFolderName = Split-Path $ProjectRoot -Leaf

$inc_decision = $Host.UI.PromptForChoice('Increment version and make PBO?', 'Are you sure you want to proceed?', @('&Yes', '&No'), 1)
if ($inc_decision -eq 0) {
    # Automatic increment of mission version found in init.sqf, used to add to the exported PBO
    $InitSQF = Get-Content -Path (Join-Path -Path $ProjectRoot -ChildPath 'init.sqf') -Raw
    # '###MISSION_VERSION\s+(\d+\.\d+)(-(\w+))?'
    # '###MISSION_VERSION\s+(\d+\.\d+)'
    if ($InitSQF -match '###MISSION_VERSION\s+(\d+\.\d+)(-(\w+))?') {


        $ver_decision = $Host.UI.PromptForChoice('Set versioning method', 'Automatic version increment, or set manually?', @('&Automatic', '&Manual'), 0)
        if ($ver_decision -eq 0) {
            # automatic
            $Version = [System.Version]($Matches.1)
            Write-Host "Current mission version: $Version"

            $NewVersion = [System.Version]"$($Version.Major).$($Version.Minor + 1)"
            Write-Host "New mission version: $NewVersion"

        } else {
            # manual
            $NewVersion = 'NOT A REAL VERSION'
            while ($NewVersion -notmatch '^\d+\.\d+$') {
                Write-Host ""
                try {
                    $NewVersion = Read-Host "Enter the desired version in the format XX.XX, where X can be any number of digits [0-9] with a dot separating them.`nFor example: 123.123 or 1.0`nDo not include any letters or symbols" -ErrorAction 'Stop'
                    $NewVersion = [System.Version]$NewVersion
                } catch {
                    # if we fail to cast user input to a valid version, reset and try again
                    $NewVersion = 'NOT A REAL VERSION'
                }
            }
        }

        Write-Host ""

        $tag_decision = $Host.UI.PromptForChoice('Add non-release tag', 'Would you like to add a tag? This is to show test versions such as "alpha", "beta", "RC1" etc', @('&No tag (This is a playable release)', '&Add non-release tag'), 0)
        if ($tag_decision -eq 0) {
            # do nothing, no tag added so define as empty
            $TagName = ''
        } else {
            # request
            $TagName = 'NOT A REAL TAG'
            while ($TagName -notmatch '^[a-zA-Z]+$') {
                Write-Host ""
                try {
                    $TagName = Read-Host "Enter the desired tag name, it must only be lowercase [a-z] or UPPERCASE [A-Z].`nFor example: beta or RC1`nDo not include any numbers, special characaters or spaces." -ErrorAction 'Stop'
                } catch {
                    # if we fail to read input, reset
                    $TagName = 'NOT A REAL TAG'
                }
            }
            if (![string]::IsNullOrWhiteSpace($TagName)) {
                $TagName = "-$TagName"
            }
        }
        
        if ($PSCmdlet.ShouldProcess('All matching files', 'Update all references to version')) {
            $NewInitSQF = ($InitSQF -replace '###MISSION_VERSION\s+(\d+\.\d+)(-(\w+))?', ("###MISSION_VERSION " + $NewVersion + $TagName)).split("`n")
            # WriteAllText with joined string array instead of WriteAllLines to stop adding a CRLF to the end of file
            try {
                [System.IO.File]::WriteAllText((Join-Path -Path $ProjectRoot -ChildPath 'init.sqf'), ($NewInitSQF -join "`n")) 
            } catch {
                throw 'Failed to overwrite init.sqf with version tag. You may need to close the file and re-run the build script.' 
            }
            Write-Host 'Overwrote init.sqf with version tag successfully'

            $ExtensionsToCheckForVersion = @('.sqf', '.cpp', '.hpp', '.ext', '.sqs', '.txt', '.md')
            $allFilesToCheck = Get-ChildItem -Path $ProjectRoot -File -Recurse | Where-Object 'Extension' -In $ExtensionsToCheckForVersion

            foreach ($file in $allFilesToCheck) {
                # make sure automatic $matches variable is overwritten to null
                $matches = $null

                $FileContents = Get-Content -Path $File.FullName -Raw

                if ($FileContents -match ([regex]::Escape($MissionName_withV) + '\d+\.\d+')) {

                    $NewFileContents = ($FileContents -replace ([regex]::Escape($MissionName_withV) + '\d+\.\d+(-\w+)?'), ($MissionName_withV + $NewVersion + $TagName)).split("`n")
                    try {
                        [System.IO.File]::WriteAllText($File.FullName, ($NewFileContents -join "`n")) 
                    } catch {
                        throw "Failed to overwrite $($File.Name) with version tag. You may need to close the file and re-run the build script." 
                    }
                    Write-Host "Overwrote $($File.Name) with version tag successfully"

                } else {
                    Write-Verbose "$($File.Name) did not have a matched version. Skipping..."
                }
            }
        }

    } else {
        Write-Warning "Version missing from init.sqf. For automatic version increments add a comment somewhere in your init.sqf with a line exactly like so:`n###MISSION_VERSION 0.1`n   OR`n###MISSION_VERSION 1.1-beta'"
    }

    Write-Host ""

    if ($PSCmdlet.ShouldProcess('Mission folder', 'Pack PBO and export')) {
        Write-Host "Packing mission folder: '$MissionFolderName' to path: '$OutputPath' as '$MissionFolderName.pbo'"
        & $FileBank_EXE -dst $OutputPath $ProjectRoot

        # Get the pbo built with FileBank
        $ExportedPBO = Get-Item -Path (Join-Path -Path $OutputPath -ChildPath "$MissionFolderName.pbo")

        # insert (file name compatible) version to pbo before world
        # insert _mods_ as we pretty much always use them anyway
        # e.g. 30_tour_power_surge.Enoch.pbo -> 30_tour_power_surge_mods_0_2.Enoch.pbo
        $PBO_withVersion = $ExportedPBO.Name.SubString(0, $ExportedPBO.Name.IndexOf('.')) + '_mods' + "_v$($NewVersion.ToString().Replace('.','_'))" + $TagName.replace('-','_') + $ExportedPBO.Name.SubString($ExportedPBO.Name.IndexOf('.'))

        $ExistingNamePBO = Get-Item -Path "$OutputPath\$PBO_withVersion" -ErrorAction 'SilentlyContinue'
        if ($ExistingNamePBO) {
            Write-Host "Renaming existing PBO with version from '$PBO_withVersion' to '$PBO_withVersion.backup'"
            Rename-Item -Path $ExistingNamePBO.FullName -NewName "$PBO_withVersion.backup" -Force | Out-Null
        }

        # rename PBO to include version
        Write-Host "Renaming PBO from '$MissionFolderName.pbo' to '$PBO_withVersion'"
        $NewPBO = Rename-Item -Path $ExportedPBO.FullName -NewName $PBO_withVersion -Force -PassThru
    }

} else {
    Write-Host 'Skipping version increment and PBO make...'
}

if ($null -eq $NewPBO) {
    $Mission_Name_NoWorld = $MissionFolderName.split('.')[0]
    $NewPBO = Get-ChildItem -Path $OutputPath | Where-Object -FilterScript { $_.Name -match $Mission_Name_NoWorld } | Sort-Object -Property 'LastWriteTime' -Descending | Select-Object -First 1
    if ($null -ne $NewPBO) {
        $PBO_withVersion = $NewPBO.Name
    } 
}

Write-Host ""

# PBO UPLOAD TO ARMA 3 TOUR SERVER
if ($null -ne $PBO_withVersion) {
    $pbo_decision = $Host.UI.PromptForChoice("Upload PBO '$PBO_withVersion' to the Tour ARMA 3 server ?", 'Are you sure you want to proceed?', @('&Yes', '&No'), 1)
    if ($pbo_decision -eq 0) {
        # yes
        if ($null -eq $env:TOUR_SERVER_IP) {
            # Environment var for IP not set, prompt for response
            Write-Warning "Environment variable 'TOUR_SERVER_IP' not set, so prompting for user input"
            
            $TourServerIP = 'INVALID_VAR'
            while ($TourServerIP -notmatch '^\d+\.\d+.\d+.\d+$') {
                $TourServerIP = Read-Host 'Enter Tour server IP e.g. 1.2.3.4'
            }
        } else {
            Write-Host 'Getting Tour server IP env:TOUR_SERVER_IP'
            $TourServerIP = $env:TOUR_SERVER_IP
        }

        if ($null -eq $env:TOUR_SERVER_PORT) {
            # Environment var for port not set, prompt for response
            Write-Warning "Environment variable 'TOUR_SERVER_PORT' not set, so prompting for user input"
            $TourServerPort = 'INVALID_VAR'
            while ($TourServerPort -notmatch '^\d+$') {
                $TourServerPort = Read-Host 'Enter FTP port number for Tour server e.g. 8821'
            }
        } else {
            Write-Host 'Getting FTP port from env:TOUR_SERVER_PORT'
            $TourServerPort = $env:TOUR_SERVER_PORT
        }

        if ($null -eq $env:TOUR_FTP_USERNAME) {
            # Environment var for username not set, prompt for response
            Write-Warning "Environment variable 'TOUR_FTP_USERNAME' not set, so prompting for user input"
            $FTPUsername = ''
            while ([System.String]::IsNullOrWhiteSpace($FTPUsername)) {
                $FTPUsername = Read-Host "Enter or paste FTP username for the server '$TourServerIP'"
            }
        } else {
            Write-Host 'Getting FTP username from env:TOUR_FTP_USERNAME'
            $FTPUsername = $env:TOUR_FTP_USERNAME
        }

        if ($null -eq $env:TOUR_FTP_PASSWORD) {
            # Environment var for password not set, prompt for response
            Write-Warning "Environment variable 'TOUR_FTP_PASSWORD' not set, so prompting for user input"
            
            $FTPPassword = ''
            while ([System.String]::IsNullOrWhiteSpace($FTPPassword)) {
                $FTPPassword = Read-Host -MaskInput "Enter or paste FTP password for user '$FTPUsername'"
            }
        } else {
            Write-Host 'Getting FTP password from env:TOUR_FTP_PASSWORD'
            $FTPPassword = $env:TOUR_FTP_PASSWORD
        }

        # ensure powershell can use all the available TLS protocols (not just TLS1.0 or w.e)
        # can / probably should just set it to Tls12 but CPDeluxe did not support :|
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls13
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } ;

        
        # create the FtpWebRequest and configure it
        # ensure full path is set including desired filename
        $TourServer = "$($TourServerIP):$($TourServerPort)"
        $FTPPath = "ftp://$TourServer/$($TourServerIP)_2302/mpmissions/$PBO_withVersion"

        if ($PSCmdlet.ShouldProcess($FTPPath, 'Upload PBO to')) {
            Write-Host "Starting FTP upload to '$FTPPath'"

            try {
                $ftp = [System.Net.FtpWebRequest]::Create($FTPPath)
                $ftp = [System.Net.FtpWebRequest]$ftp
                $ftp.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
                $ftp.Credentials = New-Object System.Net.NetworkCredential($FTPUsername, $FTPPassword)
                $ftp.UseBinary = $true
                $ftp.UsePassive = $true
                $ftp.EnableSsl = $true
                # read in the file to upload as a byte array
                $content = [System.IO.File]::ReadAllBytes($NewPBO.FullName)
                $ftp.ContentLength = $content.Length
                # get the request stream, and write the bytes into it
                $rs = $ftp.GetRequestStream()
                $rs.Write($content, 0, $content.Length)
                # be sure to clean up after ourselves
                $rs.Close()
                $rs.Dispose()

                Write-Host 'FTP upload successful'
            }
            catch {
                Write-Host "Failed to upload PBO to '$FTPPath'." -ForegroundColor 'Red' -BackgroundColor Black
                Write-Host "Possible issues:" -ForegroundColor 'Red' -BackgroundColor Black
                Write-Host "`tFTP password is invalid (changed recently?)" -ForegroundColor 'Red' -BackgroundColor Black
                Write-Host "`tPBO with exact name already exists" -ForegroundColor 'Red' -BackgroundColor Black
                Write-Host "`tNetwork connectivity" -ForegroundColor 'Red' -BackgroundColor Black
                throw $_
            }
            
        }
        
    } else {
        # no
        Write-Host 'Skipping FTP upload'
    }
} else {
    Write-Warning "No PBO was generated nor one found in '$OutputPath' matching '$($MissionFolderName.split('.')[0])'. Skipping upload to Tour server..."
}
Write-Host ""

# START LOCAL DEDICATED SERVER WITH LATEST MISSIONS
$decision = $Host.UI.PromptForChoice('Start local dedicated server', 'Do you want to start up a local dedicated server?', @('&Yes', '&No'), 1)
if ($decision -eq 0) {

    if ($null -eq $NewPBO) {
        Write-Host 'NewPBO not found (didnt increment?) using last modified PBO in output folder for server config'
        $NewPBO = Get-ChildItem -Path $OutputPath -Filter '*.pbo' | Sort-Object -Property 'LastWriteTime' -Descending | Select-Object -First 1
    } else {
        Write-Host 'Using new PBO with incremented version in server config.'
    }

    if ($PSCmdlet.ShouldProcess('Local dedicated Arma 3 server', 'Update config and start server')) {

        $CurrCFG = Get-Content -Path $A3_Server_Config -Raw
        if ($CurrCFG -match 'template\s+=\s+(.*);') {
            $NewCFG = ($CurrCFG -replace $Matches.1, $NewPBO.Basename).split("`n")
    
            try {
                [System.IO.File]::WriteAllText($A3_Server_Config, ($NewCFG -join "`n")) 
            } catch {
                throw 'Failed to overwrite server config with new PBO. You may need to close the file and re-run the build script.' 
            }
            Write-Host 'Overwrote server config with version tag successfully'
        }

        & $A3_Server -config="$A3_Server_Config" -name=LocalDedicatedServer -mod="$($ClientModList -join ';')" -serverMod="$($ServerModList -join ';')"   
    }
} else {
    Write-Host 'Skip starting dedicated server'
}
