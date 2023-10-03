# B/S, P/L 関連の関数


<#
    .synopsis
    引数の取引の借方金額と貸方金額を勘定科目の金額変数に足す。親にも足される。
    .parameter obj
    取引
#>
function Set-IIMitaAccountAmount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $obj
    )

    process {
        $debit = $global:IIMitaAccount.table[$obj.debit_id]
        $debit.debit_amount += $obj.amount

        $parent = $debit.parent

        while ($parent -ne $null) {
            $parent.debit_amount += $obj.amount
            $parent = $parent.parent
        }

        $credit = $global:IIMitaAccount.table[$obj.credit_id]
        $credit.credit_amount += $obj.amount

        $parent = $credit.parent

        while ($parent -ne $null) {
            $parent.credit_amount += $obj.amount
            $parent = $parent.parent
        }
    }
}


<#
    .synopsis
    引数の勘定科目とその子孫の金額変数を出力する。
    .parameter Account
    出力する勘定科目
#>
function Write-IIMitaAccountAmount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Account
    )

    process {
        if ($Account.type -eq 1 -or $Account.type -eq 2) {
            $amount = $Account.debit_amount - $Account.credit_amount
        } else {
            $amount = $Account.credit_amount - $Account.debit_amount
        }

        if ($amount -eq 0) {
            return
        }

        $indent = "    " * ($Account.depth - 1)
        $line = "{0}{1} {2:N0}" -f $indent, $Account.name, $amount
        Write-Output $line

        $Account.children.foreach({
            Write-IIMitaAccountAmount $_
        })
    }
}


<#
    .synopsis
    今現在のB/Sを表示する。
#>
function Out-IIMitaBS {
    Reset-IIMitaAccountAmount -Account $global:IIMitaAccount.root

    Get-IIMitaTransactions -All | Set-IIMitaAccountAmount

    $global:IIMitaAccount.root.children[@(1, 2)] | Write-IIMitaAccountAmount
}

<#
    .synopsis
    引数で指定した年のP/Lを表示する。
    .parameter Year
    年
#>
function Out-IIMitaPLYear {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]$Year
    )

    $ToMonth = 12

    $cur_year = Get-Date -Format "yyyy"

    if ($Year -eq $cur_year) {
        $ToMonth = [int](Get-Date -Format "MM")
    }

    $pl_list = [System.Collections.ArrayList]::new()

    @(1..$ToMonth).foreach({
        Reset-IIMitaAccountAmount -Account $global:IIMitaAccount.root

        $date = "{0}-{1:00}" -f $Year, $_

        Get-IIMitaTransactions -Month $date | Set-IIMitaAccountAmount

        $obj = @{ date = $date }

        $global:IIMitaAccount.root.children[@(3, 4)] | Set-IIMitaAccountAmountObject -Table $obj

        $pl_list.Add($obj) | Out-Null
    })

    $global:IIMitaAccount.root.children[@(3, 4)] | Write-IIMitaAccountAmountList -List $pl_list
}


<#
    .synopsis
    引数で指定した月のP/Lを表示する。
    .parameter Month
    空白 => 現在の月
    数字 => 現在の年のMonth月
    -数字 => Month前の月
    yyyy => yyyy年の年間P/Lを表示する
    yyyy-MM => そのまま
#>
function Out-IIMitaPL {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Month
    )

    $Month = $Month.Trim()

    if ($Month -match "^(\d{4})$") {
        [int]$year = $Matches.1
        return Out-IIMitaPLYear $year
    }

    $date = Convert-IIMitaMonth -Month $Month

    if ($date -eq $null -or $date -eq "") {
        return
    }

    Reset-IIMitaAccountAmount -Account $global:IIMitaAccount.root

    Get-IIMitaTransactions -Month $date | Set-IIMitaAccountAmount

    $global:IIMitaAccount.root.children[@(3, 4)] | Write-IIMitaAccountAmount
}


<#
    .synopsis
    引数の勘定科目とその子孫の金額をハッシュテーブルに設定する。
    .parameter Account
    出力する勘定科目
    .parameter Table
    ハッシュテーブル
#>
function Set-IIMitaAccountAmountObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Account,
        $Table
    )

    process {
        if ($Account.type -eq 1 -or $Account.type -eq 2) {
            $amount = $Account.debit_amount - $Account.credit_amount
        } else {
            $amount = $Account.credit_amount - $Account.debit_amount
        }

        $Table[$Account.name] = $amount

        $Account.children.foreach({
            Set-IIMitaAccountAmountObject $_ $Table
        })
    }
}


<#
    .synopsis
    引数の勘定科目とその子孫の金額を出力する。
    .parameter Account
    出力する勘定科目
    .parameter List
    月ごとの金額が入ったリスト
#>
function Write-IIMitaAccountAmountList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Account,
        $List
    )

    process {
        $obj = [PSCustomObject]@{ name = $Account.name }

        $List.foreach({
            $obj | Add-Member -MemberType NoteProperty -Name $_.date -Value $_[$Account.name]
        })

        Write-Output $obj

        $Account.children.foreach({
            Write-IIMitaAccountAmountList $_ $List
        })
    }
}
