$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\DownloadSymbols.ps1"

Describe "Get-PackageDirectory" {
    It "Should build file path" {
        Get-PackageDirectory "miruken" "1.2.3.4" | 
            Should Be "c:/temp/symbols/packages/miruken/1.2.3.4"
    }
}

Describe "Get-PdbDirectory" {
    It "Should build file path" {
        Get-PdbDirectory "miruken" "1.2.3.4" | 
            Should Be "c:/temp/symbols/miruken.pdb/1.2.3.4"
    }
}

Describe "Get-Pd_" {
    It "Should build file path" {
        Get-Pd_ "miruken" "1.2.3.4" | 
            Should Be "c:/temp/symbols/miruken.pdb/1.2.3.4/miruken.pd_"
    }
}

Describe "Get-Pdb" {
    It "Should build file path" {
        Get-Pdb "miruken" "1.2.3.4" | 
            Should Be "c:/temp/symbols/miruken.pdb/1.2.3.4/miruken.pdb"
    }
}

Describe "Get-Hash" {
    It "Should return hash" {
        Get-Hash "$test/Miruken.dll" | Should Be "AC609D0195BE4EB3935B7C6BE0A6D2601"
    }

    It "Should throw exception" {
        { Get-Hash "$test/Foo.dll" } | Should Throw "Could not find dll"
    }
}

