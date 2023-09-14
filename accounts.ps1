# 勘定科目関連の関数


<#
    .synopsis
    勘定科目をセットアップ(親、深さ、タイプの設定など)し、{id => 勘定科目}ハッシュテーブルを作る。
    .parameter Account
    勘定科目
    .parameter AccountTable
    {[string]id => 勘定科目}ハッシュテーブル
    .parameter NeedGroup
    need_groupな勘定科目を保存するためのリスト
    .parameter Parent
    親勘定科目
    .parameter Depth
    木構造の深さ。再帰的にこの関数が呼び出されるたびに1増える。
#>
function Set-IIMitaAccountParent {
    param (
        $Account,
        $AccountTable,
        $NeedGroup,
        $Parent = $null,
        $Depth = 0
    )

    $Account | Add-Member -MemberType NoteProperty -Name "parent" -Value $Parent
    $Account | Add-Member -MemberType NoteProperty -Name "depth" -Value $Depth
    $Account | Add-Member -MemberType NoteProperty -Name "debit_amount" -Value 0
    $Account | Add-Member -MemberType NoteProperty -Name "credit_amount" -Value 0

    if ($Account.type -eq $null) {
        $Account | Add-Member -MemberType NoteProperty -Name "type" -Value $Parent.type
    }

    if ($Account.need_group -ne $null -and $Account.need_group -eq $true) {
        $NeedGroup.Add($Account)
    }

    [string]$id = $Account.id

    if ($AccountTable.ContainsKey($id)) {
        Write-Error "Account ID の重複: $id"
    }

    $AccountTable[$id] = $Account

    $Account.children.foreach({
        Set-IIMitaAccountParent -Account $_ -AccountTable $AccountTable -NeedGroup $NeedGroup -Parent $Account -Depth ($Depth+1)
    })
}


<#
    .synopsis
    BS, PLを作るために利用する一時変数であるdebit_amountとcredit_amountを0にする。
    .parameter Account
    ルート勘定科目
#>
function Reset-IIMitaAccountAmount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Account
    )

    $Account.debit_amount = 0
    $Account.credit_amount = 0

    $Account.children.foreach({
        Reset-IIMitaAccountAmount -Account $_
    })
}


<#
    .synopsis
    accounts.jsonファイルから勘定科目データを作成する。
#>
function Import-IIMitaAccounts {
    $table = @{}
    $need_group = [System.Collections.ArrayList]::new()

    $root = Get-Content -Path $global:IIMitaAccountsFile -Raw | ConvertFrom-Json
    Set-IIMitaAccountParent -Account $root -AccountTable $table -NeedGroup $need_group

    $global:IIMitaAccount = @{
        root = $root
        table = $table
        need_group = $need_group
    }
}


# モジュール読み込み時に勘定科目をインポートしておく
Import-IIMitaAccounts


<#
    .synopsis
    勘定科目とその子孫勘定科目を表示する。
    .inputs
    表示する勘定科目
#>
function Write-IIMitaAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Account
    )

    process {
        Write-Output -InputObject "$($Account.id) $($Account.name) $($Account.search_words)"

        $Account.children.foreach({
            Write-IIMitaAccount $_
        })
    }
}


<#
    .synopsis
    勘定科目の一覧を表示してfzfで選択したものを返す。
    .parameter AccountTypes
    選択できる勘定科目のタイプを入れた配列。デフォルトはすべてのタイプ(@(1..5))。
    .outputs
    選択された勘定科目。選択がキャンセルされた場合は$null
#>
function Select-IIMitaAccount {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int[]]$AccountTypes = @(1..5)
    )

    $lines = $global:IIMitaAccount.root.children[$AccountTypes] | ForEach-Object -Process {
        $_.children | Write-IIMitaAccount
    }
    $line = $lines | fzf

    if ($line -eq $null) {
        return
    }

    return -Split $line | Select-Object -First 1
}
