$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\DownloadSymbols.ps1"

$tags     = @("Integration")
$nuget    = "https://www.nuget.org/api/v2/"
$teamCity = "http://build.miruken.com/guestAuth/app/nuget/v1/FeedService.svc/"

$config = @{
    symbolFolder = "c:\temp\_testSymbols"
    nugetServers = $nuget,$teamCity
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
