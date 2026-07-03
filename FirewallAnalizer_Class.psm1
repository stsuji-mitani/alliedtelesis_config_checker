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


class ARCONFIG{
    
    $filename =""
    $zonelist=@{}
    $filewalllist=[System.Collections.Generic.List[PSCustomObject]]::new()
    # フラグ初期化
    [string]$zoneflag = ""
    [bool]$firewallflag = $false
    ARCONFIG(){
    }
    

    [string]startzone($line) {
        $flag = ""
        if($line -match "^zone (.*$)$"){
            $name = $Matches[1]
            $z1 = [ZONE_DATA]::new($name)
            $this.zonelist.add($name , $z1)
            $flag = $name
        }
        return $flag
    }


    [string]readzone($line,$indexname){
        
        # 行を分析して、オブジェクトを定義していく。
        if ($line -match "^ network (.*$)$"){
            $this.zonelist[$indexname].AddNetwork($Matches[1])
        }elseif($line -match "^ *ip subnet (.*$)$"){
            $this.zonelist[$indexname].nwlist[-1].AddIpSubnet($Matches[1])
        }elseif($line -match "^ *host (.*$)$"){
            $this.zonelist[$indexname].nwlist[-1].AddHost($Matches[1])
        }elseif($line -match "^ *ip address (.*$)$"){
            $this.zonelist[$indexname].nwlist[-1].hosts[-1].AddIpAdress($Matches[1])
        }elseif ($line -match "^!$"){
            return ""
        }
        return $indexname
    }


    <############################################################
    ^firewall$
    行を見つけた場合、Firewallブロックに入ったとして、フラグを立てる
    #############################################################>
    [bool]startfirewall($line){
        $flag = $false
        if($line -match "^firewall$"){
            $flag = $true
        }
        return $flag
    }

    <#############################################################
    行を読み込み、各処理を実施
    1) ^!$ 
    Firewallブロックを抜けたとして、フラグを解除する
    2) \s*protect$
    システム全体でFirewallが有効
    3) そのほか
    Firewallルールを分析し、PSCustomObject格納して、グローバル変数(配列)に追加する。
    例： rule 10 permit ping from public to public
    
    #############################################################>
    [bool]readfirewall($line){
        $res = $true
        if ($line -match "^!$"){
            $res = $false
        }elseif($line -match "\s*protect$"){
            
        }else{
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

            $this.filewalllist.Add($rule)
        }
        
        return $res
    }


    <#
    受け取った名前から、ゾーン情報(PSCustomObject[])を返す。
    zone.network.host

    #>
    [PSCustomObject[]]splitaddres($ob){
        #  "."で分割して、エントリー記述（zone.network.host）のどこまでが指定されているかを判断する。
        $t1 = $ob -split "\."
        $res = @()
        #$res = [PSCustomObject[]]::new()
        
        if($t1.count -eq 1){
            # FROMノードがゾーン名指定
            # ゾーン名でゾーン定義を選択
            #return $zonelist[$t1[0]].nwlist.GetList()
            $res= $this.zonelist[$t1[0]].GetList()
           
        
        }elseif($t1.count -eq 2){
            # FROMノードがネットワーク名指定
            # ゾーン名と、ネットワーク名で、ゾーン定義を選択し、ルールを可読化
            foreach($n1 in $this.zonelist[$t1[0]].nwlist){
                if($n1.name -eq $t1[1]){
                    $res = $n1.GetList()
                }
            }
        }elseif($t1.count -eq 3){
            # FROMノードがHOST名指定
            $zonename = $t1[0]
            $hostname = $t1[2]

            foreach($ns1 in $this.zonelist[$zonename].nwlist){ #zoneリストのうち、1つが選択され、NETWORK一覧を処理。
                foreach($n1 in $ns1.where({$_.name -eq $t1[1]})){ # NETWORKのうち、1つが選択され、ホスト一覧を処理。 
                    foreach($h1 in $n1.hosts.where({$_.name -eq $hostname})){ # HOSTのうち、1つが選択され、IPアドレス一覧を処理。
                        $res = $h1.GetList() 
                    }
                }
            }
            #>
        }   
    
        return $res
    
    }


    [void]ReadConfig($filename){
        # Configファイルを読み込む
        
        foreach($line in get-content -path $filename){    
            if($this.zoneflag -ne ""){
                # zone定義ブロックを処理する
                $this.zoneflag     = $this.readzone($line, $this.zoneflag)
            }elseif($this.firewallflag -ne $false){
                # firewallブロックを処理する
                $this.firewallflag = $this.readfirewall($line)
            }else{
                # GlobalなConfigエリア用
                $this.zoneflag     = $this.startzone($line)
                $this.firewallflag = $this.startfirewall($line)
                # ホスト名定義
                # VLAN一覧
                # NAT
                # PBR
                # interface(port)
                # interface (vlan)
                # interface tunnel
                # Static Route

            }
        }


    }

    <#
    Firewallオブジェクトの各エントリをアドレス表記に置き換える。
    $ruleはconfig上は、1行に該当する。
    #>
    [void]ReadableFirewall([PSCustomObject]$rule){
        
        $fromob = $this.splitaddres($rule.FROM)
        $toob = $this.splitaddres($rule.TO)

        Write-Host "NO,ACTION,APP,FROM:ZONE,FROM:SUBNET,TO:ZONE,TO:SUBNET,STATEFULL"
        foreach ($from in $fromob){
            foreach($to in $toob){
                Write-Host ("{0},{1},{2},{3},{4},{5},{6},{7}" `
                -f @($rule.NO,$rule.ACTION,$rule.APP,`
                $from.ZONE,$from.IPSUBNET,`
                $to.ZONE,$to.IPSUBNET,$rule.STATE))
            }
        }
    }



    [void]ExportCSVfromFirewall(){
        foreach($a in $this.filewalllist){
            $this.ReadableFirewall($a)
        }
    }

}






