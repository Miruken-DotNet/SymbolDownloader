$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\DownloadSymbols.ps1"

Describe "Get-Hash" {
    It "Should return hash" {
        Get-Hash "$test/Miruken.dll" | Should Be "AC609D0195BE4EB3935B7C6BE0A6D2601"
    }
}

