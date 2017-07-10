function ReadPackageFiles
{
    Param(
        [String]
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $packageName
    )

    $packageConfigs = @(Get-ChildItem -Path .\ -Recurse -Include packages.config)
    Write-Host "`r`nFound $($packageConfigs.Count) packages.config files.`r`n"

    $packageList = New-Object System.Collections.ArrayList

    foreach($packageConfig in $packageConfigs )
    {
        [Xml]$xmlDocument = Get-Content $packageConfig
        foreach($package in $xmlDocument.packages.package)
        {
            if($package.id.ToLower().Contains($packageName.ToLower())){
                $packageList.Add(@{id = $package.id; version = $package.version})
            }
        }
    }

    Write-Host "`r`nFound $($packageList.Count) packages matching [$packageName]`r`n"
}


function ReadPackage([xml]$xmlDocument, $packageName)
{
    foreach($package in $xmlDocument.packages.package)
    {
        if($package.id.ToLower().Contains($packageName.ToLower())){
            Write-Host @{id = $package.id; version = $package.version}
        }
    }
}

ReadPackageFiles "Miruken"

