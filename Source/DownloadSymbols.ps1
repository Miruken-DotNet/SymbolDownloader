﻿$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Infrastructure.ps1"

#http://build.miruken.com/guestAuth/app/nuget/v1/FeedService.svc/Search()?$filter=IsAbsoluteLatestVersion&searchTerm='miruken'&targetFramework='net46'&includePrerelease=true&$skip=0&$top=26

function Get-PackageDirectory($packageName, $version)
{
    return "$((Get-Config).symbolFolder)/packages/$packageName/$version"
}

function Get-PdbDirectory($assemblyName, $hash)
{
    return "$((Get-Config).symbolFolder)/$assemblyName.pdb/$hash" 
}

function Get-Pd_Path($assemblyName, $hash)
{
    return "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName.pd_" 
}

function Get-PdbPath($assemblyName, $version)
{
    return "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName.pdb" 
}

function Get-DllPath($packageName, $version){
    $packageDirectory = Get-PackageDirectory $packageName $version
    return "$packageDirectory/$packageName/lib/net461/$packageName.dll"
}

function Get-PackageMetaData($packageName, $version){
    foreach($server in  (Get-Config).nugetServers)
    {
        try
        {
            $uri = Join-Parts "$server","Packages(Id='$packageName',Version='$version')"
            $package = (Invoke-RestMethod -Method Get -Uri $uri).entry

            if($package){
                $data = @{
                    name    = $package.properties.id
                    version = $package.properties.version
                    zipUri  = $package.content.src
                }
                return $data
            }
            Write-Verbose "Package does not exist $packageName $version at $uri"
        }
        catch
        {
            #we will throw later if we don't find it
        }
    }
    
    throw "Package does not exist $packageName $version"
}

function Get-NugetPackage($packageName, $version)
{
    $directory = Get-PackageDirectory $packageName $version
    $zip       = "$directory/$packageName.zip" 
    $unzipped  = "$directory/$packageName" 

    if((Test-Path $zip) -and (Test-Path $unzipped)) { return $true }

    foreach($server in  (Get-Config).nugetServers)
    {
        try
        {
            $packageData = Get-PackageMetaData $packageName $version
            if(Download-File $packageData.zipUri $zip) {
                break
            }
        }
        catch
        {
        }
    }

    if((Test-Path $zip))
    {
        Unzip $zip $unzipped
        return $true
    }
    
    Write-Verbose "`r`nCould not find nuget package : $packageName $version`r`n"
    return $false
}

function Get-Hash()
{
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $dll
    )

    if(-not (Test-Path $dll)) {
        throw "Could not find dll: $dll"
    }

    $line  = (dumpbin /headers $dll | Select-String -Pattern '{').Line 

    $guid  = (($line | Select-String -Pattern '(?<={)(.*)(?=})').Matches[0].Value) -replace "-",""
        
    $build = ($line | Select-String -Pattern '(?<=},)(.*)(?=,)').Matches[0].Value.Trim()

    return "$guid$build"
}

function Get-Pdb($assemblyName, $hash)
{
    $pd_ = Get-Pd_Path $assemblyName $hash
    $pdb = Get-PdbPath $assemblyName $hash

    if(Test-Path $pdb){ return true }

    $fileTypes = ".pd_",".pdb"
    
    $found = $false
    foreach($symbolServer in ((Get-Config).symbolServers))
    {
        foreach($fileType in $fileTypes)
        {
            if(-not $found)
            {
                $uri  = Join-Parts $symbolServer,"$assemblyName.pdb/$hash/$assemblyName$fileType"
                $path = "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName$fileType" 

                if(Download-File $uri $path)
                {
                   $found = $true
                }
            }
        }
    }

    if(Test-Path $pdb){ return $true }


    if(Test-Path $pd_)
    {
        expand $pd_ $pdb | Out-Null
        return $true
    }

    return $false
}

function DownloadSourceFiles($assemblyName, $version)
{
    $pdb = Get-PdbDirectory $assemblyName $version

    $srcsrv = pdbstr -r -p:$pdb -s:srcsrv

    $uriTemplate = ($srcsrv | Select-String -Pattern SRCSRVTRG).Line.Split("=")[1].Replace("(%var1%)","")

    $files = $srcsrv | where{$_ -like '*.cs*'}
    

    foreach($file in $files.GetEnumerator()){
        $parts         = $file.Split("*")  
        $buildFilePath = $parts[0] 
        $hash      = $parts[1]
        $fileName  = Split-Path $buildFilePath -leaf
        $uri       = $uriTemplate.Replace("%fnfile%",$fileName).Replace("%var2%",$hash) 
        $directory = "$((Get-Config).symbolFolder)/src/src/$fileName/$hash/"
        $downloadFileName  = Join-Parts "$directory","$fileName"
        if(-Not (Test-Path $downloadFileName))
        {
            Download-File $uri $downloadFileName | Out-Null
        }
        else
        {
            Write-Verbose "Existing $fileName"        
        }
    }
}

function DownloadSourceFile($filePath, $hash)
{
    $file      = Split-Path $filePath -leaf
    

    if(-Not (Test-Path $fileName))
    {
        throw "need to build the uri from info in the pdb file"
        $uri  = "https://nuget.smbsrc.net/src/$($file)/$($hash)/$($file)"
        Download-File $uri $fileName
    }
    else
    {
        Write-Host "Existing $fileName"        
    }
}

function Get-SymbolsByPackages
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

function Get-SymbolsByNameAndVersion
{
    Param(
        [Parameter(Mandatory=$true)]
        $packageName,
        [Parameter(Mandatory=$true)]
        $version
    )

    Write-Host "`r`n**** Getting Symbols For $packageName $version ****`r`n"

    if(-not(Get-NugetPackage $packageName $version)){
        Write-Warning "Could not find nuget package: $packageName $version"
        return $false
    }

    $hash = (Get-Hash (Get-DllPath $packageName $version))
    if(-not $hash){
        Write-Warning "Could not get hash from dll: $packageName $version"
        return $false
    }
    
    if(-not(Get-Pdb $packageName $hash))
    {
        Write-Warning "Could not get Pdb file: $packageName $version"
        return $false
    }

    DownloadSourceFiles $packageName $hash

    return $true
}

function Get-Symbols
{
    Param(
        $packageName,
        $version
    )

    if($PSBoundParameters.ContainsKey('packageName') -or $PSBoundParameters.ContainsKey('version'))
    {
        return Get-SymbolsByNameAndVersion $packageName $version
    }
    elseif(@(Get-ChildItem -Path .\ -Recurse -Include packages.config).Count -gt 0)
    {
        return Get-SymbolsByPackages
    }
    else
    {
        Write-Warning ("`r`n`r`n"`
            + "Usage:`r`n"`
            + "    Run in a directory that contains a packages.config file or`r`n"`
            + "    Get-Symbols <packageName> <version>`r`n")
    }
}
