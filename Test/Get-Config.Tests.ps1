$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Get-Config.ps1"

Describe "Get-Config" {
    It "Should have configured sourceFolder" {
        (Get-Config).sourceFolder | Should not be $null
    }

    It "Should have configured nugetServers" {
        (Get-Config).nugetServers.Count | Should be 2 
    }

    It "Should have configured symbolsServers" {
        (Get-Config).symbolServers.Count | Should be 2 
    }
}
