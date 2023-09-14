# データの保存場所
[string]$global:IIMitaData = "$HOME\.mita"

# 勘定科目ファイル
[string]$global:IIMitaAccountsFile = "$IIMitaData\accounts.json"

# 勘定科目データ
# @{
#     root = ルート勘定科目
#     table = @{ [string]id => 勘定科目 }
#     need_group = need_groupな勘定科目のリスト
# }
$global:IIMitaAccount = $null

# データベースファイル
[string]$global:IIMitaDBFile = "$IIMitaData\transactions.sqlite3"

# データベース接続文字列
[string]$global:IIMitaDBCon = "Data Source=$IIMitaDBFile"
