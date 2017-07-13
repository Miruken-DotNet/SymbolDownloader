$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\DownloadSymbols.ps1"

$tags     = @("Integration")
$nuget    = "https://www.nuget.org/api/v2/"
$teamCity = ""

$config = @{
    symbolFolder = "c:\temp\_testSymbols"
    nugetServers = $nuget,$teamCity
} 

function CleanUp {
    if(Test-Path $config.symbolFolder){
        Remove-Item -Force -Recurse $config.symbolFolder
    }
}

Describe -Tag ($tags) "Get-NugetPackage that exists from a single NugetServer" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $nuget
        return $config
    }
    
    It "Should download package" {
        Get-NugetPackage "Miruken" "1.4.0.3" | Should Be $true
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}

Describe -Tag($tags) "Get-NugetPackage that does not exist from a single NugetServer" {
    
    BeforeEach {
        Cleanup
    }

    Mock Get-Config { 
        $config.nugetServers = $teamCity
        return $config
    }
    
    It "Should download package" {
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
    
    It "Should download package" {
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
    
    It "Should download package" {
        Get-NugetPackage "Miruken" "1.4.0.3" | Should Be $true
        Test-Path "$($config.symbolFolder)/packages/miruken/1.4.0.3/Miruken.zip"
    }
}
