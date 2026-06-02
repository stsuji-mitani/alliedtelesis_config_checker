using module ".\FirewallAnalizer_Class.psm1"




class ARConfig{
    
    $filename =""
    $zonelist=@{}
    $filewalllist=[System.Collections.Generic.List[PSCustomObject]]::new()
    # フラグ初期化
    [string]$zoneflag = ""
    [bool]$firewallflag = $false
    ARConfig(){
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
        $res = $null
        if($t1.count -eq 1){
            # FROMノードがゾーン名指定
            # ゾーン名でゾーン定義を選択
            #return $zonelist[$t1[0]].nwlist.GetList()
            $res= $this.zonelist[$t1[0]].GetList()
        
        
        }elseif($t1.count -eq 2){
            # FROMノードがネットワーク名指定
            # ゾーン名と、ネットワーク名で、ゾーン定義を選択し、ルールを可読化
            foreach($z1 in $this.zonelist[$t1[0]]){
                foreach($n1 in $z1.nwlist){
                    if($n1.name -eq $t1[1]){
                       $res = $n1.GetList()
                    }
                }
            }
        }elseif($t1.count -eq 3){
            # FROMノードがHOST名指定

            foreach($z1 in $this.zonelist[$t1[0]]){ #zoneリストのうち、1つが選択される。
                $z1.nwlist|Where-Object{$_.name -eq $t1[1]}|foreach-object { # NETWORKのうち、1つが選択される。
                    foreach($h1 in $_.hosts){ # HOSTインスタンスを順に確認
                        if($h1.name -eq $t1[2]){ # HOST名が一致したら
                            $res = $h1.GetList() 
                        }
                    }
                }
            }
        }   
    
        return $res
    
    }


    [void]ReadConfig($filename){
        # Configファイルを読み込む
        #Get-Content -Path $filename | forEach-Object {
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
            }
        }


    }

    <#
    Firewallオブジェクトの各エントリをアドレス表記に置き換える。
    $ruleはconfig上は、1行に該当する。
    #>
    readablefirewall([PSCustomObject]$rule){
        
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



    [void]TestRun(){
        ### TEST Code ###
        foreach($k in $this.zonelist.Keys){
           $this.zonelist[$k].GetList()|convertto-csv
        }
        #$zonelist["fukui-city-center"].nwlist.GetList()|?{$_.NETWORK -match "252"}|%{
        #    $_
        #}
        #$zonelist["fukui-city-center"].nwlist|?{$_.name -match "252"}|%{
        #    $_
        #}

        #$this.filewalllist|convertto-csv

        $this.readablefirewall($this.filewalllist[1])
    
    }

}


function main{
    param($filename)
    #$config = "C:\Users\stsuji\OneDrive\ドキュメント\scripts\e-h-ago_L3.txt"

    #$hostname = "AR4050S"
    
    
    [ARConfig]$a = [ARConfig]::new()
    $a.ReadConfig($filename)
    $a.TestRun()

    



}



main -filename "C:\Users\Administrator\Downloads\e-h-ago_L3.txt"

