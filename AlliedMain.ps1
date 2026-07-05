

using module ".\FirewallAnalizer_Class.psm1"
param($filename)






function main{
    param($filename)
    
    [ARCONFIG]$a = [ARCONFIG]::new()
    $a.ReadConfig($filename)
    #$a.ExportCSVfromFirewall()
    
    #foreach($i in $a.vlanlist.values){
    #    write-host $i.print()
    #}
    foreach($i in $a.interfacelist){
        #write-host $i.name
    }

}



main -filename $filename

