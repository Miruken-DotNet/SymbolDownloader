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

function Download-File($uri, $outputFile)
{
    Try
    {
        Write-Verbose "Downloading: $uri"
        Write-Verbose "To:          $outputFile"
 
        Create-Directory (Split-Path -Parent $outputFile) | Out-Null

        Invoke-WebRequest -Uri $uri -OutFile $outputFile

        return $true
    }
    Catch
    {
        return $false
    }
}
