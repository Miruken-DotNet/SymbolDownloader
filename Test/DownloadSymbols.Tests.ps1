$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\DownloadSymbols.ps1"

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

Describe "Get-Hash" {
    It "Should return hash" {
        Get-Hash "$test/Miruken.dll" | Should Be "AC609D0195BE4EB3935B7C6BE0A6D2601"
    }
}

Describe "Join-Parts" {
    It "Should add missing /" {
        Join-Parts "a","b" | Should Be "a/b"
    }

    It "Should not duplicate / from left" {
        Join-Parts "a/","b" | Should Be "a/b"
    }

    It "Should not duplicate / from right" {
        Join-Parts "a","/b" | Should Be "a/b"
    }

    It "Should not duplicate / from both" {
        Join-Parts "a/","/b" | Should Be "a/b"
    }

    It "Should specify specific seperator" {
        Join-Parts "a","b" "," | Should Be "a,b"
    }

    It "should not duplicate specific seperator" {
        Join-Parts "a,",",b" "," | Should Be "a,b"
    }
}