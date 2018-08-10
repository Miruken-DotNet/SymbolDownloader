$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Infrastructure.ps1"

$appData        = "$env:APPDATA\miruken\symboldownloader"
$credentialPath = "$appData\credentials"


function Get-Credentials
{
    [cmdletbinding()]
    Param(
        $symbolServers,
        [switch]
        $promptForCredentials
    )

    Create-Directory $appData 

    if($promptForCredentials.IsPresent -eq $false -and (FileExists) -eq $true -and (FileWasUpdateToday) -eq $true -and (ContainsAllKeys $symbolServers) -eq $true)
    {
        return Get-CSV
    }

    $credentials = New-Object System.Collections.ArrayList

    foreach($server in ($config.symbolServers | ? {$_.enabled -eq $true -and $_.requiresAuthentication -eq $true}))
    {
        $username             = Read-Host -Prompt "Username for [$($server.name)]"
        $passwordSecureString = Read-Host -Prompt "Password for [$($server.name)]" -AsSecureString

        $obj = New-Object psobject
        $obj | Add-Member -MemberType NoteProperty -Name 'key'      -Value $server.name
        $obj | Add-Member -MemberType NoteProperty -Name 'username' -Value $username
        $obj | Add-Member -MemberType NoteProperty -Name 'password' -Value ($passwordSecureString | ConvertFrom-SecureString)
        $credentials.Add($obj)
    }

    $credentials | Export-Csv -NoTypeInformation -Path $credentialPath
    
    return Get-CsV
}

function Get-CSV
{
   $csv = Import-Csv -Path $credentialPath
   foreach($row in $csv)
   {
        $row.password = $row.password | ConvertTo-SecureString
   }
   return $csv
}

function FileExists
{
    return Test-Path $credentialPath
}

function FileWasUpdateToday
{
    return ([System.Io.fileinfo]$credentialPath).LastWriteTime.Date -ge [datetime]::Today 
}

function ContainsAllKeys
{
    $credentials = Import-Csv -Path $credentialPath
    foreach($server in ($config.symbolServers | ? {$_.enabled -eq $true -and $_.requiresAuthentication -eq $true}))
    {
        $selected = $credentials | ? {$_.key -eq $server.name}
        if($selected -eq $null -or [string]::IsNullOrEmpty($selected.username) -or [string]::IsNullOrEmpty($selected.password))
        {
            return $false
        }
    }
    return $true
}
