$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path

"$ModuleRoot\Source\*.ps1" |
    Resolve-Path |
    Where-Object { -not ($_.ProviderPath.ToLower().Contains(".tests.")) } |
    ForEach-Object { . $_.ProviderPath }

Export-ModuleMember -function Get-Symbols