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

function Write-IIMitaAccountAmount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Account,
        [Parameter(Mandatory)]
        [bool]$IsBS
    )

    process {
        if ($IsBS) {
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
            Write-IIMitaAccountAmount $_ -IsBS $IsBS
        })
    }
}

function Out-IIMitaBS {
    Reset-IIMitaAccountAmount -Account $global:IIMitaAccount.root

    Get-IIMitaTransactions -All | Set-IIMitaAccountAmount

    $global:IIMitaAccount.root.children[@(1, 2)] | Write-IIMitaAccountAmount -IsBS $true
}

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

    $global:IIMitaAccount.root.children[@(3, 4)] | Write-IIMitaAccountAmount -IsBS $false
}
