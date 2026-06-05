using module ".\FirewallAnalizer_Class.psm1"






function main{
    param($filename)
    #$config = "C:\Users\stsuji\OneDrive\ドキュメント\scripts\e-h-ago_L3.txt"

    #$hostname = "AR4050S"
    
    [ARConfig]$a = [ARConfig]::new()
    $a.ReadConfig($filename)
    # Firewallルールを解析
    #
    #foreach($b in $a.filewalllist){
    #        $a.ReadableFirewall($b)
    #}


    $a.ExportCSVtoFirewall()
    #$a.filewalllist[7]
    #$a.ReadableFirewall($a.filewalllist[7])
    



}



main -filename "C:\Users\Administrator\Documents\alliedtelesis_config_checker\e-h-ago_L3.txt"

