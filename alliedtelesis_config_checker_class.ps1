class IMODEBASE{
    decode($line){}
}

class GLOBALMODE :IMODEBASE{
    #[void]GetHostName($line){
    #    if($line -match "hostname (.*)$"){
    #        $this.data.hostname = $Matches[1]
    #    }
    #}


}
class FIREWAREMODE :IMODEBASE{

}

class IZONE{}

class IPADDRES :IZONE{
    [System.Net.IPAddress]$ipaddres
    [string]$dynamic=$false
    [string]$interface=""
    IPADDRES([string]$ip){
        $parsedIP = $null
        if ([System.Net.IPAddress]::TryParse($ip, [ref]$parsedIP)) {
            $this.ipaddres = $parsedIP
            $this.dynamic = $false
        }else{
            if($ip -match ".* interface (.*)$"){
                $this.interface = $Matches[1] 
            }
            $this.dynamic = $true
        }
    }

}

class HOST :IZONE{
    $name = ""
    $ipaddress = [System.Collections.Generic.List[IPADDRES]]::new()
    
    HOST($name){
        $this.name = $name
        
    }
    AddIpAdress([string]$ip){
        $this.ipaddress.add([IPADDRES]::new($ip))
    }
    

}

class IPSUBNET :IZONE{
    [string]$zonename = ""
    [string]$ipsubnet=""
    [string]$ifname = ""
    
    IPSUBNET([string]$zone,[string]$ipsubnet){
        $this.zonename = $zone
        $this.ipsubnet = $ipsubnet
    }

}


class NETWORK :IZONE{
    $zonename = ""
    $name = ""
    $ipsubnets 
    $hosts

    NETWORK([string]$zonename , [string]$name){
        $this.name = $name
        $this.zonename = $zonename
        $this.ipsubnets = [System.Collections.Generic.List[IPSUBNET]]::new()
        $this.hosts = [System.Collections.Generic.List[HOST]]::new()
    }

    AddIpSubnet([string]$ips){
        $t2 = [IPSUBNET]::new($this.zonename+"."+$this.name ,$ips)
        $this.ipsubnets.add($t2)
    }
    
    AddHost($name){
        $t1 = [HOST]::new($name)
        $this.hosts.add($t1)
    }

}

class ZONEMODE :IMODEBASE{
    [string]$name
    [System.Collections.Generic.List[NETWORK]]$nwlist
  

    ZONEMODE($name){
        $this.name = $name
        $this.nwlist = [System.Collections.Generic.List[NETWORK]]::new()
    }

    decode($line){
        # 行を分析して、オブジェクトを定義していく。
        if ($line -match "^network (.*$)$"){
            $this.nwlist.add([NETWORK]::new($this.name,$Matches[1]))
            return
        }
        
        if($line -match "^ip subnet (.*$)$"){
            $this.nwlist[$this.nwlist.Count - 1].AddIpSubnet($Matches[1])
            return
        }
        if($line -match "^host (.*$)$"){
            $this.nwlist[$this.nwlist.Count - 1].AddHost($Matches[1])
            return
        }

        if($line -match "^ip address (.*$)$"){
            $LastNW = $this.nwlist.Count -1
            $LastHost = $this.nwlist[$LastNW].hosts.count -1
            $this.nwlist[$LastNW].hosts[$LastHost].AddIpAdress($Matches[1])
            return
        }
        

    }
    

}

class VLANMODE :IMODEBASE{

}

class INTERFACEMODE :IMODEBASE{

}

class ARCONFIG{
    
    [GLOBALMODE]$globalmode 
    [System.Collections.Generic.Dictionary[string, [ZONEMODE]]]$zonelist 
    #[System.Collections.Generic.Dictionary[int, [FIREWAREMODE]]]$firewallrule
    [FIREWAREMODE]$firewall
    [VLANMODE]$vlanlist
    [string]$hostname
    ARCONFIG(){
        $this.globalmode = [GLOBALMODE]::new()
        $this.zonelist = [System.Collections.Generic.Dictionary[string, [ZONEMODE]]]::new() # 連想配列(キーは名前)
        $this.firewall = [FIREWAREMODE]::new()
    }


}



# 1行づつ読み、各種ブロック処理に一致している場合、
# ブロック事の専用分析を行う。
function ConvertFrom-ARConfig{
    param(
        [string]$FilePath
    )
    $data = [ARCONFIG]::new()
    [IMODEBASE]$CurrentMode = $data.globalmode
    
    # configを読み進める処理は、ここでしか行わない。
    foreach($line in get-content -path $FilePath){
        $line = $line.Trim()    
        if($line -match "^!$"){
            # Globalモードに戻る
            $CurrentMode = $data.globalmode
            continue
        }

        # グローバルモード　ー＞ サブモードへの切り替え　
        if($line -match "^zone (.*$)$"){
            $data.zonelist.add($Matches[1] , [ZONEMODE]::new($Matches[1]))
            $CurrentMode = $data.zonelist[$Matches[1]]
            continue
        }

        if($line -match "^firewall$"){
            $CurrentMode = $data.firewall
            continue
        }

        # 現モードの処理
        # CurrentModeがモード切替処理で指し示すクラスを切り替えているので、読み込み処理は1行で書ける。
        $CurrentMode.decode($line)
    }

    return $data
}



function main(){
    $ARCONFIG = ConvertFrom-ARConfig -FilePath "C:\Users\stsuji\OneDrive\ドキュメント\scripts\e-h-ago_L3.txt"
    foreach($temp in $ARCONFIG.zonelist.Keys){
        write-host $temp -ForegroundColor Blue
        foreach($a in $ARCONFIG.zonelist[$temp]){
            foreach($b in $a.nwlist){
                write-host $b.name -ForegroundColor Yellow
                write-host "  "$b.ipsubnets.ipsubnet
                foreach($c in $b.hosts){
                    write-host $c.name -ForegroundColor Red
                    write-host "   "$c.ipaddress.ipaddres 
                }
            }
        }
    }
}

main
