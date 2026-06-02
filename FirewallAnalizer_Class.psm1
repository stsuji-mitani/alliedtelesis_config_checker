Set-StrictMode -Version Latest

#Test

#### CLASS 定義 ######
class IPADDRES {
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
    [string]GetIP(){
        if($this.dynamic -eq $false){
            return $this.ipaddres.ToString()
        }else{
            $res = "dynamic " + $this.interface
            return $res
        }
    }
}

class HOST{
    $name = ""
    $ipaddress = [System.Collections.Generic.List[IPADDRES]]::new()
    $zonename=""

    HOST([string]$zonename,$name){
        $this.name = $name
        $this.zonename = $zonename
    }
    AddIpAdress([string]$ip){
        $t1 =[IPADDRES]::new($ip)
        $this.ipaddress.add($t1)
    }
    
    [System.Collections.Generic.List[PSCustomObject]]GetList(){
        #$csv =[System.Collections.Generic.List[PSCustomObject]]::new()
        $csv = foreach($node in $this.ipaddress){
            [PSCustomObject]@{
                ZONE = $this.zonename
                IPSUBNET = $node.GetIP() 
            }
        }
        return $csv 
    }
}

class IPSUBNET{
    [string]$zonename = ""
    [string]$ipsubnet=""
    [string]$ifname = ""
    
    IPSUBNET([string]$zone,[string]$ipsubnet){
        $this.zonename = $zone
        $this.ipsubnet = $ipsubnet
    }

}

class NETWORK{
    $zonename = ""
    $name = ""
    $ipsubnets = [System.Collections.Generic.List[IPSUBNET]]::new()
    $hosts = [System.Collections.Generic.List[HOST]]::new()

    NETWORK([string]$zonename , [string]$name){
        $this.name = $name
        $this.zonename = $zonename
    }

    AddIpSubnet([string]$ips){
        $t2 = [IPSUBNET]::new($this.zonename+"."+$this.name ,$ips)
        $this.ipsubnets.add($t2)
    }
    
    AddHost($name){
        $t1 = [HOST]::new($this.zonename+"."+$this.name+"."+$name,$name)
        $this.hosts.add($t1)
    }

    [System.Collections.Generic.List[PSCustomObject]]GetList(){
        #$csv =[System.Collections.Generic.List[PSCustomObject]]::new()
        
        $csv = foreach($node in $this.ipsubnets){
            [PSCustomObject]@{
                ZONE = $this.zonename+"."+$this.name
                IPSUBNET = $node.ipsubnet
            }
        }

        return $csv
    }
}


<#
----原文Config---
zone private
 network GIGA
  ip subnet 10.104.0.0/20
 network myself
  ip subnet 10.9.4.201/32
 network ST
  ip subnet 192.168.20.0/24
  host enkaku
   ip address 192.168.20.99
  host ftp-allow
   ip address 192.168.20.50
  host stsv
   ip address 192.168.20.254
 network TC
  ip subnet 10.11.4.0/24
  ip subnet 192.168.10.0/24
  host direct
   ip address 10.11.4.101
   ip address 10.11.4.102
   ip address 10.11.4.103
   ip address 10.11.4.104
   ip address 10.11.4.105
   ip address 10.11.4.106
   ip address 10.11.4.107
   ip address 10.11.4.108
   ip address 10.11.4.109
   ip address 10.11.4.110
-----------------------------------------


この原文は
 Zone内に、networkが複数定義されている。
 network内に、ip subnetが複数定義されている。
 ip subnet内に、hostが複数定義されている。
 host内に、ip addressが複数定義されている。
とういう構造になっている。

これをCLASSで表現するために
ZONE_DATA:ゾーンの構造データ化
 複数のnetworkを持つ。

GetObject(): 
    ゾーン名だけを指定されたときに、CustomObject[]形式で情報を返す。
    CustomObjectは、network1つに該当する。

#>

class ZONE_DATA{
    $name = ""
    
    $nwlist=[System.Collections.Generic.List[NETWORK]]::new()
    ZONE_DATA([string]$name){
        $this.name = $name
    }
    AddNetwork($name){
        $t1 = [NETWORK]::new($this.name,$name)
        $this.nwlist.add($t1)
    }
    [System.Collections.Generic.List[PSCustomObject]]GetList(){
        $csv =[System.Collections.Generic.List[PSCustomObject]]::new()
        foreach($node in $this.nwlist){
            $t1 = $node.GetList()
            foreach($t2 in $t1){
                $csv.add([PSCustomObject]@{
                    ZONE = $t2.ZONE
                    IPSUBNET = $t2.IPSUBNET
                })
            }
        }

        return $csv
    }

}








