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
        $outputFile,
        $username,
        $password
    )

    Try
    {
        Write-Verbose "Downloading: $uri"
        Write-Verbose "To:          $outputFile"
 
        Create-Directory (Split-Path -Parent $outputFile) | Out-Null

        $headers
        if($username -and $password){
            $pair = "$($username):$($password)"
            $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
            $basicAuthValue = "Basic $encodedCreds"
            $headers = @{
                Authorization = $basicAuthValue
            }
        }

        $response = Invoke-WebRequest -Uri $uri -Headers $headers -UseBasicParsing

        if($response.StatusCode -eq 200){
            $response.Content | Set-Content -Encoding Byte -path $outputFile
        } else {
            Write-Verbose "Download: Non 200 response"
            return $false
        }

        Write-Verbose "Download: Succeeded"
        return $true
    }
    Catch
    {
        Write-Verbose "Download: Failed $($_.Exception)"
        return $false
    }
}
