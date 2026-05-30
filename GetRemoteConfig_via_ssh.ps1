# スイッチからConfigを収集する
# Write By Tsuji @20250922
# 以下のコマンドにより,running configを取得できるsystem(アライドテレシス AR,ARX,AT系）
#  enable
#  terminal length 0
#  sh run



# 依存モジュール
#  Posh-SSH
#   install-module Posh-SSH


# 対象をCSVファイルで渡す
# CSV format
# ip,username,password,outfile
param(
    $csvfile
    )



function main(){

    # CSVファイル内にコメントアウトに対応するため、以下の読み込み方法にする。
    $csv = Get-Content -Path $csvfile -Encoding utf8 `
      | Where-Object {
          ($_ -notlike "#*") -or ($_.Trim() -notlike "")
      } | ConvertFrom-Csv
    

    $csv | %{
        # リモート接続
        write-host ($_.ip +" config to " + $_.outfile)
        # 平文パスワードをPwsh用に変換する
        $spass = convertto-securestring -string $_.password -asplaintext -force
        $cre = New-object system.Management.Automation.pscredential($_.username,$spass)
        # SSH接続
        $sshsession = New-SSHSession -computername $_.ip -credential $cre -acceptkey
        $session = Get-SSHSession -sessionid $sshsession.sessionid
        # コマンド実行(入力待ちがないパターン）
        invoke-sshcommand -SSHSession $session -command "enable" | out-null
        invoke-sshcommand -SSHSession $session -command "terminal lengt 0" | out-null
        invoke-sshcommand -SSHSession $session -command "show run" -outvariable out | out-null
        
        # 入力待ちがある場合には以下（未作成）
        #$sshstream = new-sshshellstream -session $sshsession

        # SSH切断
        Remove-SSHSession -SessionId $sshsession.sessionid | out-null

        # 結果を出力
        $out.Output | out-file -path $_.outfile -Encoding utf8

    }
    
}


# CSVファイルの存在確認
function ExistCSV(){
    param($csv)
    if($csv -eq $null){
        write-host "CSVファイルを指定してください" -ForegroundColor Yellow
        exit
    }
    if(-not (test-path $csv)){
        write-host "CSVファイルが存在しません" -ForegroundColor Yellow
        exit
    }
}


## MAIN #####################################

ExistCSV -csv $csvfile

main




# FINISH #


