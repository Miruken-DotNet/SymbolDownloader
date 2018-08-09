$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Infrastructure.ps1"

$script:config = $null;

function Get-PackageDirectory
{
    [cmdletbinding()]
    Param(
        $packageName, 
        $version
    )

    return "$($config.symbolFolder)/packages/$packageName/$version"
}

function Get-PdbDirectory
{
    [cmdletbinding()]
    Param(
        $assemblyName, 
        $hash
    )
    return "$($config.symbolFolder)/$assemblyName.pdb/$hash" 
}

function Get-Pd_Path
{
    [cmdletbinding()]
    Param(
        $assemblyName, 
        $hash
    )
    return "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName.pd_" 
}

function Get-PdbPath()
{
    [cmdletbinding()]
    Param(
        $assemblyName, 
        $hash
    )
    return "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName.pdb" 
}

function Get-DllPath(){

    [cmdletbinding()]
    Param(
        $packageName,
        $version
    )

    $packageDirectory = Get-PackageDirectory $packageName $version
    $filter           = "$packageName.dll"

    $dlls = @(Get-ChildItem $packageDirectory -Include *.dll -Filter $filter -Recurse)

    if($dlls.Length -gt 0){
        return $dlls[0].FullName
    } else {
        $packageDirectory = Get-PackageDirectory $packageName $version
        return "$packageDirectory/$packageName/lib/net461/$packageName.dll"
    }
}

function Get-PackageMetaData {
    [cmdletbinding()]
    Param(
        $packageName,
        $version
    )
    foreach($server in ($config.nugetServers | ? {$_.enabled -eq $true}))
    {
        try
        {
            $uri = Join-Parts $server.uri,"Packages(Id='$packageName',Version='$version')"
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

function Get-NugetPackage
{
    [cmdletbinding()]
    Param(
        $packageName,
        $version
    )

    $directory = Get-PackageDirectory $packageName $version
    $zip       = "$directory/$packageName.zip" 
    $unzipped  = "$directory/$packageName" 

    if((Test-Path $zip) -and (Test-Path $unzipped)) { 
        Write-Verbose "Existing nuget package: $unzipped"
        return $true 
    }

    try
    {
        $packageData = Get-PackageMetaData $packageName $version
        Download-File $packageData.zipUri $zip
    }
    catch
    {
    }

    if((Test-Path $zip))
    {
        Unzip $zip $unzipped
        Write-Host "Downloaded Nuget Package $packageName $version"
        return $true
    }
    
    Write-Verbose "`r`nCould not find nuget package : $packageName $version`r`n"
    return $false
}

function Get-Hash()
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $dll
    )

    if(-not (Test-Path $dll)) {
        throw "Could not find dll: $dll"
    }

    $line  = (. "$source/lib/dumpbin/dumpbin.exe" /headers $dll | Select-String -Pattern '{').Line 

    $guid  = (($line | Select-String -Pattern '(?<={)(.*)(?=})').Matches[0].Value) -replace "-",""
        
    $build = ($line | Select-String -Pattern '(?<=},)(.*)(?=,)').Matches[0].Value.Trim()

    return "$guid$build"
}

function Get-Pdb()
{
    [cmdletbinding()]
    Param(
        $assemblyName, 
        $hash
    )

    $pd_ = Get-Pd_Path $assemblyName $hash
    $pdb = Get-PdbPath $assemblyName $hash

    if(Test-Path $pdb){ 
        Write-Verbose "Existing pdb: $pdb"
        return $true 
    }

    $found = $false
    foreach($symbolServer in ($config.symbolServers | ? {$_.enabled -eq $true}))
    {
        if(-not $found)
        {
            if($symbolServer.compressedPdb -eq $True){
                $fileType = ".pd_"
                $uri  = Join-Parts $symbolServer.uri,"$assemblyName.pdb/$hash/$assemblyName$fileType"
                $path = "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName$fileType" 

                if((Download-File $uri $path $symbolServer.username $symbolServer.password) -eq $true)
                {
                   $found = $true
                }
            }
            if($symbolServer.compressedPdb -eq $False){
                $fileType = ".pdb"
                $uri  = Join-Parts $symbolServer.uri,"$assemblyName.pdb/$hash/$assemblyName$fileType"
                $path = "$(Get-PdbDirectory $assemblyName $hash)/$assemblyName$fileType" 

                if((Download-File $uri $path $symbolServer.username $symbolServer.password) -eq $true)
                {
                   $found = $true
                }
            }
        }
    }

    if(Test-Path $pdb){
        Write-Host "Downloaded $assemblyName.pdb" 
        return $true 
    }


    if(Test-Path $pd_)
    {
        Write-Verbose "Expanding $pd_"

        . "$source/lib/expand.exe" $pd_ $pdb | Out-Null

        Write-Host "Downloaded $assemblyName.pdb" 
        return $true
    }

    return $false
}

function DownloadSourceFiles
{
    [cmdletbinding()]
    Param(
        $assemblyName, 
        $hash
    )

    $pdb = Get-PdbPath $assemblyName $hash

    $srcsrv = . "$source/lib/pdbstr.exe" -r -p:$pdb -s:srcsrv

    if(!$srcsrv)
    {
        Write-Warning "Pdb is missing symbol server meta data 'srcsrv' $pdb"
        return
    }

    #Can make this better/easier/more exact by using "srctool mypdb.pdb" to build the uri
    $srcsrvtrg = $srcsrv | Select-String -Pattern SRCSRVTRG
    if($srcsrvtrg.Line.Contains("%HTTP_EXTRACT_TARGET%"))
    {
        $httpAlias = ($srcsrv | Select-String -Pattern HTTP_ALIAS)[0].Line.Split("=")[1]
        $uriTemplate = Join-Parts $httpAlias,"%var2%"
    }
    else
    {
        $uriTemplate = ($srcsrv | Select-String -Pattern SRCSRVTRG).Line.Split("=")[1].Replace("(%var1%)","")
    }

    $files = @($srcsrv | where{$_ -like '*.cs*'})
    if($files.Length -lt 1){
        Write-Warning "No source files referenced in $pdb"
    }

    foreach($file in $files.GetEnumerator()){
        $parts         = $file.Split("*")  
        $buildFilePath = $parts[0] 
        $hash      = $parts[1]
        $fileName  = Split-Path $buildFilePath -leaf
        $uri       = $uriTemplate.Replace("%fnfile%",$fileName).Replace("%var2%",$hash)
        $uniquePath = ([System.Uri]$uri).AbsolutePath
        $downloadFileName = Join-Parts $config.symbolFolder,"src",$uniquePath
        if(-Not (Test-Path $downloadFileName))
        {
            Download-File $uri $downloadFileName | Out-Null
        }
        else
        {
            Write-Verbose "Existing file: $fileName"        
        }
    }
    Write-Host "Downloaded $($files.Length) source files"
}

function Get-SymbolsByPackages
{
    [cmdletbinding()]
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
        Get-SymbolsByNameAndVersion $package.Name $package.Value | Out-Null
    }
}

function Get-SymbolsByNameAndVersion
{
    [cmdletbinding()]
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

function Configure
{
    $script:config = Get-Content "$source/config.json" | Out-String | ConvertFrom-Json
    foreach($server in ($script:config.symbolServers | ? {$_.enabled -eq $true}))
    {
        $username = $null
        $password = $null
        if($server.requiresAuthentication){
            $username = Read-Host -Prompt "Username for [$($server.name)]"
            $password = Read-Host -Prompt "Password for [$($server.name)]" -AsSecureString
            $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        }
        Add-Member -InputObject $server -MemberType NoteProperty -Name username -Value $username
        Add-Member -InputObject $server -MemberType NoteProperty -Name password -Value $password
    }
}

function Get-Symbols
{
    [cmdletbinding()]
    Param(
        $packageName,
        $version
    )

    Configure 

    if($PSBoundParameters.ContainsKey('packageName') -and $PSBoundParameters.ContainsKey('version'))
    {
        return Get-SymbolsByNameAndVersion $packageName $version
    }
    elseif(($PSBoundParameters.ContainsKey('packageName')) -and (@(Get-ChildItem -Path .\ -Recurse -Include packages.config).Count -gt 0))
    {
        return Get-SymbolsByPackages $packageName
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
