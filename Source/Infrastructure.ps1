function Get-Config
{
    return Get-Content "$source/config.json" | Out-String | ConvertFrom-Json
}

function Join-Parts
{
    param
    (
        $Parts = $null,
        $Separator = '/'
    )

    ($Parts | ? { $_ } | % { ([string]$_).trim($Separator) } | ? { $_ } ) -join $Separator 
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip($zipFile, $unzipFile)
{
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $unzipFile)
}

function Create-Directory($directory)
{
    $directoryExists = Test-Path($directory) 
    if($directoryExists -ne $True)
    {
        md -force $directory | Out-Null
    }
}

function Download-File
{
    [cmdletbinding()]
    Param(
        $uri,
        $outputFile
    )

    Try
    {
        Write-Verbose "Downloading: $uri"
        Write-Verbose "To:          $outputFile"
 
        Create-Directory (Split-Path -Parent $outputFile) | Out-Null

        $response = Invoke-WebRequest -MaximumRedirection 0 -Uri $uri

        if($response.StatusCode -eq 200){
            $response.Content | Set-Content -Encoding Byte -path $outputFile
        } else {
            Write-Verbose "Download: Failed"
            return $false
        }

        Write-Verbose "Download: Succeeded"
        return $true
    }
    Catch
    {
        Write-Verbose "Download: Failed"
        return $false
    }
}
