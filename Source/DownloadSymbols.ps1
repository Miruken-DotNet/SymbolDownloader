$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Infrastructure.ps1"

#http://build.miruken.com/guestAuth/app/nuget/v1/FeedService.svc/Search()?$filter=IsAbsoluteLatestVersion&searchTerm='miruken'&targetFramework='net46'&includePrerelease=true&$skip=0&$top=26

function Get-PackageDirectory($packageName, $version)
{
    return "$((Get-Config).symbolFolder)/packages/$packageName/$version"
}

function Get-PdbDirectory($assemblyName, $version)
{
    return "$((Get-Config).symbolFolder)/$assemblyName.pdb/$version" 
}

function Get-Pd_($assemblyName, $version)
{
    return "$(Get-PdbDirectory $assemblyName $version)/$assemblyName.pd_" 
}

function Get-Pdb($assemblyName, $version)
{
    return "$(Get-PdbDirectory $assemblyName $version)/$assemblyName.pdb" 
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

function DownloadPdb($assemblyName, $version)
{
    $uri = "https://nuget.smbsrc.net/$assemblyName.pdb/$version/$assemblyName.pd_"
    $pd_ = Pd_ $assemblyName $version
    $pdb = Pdb $assemblyName $version

    if(-Not(Test-Path $pd_))
    {
        Download-File $uri $pd_
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

function DownloadSourceFiles($assemblyName, $version)
{
    $pdb = Pdb $assemblyName $version

    $srcsrv = pdbstr -r -p:$pdb -s:srcsrv
    $files = $srcsrv | where{$_ -like '*.cs*'}

    foreach($file in $files.GetEnumerator()){
        $parts = $file.Split("*")   
        DownloadSourceFile $parts[0] $parts[1]
    }
}

function DownloadSourceFile($filePath, $hash)
{
    $file      = Split-Path $filePath -leaf
    
    $directory = "$((Get-Config).symbolFolder)/src/src/$file/$hash/"
    
    $fileName  = "$directory/$file"

    if(-Not (Test-Path $fileName))
    {
        $uri  = "https://nuget.smbsrc.net/src/$($file)/$($hash)/$($file)"
        Download-File $uri $fileName
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

    Write-Host "`r`n**** Getting Symbols For $packageName $version ****`r`n"

    if(-not(Get-NugetPackage $packageName $version)){
        Write-Warning "Could not find: $packageName $version"
        return
    }

    $hash = (Get-Hash (Get-DllPath $packageName $version))
    if($hash){
        DownloadPdb         $packageName $hash
        DownloadSourceFiles $packageName $hash
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
