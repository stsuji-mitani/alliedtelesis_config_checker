using module ".\FirewallAnalizer_Class.psm1"






function main{
    param($filename)
    #$config = "C:\Users\stsuji\OneDrive\ドキュメント\scripts\e-h-ago_L3.txt"

    #$hostname = "AR4050S"
    
    [ARCONFIG]$a = [ARCONFIG]::new()
    $a.ReadConfig($filename)
    $a.ExportCSVtoFirewall()
    



}



main -filename "C:\Users\Administrator\Documents\alliedtelesis_config_checker\e-h-ago_L3.txt"

