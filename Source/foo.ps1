$source = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$source\Get-Config.ps1"

function do-work (){
  return Get-Config
}