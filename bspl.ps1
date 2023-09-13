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
    引数で指定した月のP/Lを表示する。
    .parameter Month
    空白 => 現在の月
    数字 => 現在の年のMonth月
    -数字 => Month前の月
    yyyy-MM => そのまま
#>
function Out-IIMitaPL {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Month
    )

    $date = Convert-IIMitaMonth -Month $Month.Trim()

    if ($date -eq $null -or $date -eq "") {
        return
    }

    Reset-IIMitaAccountAmount -Account $global:IIMitaAccount.root

    Get-IIMitaTransactions -Month $date | Set-IIMitaAccountAmount

    $global:IIMitaAccount.root.children[@(3, 4)] | Write-IIMitaAccountAmount
}
