function Get-Config
{
    return Get-Content "$source/config.json" | Out-String | ConvertFrom-Json
}