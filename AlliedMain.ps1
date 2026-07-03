

using module ".\FirewallAnalizer_Class.psm1"
param($filename)






function main{
    param($filename)
    
    [ARCONFIG]$a = [ARCONFIG]::new()
    $a.ReadConfig($filename)
    $a.ExportCSVfromFirewall()
    



}



main -filename $filename

