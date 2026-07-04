

using module ".\FirewallAnalizer_Class.psm1"
param($filename)






function main{
    param($filename)
    
    [ARCONFIG]$a = [ARCONFIG]::new()
    $a.ReadConfig($filename)
    #$a.ExportCSVfromFirewall()
    
    foreach($i in $a.vlanlist.values){
        write-host $i.print()
        #write-host $i.vlanname
    }


}



main -filename $filename

