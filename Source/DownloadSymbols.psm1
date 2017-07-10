Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unzip($zipFile, $unzipFile)
{
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $unzipFile)
}

function Download($uri, $outputFile)
{
    Write-Host "Downloading: $uri"
    Write-Host "To:          $outputFile"
    Invoke-WebRequest -Uri $uri -OutFile $outputFile
}

function CreateDirectory($directory)
{
    $directoryExists = Test-Path($directory) 
    if($directoryExists -ne $True)
    {
        md -force $directory
    }
}

function DownloadPackages
{
    $uri = "https://www.nuget.org/api/v2/Search()?$orderby=Id&$skip=0&$top=30&searchTerm='Miruken'&targetFramework=''"
    $response = Invoke-RestMethod -Uri $uri -Method GET

    $sources = $response.content.src

    foreach($package in $response.GetEnumerator()){
        $uri  = $package.content.src
        $name = $package.title.InnerText
        $zip  = "$($package.title.InnerText).zip"

        Write-Host "Dowloading $url"
        Write-Host "To $name"

        Invoke-WebRequest -Uri $uri -OutFile $name
    }
}

function PackageDirectory($symbolFolder, $packageName, $version)
{
    return "$symbolFolder/packages/$packageName/$version"
}

function DownloadPackage($symbolFolder, $packageName, $version)
{
    $directory = PackageDirectory $symbolFolder $packageName $version
    CreateDirectory $directory
    
    $zip      = "$directory/$packageName.zip" 
    $unzipped = "$directory/$packageName" 

    $uri = "https://www.nuget.org/api/v2/package/$packageName/$version"
    Download $uri $zip
    Unzip    $zip $unzipped
}

function GetHash($symbolFolder, $packageName, $version)
{
    $packageDirectory = PackageDirectory $symbolFolder $packageName $version
    $headers = dumpbin /headers "$packageDirectory/$packageName/lib/net461/$packageName.dll"
    $line = $headers -match '{'
    $line[0] -match '(?<={)(.*)(?=})'
    $guid = $matches[0]
    $guid = $guid.Replace("-", "")
    $line[0] -match '(?<=},)(.*)(?=,)'
    $build = $matches[0].Trim()
    return "$guid$build"
}

function PdbDirectory($symbolFolder, $assemblyName, $version)
{
    return "$symbolFolder/$assemblyName.pdb/$version" 
}

function Pd_($symbolFolder, $assemblyName, $version)
{
    return "$(PdbDirectory $symbolFolder $assemblyName $version)/$assemblyName.pd_" 
}

function Pdb()
{
    return "$(PdbDirectory $symbolFolder $assemblyName $version)/$assemblyName.pdb" 
}

function DownloadPdb($symbolFolder, $assemblyName, $version)
{
    CreateDirectory(PdbDirectory $symbolFolder $assemblyName $version)

    $uri = "https://nuget.smbsrc.net/$assemblyName.pdb/$version/$assemblyName.pd_"
    $pd_ = Pd_ $symbolFolder $assemblyName $version
    $pdb = Pdb $symbolFolder $assemblyName $version
    Download $uri $pd_
    expand   $pd_ $pdb
}

function DownloadSourceFiles($symbolFolder, $assemblyName, $version)
{
    $pdb = Pdb $symbolFolder $assemblyName $version

    $srcsrv = pdbstr -r -p:$pdb -s:srcsrv
    $files = $srcsrv | where{$_ -like '*.cs*'}

    foreach($file in $files.GetEnumerator()){
        $parts = $file.Split("*")   
        DownloadSourceFile $symbolFolder $parts[0] $parts[1]
    }
}

function DownloadSourceFile($symbolFolder, $filePath, $hash)
{
    $file = Split-Path $filePath -leaf

    $directory = "$symbolFolder/src/src/$file/$hash/"
    CreateDirectory $directory

    $uri  = "https://nuget.smbsrc.net/src/$($file)/$($hash)/$($file)"
    Download $uri "$directory/$file"
}

function Get-Symbols
{
    Param(
        [Parameter(Mandatory=$true)]
        $packageName,
        [Parameter(Mandatory=$true)]
        $version
    )

    $symbolFolder = "C:/temp/symbols"
    
    DownloadPackage $symbolFolder $packageName $version
    $hash = (GetHash $symbolFolder $packageName $version)[-1]
    DownloadPdb         $symbolFolder $packageName $hash
    DownloadSourceFiles $symbolFolder $packageName $hash
}


Export-ModuleMember -function Get-Symbols