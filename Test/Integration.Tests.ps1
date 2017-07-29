$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\DownloadSymbols.ps1"

$tags           = @("Integration")
$nuget          = "https://www.nuget.org/api/v2/"
$teamCity       = "http://build.miruken.com/guestAuth/app/nuget/v1/FeedService.svc/"
$nugetSymbols    = "https://nuget.smbsrc.net"
$teamCitySymbols = "http://build.miruken.com/app/symbols"

$config = @{
    symbolFolder = "$test\_temp"
    nugetServers = $nuget,$teamCity
    symbolServers = $nugetSymbols,$teamCitySymbols
} 

function CleanUp {
    if(Test-Path $config.symbolFolder){
        Remove-Item -Force -Recurse $config.symbolFolder
    }
}

Describe -Tag ($tags) "Get-PackageMetaData from team city" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $teamCity
        return $config
    }
    
    It "Should download package and return true" {
        $name    = "Miruken"
        $version = "1.4.1.7-prerelease"

        $data = Get-PackageMetaData $name $version
        $data.version | Should Be $version
        $data.name    | Should Be $name
        $data.zipUri  | Should Not Be $null
    }
}

Describe -Tag ($tags) "Get-PackageMetaData from nuget" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $nuget
        return $config
    }
    
    It "Should download package and return true" {
        $name    = "Miruken"
        $version = "1.4.0.3"

        $data = Get-PackageMetaData $name $version
        $data.version | Should Be $version
        $data.name    | Should Be $name
        $data.zipUri  | Should Not Be $null
    }
}

Describe -Tag ($tags) "Get-NugetPackage that exists on nuget" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $nuget
        return $config
    }
    
    It "Should download package and return true" {
        Get-NugetPackage "Miruken" "1.4.0.3" | Should Be $true
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}

Describe -Tag ($tags) "Get-NugetPackage that exists on TeamCity" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $teamCity
        return $config
    }
    
    It "Should download package and return true" {
        Get-NugetPackage "Miruken" "1.4.1.7-prerelease" | Should Be $true
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}

Describe -Tag($tags) "Get-NugetPackage that does not exist on NugetServer" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $teamCity
        return $config
    }
    
    It "Should return false" {
        Get-NugetPackage "Miruken" "1.4.0.3" | Should Be $false
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}

Describe -Tag ($tags) "Get-NugetPackage that exists on last of many NugetServers" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $teamCity,$nuget
        return $config
    }
    
    It "Should download package and return true" {
        Get-NugetPackage "Miruken" "1.4.0.3" | Should Be $true
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}

Describe -Tag ($tags) "Get-NugetPackage that exists on first of many NugetServers" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $nuget,$teamCity
        return $config
    }
    
    It "Should download package and return true" {
        Get-NugetPackage "Miruken" "1.4.0.3" | Should Be $true
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}

Describe -Tag ($tags + "target") "Get-Pdb that exists on TeamCity" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.symbolServers = @($teamCitySymbols)
        return $config
    }
    
    It "Should download pdb and return true" {
        Get-Pdb "Miruken" "DAB22A3490B04F07A4BFB1F19F3F412D1" | Should Be $true
        Test-Path "$($config.symbolFolder)/Miruken.pdb/DAB22A3490B04F07A4BFB1F19F3F412D1/Miruken.pdb"
    }
}

Describe -Tag ($tags) "Get-Pdb that does not exists on TeamCity" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.symbolServers = @($teamCitySymbols)
        return $config
    }
    
    It "Should download pdb and return true" {
        Get-Pdb "Miruken" "foo" | Should Be $false
    }
}

Describe -Tag ($tags) "Get-Pdb that exists on nuget symbol server" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.symbolServers = @($nugetSymbols)
        return $config
    }
    
    It "Should download pdb and return true" {
        Get-Pdb "Miruken" "42AF557992974F988C23152957E8DE781" | Should Be $true
        Test-Path "$($config.symbolFolder)/Miruken.pdb/42AF557992974F988C23152957E8DE781/Miruken.pdb"
    }
}

Describe -Tag ($tags) "Get-Pdb that does not exists on nuget symbol server" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.symbolServers = @($nugetSymbols)
        return $config
    }
    
    It "Should download pdb and return true" {
        Get-Pdb "Miruken" "foo" | Should Be $false
    }
}

Describe -Tag ($tags) "Get-Symbols from team city that do not exist" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = @($teamCity)
        $config.symbolServers = @($teamCitySymbols)
        return $config
    }
    
    It "Should get symbols and sourc files" {
        Get-Symbols "Miruken" "1.4.0.3" | Should Be $false
    }
}

Describe -Tag ($tags) "Get-Symbols from team city that do exist" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = @($teamCity)
        $config.symbolServers = @($teamCitySymbols)
        return $config
    }
    
    It "Should get symbols and sourc files" {
        Get-Symbols "Miruken" "1.4.1.7-prerelease" | Should Be $true
        (Get-ChildItem -Recurse -Path "$($config.symbolFolder)/src" -Include *.cs).Count | Should BeGreaterThan 1
    }
}

Describe -Tag ($tags) "Get-Symbols from nuget that do exist" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers  = @($nuget)
        $config.symbolServers = @($nugetSymbols)
        return $config
    }
    
    It "Should get symbols and source files" {
        Get-Symbols "Miruken" "1.4.0.3" | Should Be $true
        (Get-ChildItem -Recurse -Path "$($config.symbolFolder)/src" -Include *.cs).Count | Should BeGreaterThan 1
    }
}

Describe -Tag ($tags) "Get-Symbols again" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers  = @($teamCity,$nuget)
        $config.symbolServers = @($teamCitySymbols,$nugetSymbols)
        return $config
    }
    
    It "Should get symbols and source files" {
        Get-Symbols "Miruken" "1.4.0.3" | Should Be $true
        Get-Symbols "Miruken" "1.4.0.3" | Should Be $true
        (Get-ChildItem -Recurse -Path "$($config.symbolFolder)/src" -Include *.cs).Count | Should BeGreaterThan 1
    }
}