$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent)\source"
$test   = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\foo.ps1"

Describe "dowork" {
    It "Should have configured sourceFolder" {
        (Do-Work).sourceFolder | Should not be $null
    }
}
