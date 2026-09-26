param($path)

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
    #[System.Collections.Generic.Dictionary[string,[IPADDRESS[]] ]]$list
    [System.Collections.Generic.List[PSCustomObject]]$list
    FIREWAREMODE(){
        $this.list = [System.Collections.Generic.List[PSCustomObject]]::new()
    }
    decode($line){
        if($line -match "\s*protect$"){
            return
        }

        $rule_number = 0
        $rule_action = ""
        $rule_app = ""
        $rule_from = ""
        $rule_to = ""
        $rule_state = $true
        # ルール番号の切り出し
        if($line -match "\s*rule\s([0-9]*?)\s.*"){
            $rule_number = [int]$Matches[1]
            
        }
        # Action部分の切り出し
        if($line -match "\s*rule\s\d*\s(\D.*?)\s.*"){
            $rule_action = $Matches[1]
        }
        # Aplication部分の切り出し
        if($line -match "\s*rule\s.*\s(.*?)\sfrom.*"){
            $rule_app = $Matches[1]
        }
        # From部分の切り出し
        if($line -match "\s*rule\s.*\sfrom\s(.*?)\s.*"){
            $rule_from = $Matches[1]
        }
        # To部分の切り出し
        if($line -match "\s*rule\s.*\sto\s(.*)"){
            $t1 = $Matches[1]
            # 文末に、"no-state-enforcement"がある場合とない場合
            if($t1 -match "(.*)\sno-state-enforcement"){
                # Stateモードの切り出し
                $rule_to = $Matches[1]
                $rule_state = $false
            }else{
                $rule_to = $t1
                
            }
        }
        
        $rule = [PSCustomObject]@{
            NO     = $rule_number
            ACTION = $rule_action
            APP = $rule_app
            FROM = $rule_from
            TO = $rule_to
            STATE  = $rule_state
        }

        $this.list.add($rule)
    }


    
}



class IPADDRESS {
    #[System.Net.IPAddress]$ipaddress
    [string]$ipaddress
    [string]$dynamic 
    [string]$interface
    IPADDRESS([string]$ip){
        $this.dynamic = $false
        if($ip -match "(.*) interface (.*)$"){
            $this.ipaddress = $ip
            $this.interface = $Matches[2] 
            $this.dynamic = $true
        }else{
            $this.ipaddress = $ip
            $this.interface=""
        }
    }
}


class IPSUBNET {
    [string]$zonename = ""
    [string]$ipsubnet=""

    
    IPSUBNET([string]$zone,[string]$ipsubnet){
        $this.zonename = $zone
        $this.ipsubnet = $ipsubnet
    }

}


class NETWORK {
    $zonename = ""
    $name = ""
    $ipsubnets 
    $hosts
    $lasthostname
    
    NETWORK([string]$zonename , [string]$name){
        $this.name = $name
        $this.zonename = $zonename
        $this.ipsubnets = [System.Collections.Generic.List[IPSUBNET]]::new()
        $this.hosts = [System.Collections.Generic.Dictionary[string,[IPADDRESS[]] ]]::new()
    }

    AddIpSubnet([string]$ips){
        $t2 = [IPSUBNET]::new($this.zonename+"."+$this.name ,$ips)
        $this.ipsubnets.add($t2)
    }
    
    AddHost($name){
        $this.hosts.add($name,$null)
        $this.lasthostname = $name
    }

    AddIp([string]$ip){
        $t = [IPADDRESS]::new($ip)
        $this.hosts[$this.lasthostname] +=$t

        
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

        $LastNW = $this.nwlist.Count -1
        if($line -match "^ip subnet (.*$)$"){
            $this.nwlist[$LastNW].AddIpSubnet($Matches[1])
            return
        }
        if($line -match "^host (.*$)$"){
            $this.nwlist[$LastNW].AddHost($Matches[1])
            return
        }

        if($line -match "^ip address (.*$)$"){
            $this.nwlist[$LastNW].AddIp($Matches[1])
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
    [FIREWAREMODE]$firewall
    [VLANMODE]$vlanlist
    [string]$hostname
    ARCONFIG(){
        $this.globalmode = [GLOBALMODE]::new()
        $this.zonelist = [System.Collections.Generic.Dictionary[string, [ZONEMODE]]]::new() # 連想配列(キーは名前)
        $this.firewall = [FIREWAREMODE]::new()
    }


}


class EXPORTARCONFIG{

    EXPORTARCONFIG(){
        #$this.data = $a
    }

    [string[]]GetZone([ref]$data,$zonename,$netname,$hostname){
        # ゾーン名、サブネット名、ホスト名が指定された場合、ipアドレスを返す(List)
        $res = @()
        foreach($nw in $data.Value.zonelist[$zonename].nwlist){
            if($nw.name -eq $netname){
                #$res += $nw.ipsubnets.ipsubnet
                $res += $nw.hosts[$hostname].ipaddress
            }
        }

        return $res
    }
    
    [string[]]GetZone([ref]$data,$zonename,$netname){
        # ゾーン名、サブネット名が指定された場合、指定サブネットを返す(List)
        $res = @()
        foreach($nw in $data.Value.zonelist[$zonename].nwlist){
            if($nw.name -eq $netname){
                $res += $nw.ipsubnets.ipsubnet
            }
        }
        return $res
    }

    [string[]]GetZone([ref]$data,$zonename){
        # ゾーン名のみ指定された場合、すべてのサブネットを返す（List）
        $res = @()
        foreach($nw in $data.Value.zonelist[$zonename].nwlist){
            $res += $nw.ipsubnets.ipsubnet
            
        }
        return $res
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
    $ARCONFIG = ConvertFrom-ARConfig -FilePath $path
    $output = [EXPORTARCONFIG]::new()
    $output.GetZone([ref]$ARCONFIG,"private","TC","direct")

}

main
