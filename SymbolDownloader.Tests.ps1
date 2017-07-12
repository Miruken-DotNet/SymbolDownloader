$source = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\source"
. "$source\get-config.ps1"

Describe "Top Level" {
    It "Should have configured sourceFolder" {
    }
}
