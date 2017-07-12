$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Get-Config"


Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unzip($zipFile, $unzipFile)
{
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $unzipFile)
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

function Download($uri, $outputFile)
{
    Try
    {
        Write-Host "Downloading: $uri"
        Write-Host "To:          $outputFile"
        Invoke-WebRequest -Uri $uri -OutFile $outputFile
    }
    Catch
    {
        Write-Warning ("`r`nFailed to Download: $uri`r`n"`
            + "To: $outputFile`r`n")
    }
}

function CreateDirectory($directory)
{
    $directoryExists = Test-Path($directory) 
    if($directoryExists -ne $True)
    {
        md -force $directory
    }
}

#function DownloadPackages
#{
#    $uri = "https://www.nuget.org/api/v2/Search()?$orderby=Id&$skip=0&$top=30&searchTerm='Miruken'&targetFramework=''"
#    $response = Invoke-RestMethod -Uri $uri -Method GET
#
#    $sources = $response.content.src
#
#    foreach($package in $response.GetEnumerator()){
#        $uri  = $package.content.src
#        $name = $package.title.InnerText
#        $zip  = "$($package.title.InnerText).zip"
#
#        Write-Host "Dowloading $url"
#        Write-Host "To $name"
#
#        Invoke-WebRequest -Uri $uri -OutFile $name
#    }
#}

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

    $Config = Get-Config

    if(-Not(Test-Path $zip))
    {
        foreach($server in  $Config.nugetServers)
        {
            $uri = Join-Parts "$server","package/$packageName/$version"
            Download $uri $zip
        }
    }
    else
    {
        Write-Host "Existing $zip"                
    }

    if((Test-Path $zip))
    {
        if(-Not (Test-Path $unzipped))
        {
            Unzip $zip $unzipped
        }
    }
    else
    {
        Write-Warning "`r`nCould not find zip file: $zip`r`n"                
    }
}

function Get-DllPath($symbolFolder, $packageName, $version){
    $packageDirectory = PackageDirectory $symbolFolder $packageName $version
    return "$packageDirectory/$packageName/lib/net461/$packageName.dll"
}

function Get-Hash()
{
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $dll
    )

    if(Test-Path $dll)
    {
        $line  = (dumpbin /headers $dll | Select-String -Pattern '{').Line 

        $guid  = (($line | Select-String -Pattern '(?<={)(.*)(?=})').Matches[0].Value) -replace "-",""
        
        $build = ($line | Select-String -Pattern '(?<=},)(.*)(?=,)').Matches[0].Value.Trim()

        return "$guid$build"
    }
    else
    {
        Write-Warning "`r`nCould not find dll: $dll`r`n"                        
        return ""
    }
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

    if(-Not(Test-Path $pd_))
    {
        Download $uri $pd_
    }
    else
    {
        Write-Host "Existing $pd_"                
    }

    if(-Not(Test-Path $pdb))
    {
        expand $pd_ $pdb
    }
    else
    {
        Write-Host "Existing $pdb"        
    }
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

    $fileName = "$directory/$file"

    if(-Not (Test-Path $fileName))
    {
        $uri  = "https://nuget.smbsrc.net/src/$($file)/$($hash)/$($file)"
        Download $uri $fileName
    }
    else
    {
        Write-Host "Existing $fileName"        
    }
}



function GetSymbolsForPackages
{
    Param(
        [String]
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $packageName
    )

    $packageConfigs = @(Get-ChildItem -Path .\ -Recurse -Include packages.config)
    Write-Host "`r`nFound $($packageConfigs.Count) [packages.config] files."

    $packageList = @{}

    foreach($packageConfig in $packageConfigs )
    {
        Write-Host "    $($packageConfig.FullName)"

        [Xml]$xmlDocument = Get-Content $packageConfig
        foreach($package in $xmlDocument.packages.package)
        {
            if($package.id.ToLower().Contains($packageName.ToLower())){
                if(-Not $packageList.ContainsKey($package.id))
                {
                    $packageList.Add($package.id, $package.version)
                }
            }
        }
    }

    Write-Host "`r`nFound $($packageList.Count) packages matching [$packageName]:"
    foreach($package in $packageList.GetEnumerator()){
        Write-Host "    $($package.Name) $($package.Value)"   
    }
    Write-Host

    foreach($package in $packageList.GetEnumerator()){
        GetSymbols $package.Name $package.Value   
    }
}

function GetSymbols
{
    Param(
        [Parameter(Mandatory=$true)]
        $packageName,
        [Parameter(Mandatory=$true)]
        $version
    )

    $symbolFolder = "C:/temp/symbols"
    
    Write-Host "`r`n**** Getting Symbols For $packageName $version ****`r`n"

    DownloadPackage $symbolFolder $packageName $version
    $hash = (Get-Hash (Get-DllPath $symbolFolder $packageName $version))[-1]
    if($hash){
        DownloadPdb         $symbolFolder $packageName $hash
        DownloadSourceFiles $symbolFolder $packageName $hash
    }
}

function Get-Symbols
{
    Param(
        $packageName,
        $version
    )

    if($PSBoundParameters.ContainsKey('packageName') -or $PSBoundParameters.ContainsKey('version'))
    {
        GetSymbols $packageName $version
    }
    elseif(@(Get-ChildItem -Path .\ -Recurse -Include packages.config).Count -gt 0)
    {
        GetSymbolsForPackages
    }
    else
    {
        Write-Warning ("`r`n`r`n"`
            + "Usage:`r`n"`
            + "    Run in a directory that contains a packages.config file or`r`n"`
            + "    Get-Symbols <packageName> <version>`r`n")
    }
}
