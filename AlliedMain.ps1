using module ".\alliedtelesis_config_checker_class.psm1"
param($filename)







function main{
    param($filename)
    
    $ARCONFIG = ConvertFrom-ARConfig -FilePath $filename
    $output = [EXPORTARCONFIG]::new()
    #$output.GetZoneAddress($ARCONFIG,"private","TC","direct")
    $output.GetFirewallRule($ARCONFIG,10)

   
}



main -filename $filename

