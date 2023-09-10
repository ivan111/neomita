function Read-IIMitaDate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    process {
        $DateStr = Read-Host -Prompt $Prompt
        $DateStr = $DateStr.Trim()

        $cur = Get-Date

        if ($DateStr -eq "") {
            return Get-Date -Format "yyyy-MM-dd"
        }

        if ($DateStr -match "^(\d\d?)/(\d\d?)$") {
            [int]$month = $Matches.1
            [int]$day = $Matches.2

            if ($month -ge 1 -and $month -le 12 -and $day -ge 1 -and $day -le 31) {
                return "{0:yyyy}-{1:00}-{2:00}" -f $cur, $month, $day
            }

            Write-Error -Message ("不正な日付形式: " + $DateStr)
            return
        }

        if ($DateStr -match "^(\d\d?)$") {
            [int]$day = $Matches.1

            return "{0:yyyy}-{0:MM}-{1:00}" -f $cur, $day
        }

        if ($DateStr -match "^\-(\d)$") {
            [int]$day = $Matches.1

            return "{0:yyyy}-{0:MM}-{0:dd}" -f $cur.AddDays(-$day)
        }

        if ($DateStr -match "^(\d{4})-(\d\d?)-(\d\d?)$") {
            [int]$year = $Matches.1
            [int]$month = $Matches.2
            [int]$day = $Matches.3

            if ($month -ge 1 -and $month -le 12 -and $day -ge 1 -and $day -le 31) {
                return "{0:0000}-{1:00}-{2:00}" -f $year, $month, $day
            }

            Write-Error -Message ("不正な日付形式: " + $DateStr)
            return
        }
    }
}

# 月を表す文字列からyyyy-MM形式の文字列に変換する。
# 引数 $Month => 結果
#     空白 => 現在の月
#     数字 => 現在の年の引数の月
#     -数字 =>引数分前の月
#     yyyy-MM => そのまま
#     その他 => $null
function Convert-IIMitaMonth {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Month
    )

    $Month = $Month.Trim()
    $cur = Get-Date

    if ($Month -eq $null -or $Month -eq "") {
        return Get-Date -Format "yyyy-MM"
    }

    if ($Month -match "^(\d\d?)$") {
        [int]$mm = $Matches.1

        return "{0:yyyy}-{1:00}" -f $cur, $mm
    }

    if ($Month -match "^(\d{4})-(\d\d)$") {
        return $Month
    }

    if ($Month -match "^\-(\d)$") {
        [int]$y = $cur.Year
        [int]$m = $cur.Month
        [int]$num = $Matches.1

        if ($m - $num -ge 1) {
            $m -= $num
        } else {
            $y -= 1
            $m = $m - $num + 12
        }

        return "{0:0000}-{1:00}" -f $y, $m
    }

    return
}

function Read-IIMitaTransaction {
    do {
        $date = Read-IIMitaDate -Prompt "日付"
    } while ($date -eq $null)

    $debit_id = Select-IIMitaAccount
    if ($debit_id -eq $null) {
        return
    }

    $credit_id = Select-IIMitaAccount
    if ($credit_id -eq $null) {
        return
    }

    do {
        $amount_str = Read-Host -Prompt "金額"
        $amount_str = $amount_str.Trim()
    } while ($amount_str -notmatch "^\d+$")

    [int]$amount = $amount_str

    $note = Read-Host -Prompt "摘要"

    return @{
        date = $date
        debit_id = $debit_id
        credit_id = $credit_id
        amount = $amount
        note = $note
    }
}

function Write-IIMitaTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Transaction
    )

    $tr = $Transaction

    $debit = $global:IIMitaAccount.table[$tr.debit_id].name
    $credit = $global:IIMitaAccount.table[$tr.credit_id].name

    $line = "{0} {1} / {2} {3:N0} {4}" -f $tr.date, $debit, $credit, $tr.amount, $tr.note
    Write-Host $line
}

function Save-IIMitaTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Transaction
    )

    $con = [System.Data.SQLite.SQLiteConnection]::new($global:IIMitaDBCon)

    try {
        $con.Open()

        $tr = $Transaction

        $command = $con.CreateCommand()
        $command.CommandText = @"
INSERT INTO transactions(date, debit_id, credit_id, amount, note) VALUES
('$($tr.date)', $($tr.debit_id), $($tr.credit_id), $($tr.amount), '$($tr.note)')
"@

        $command.ExecuteNonQuery() | Out-Null
    } finally {
        $con.Close()
    }
}

function New-IIMitaTransaction {
    $tr = Read-IIMitaTransaction
    if ($tr -eq $null) {
        return
    }

    Write-IIMitaTransaction -Transaction $tr

    do {
        $a = Read-Host -Prompt "保存しますか？ (y)es, (q)uit"
        $a = $a.Trim()
    } while ($a -ne "y" -and $a -ne "q")

    if ($a -eq "q") {
        return
    }

    Save-IIMitaTransaction -Transaction $tr
}

function Get-IIMitaTransactions {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string]$Month,
        [switch]$All,
        [switch]$NeedGroup,
        [switch]$BelongToGroup
    )

    begin {
        $con = [System.Data.SQLite.SQLiteConnection]::new($global:IIMitaDBCon)

        $con.Open()
        $command = $con.CreateCommand()
    }

    process {
        if ($All) {
            $date = Get-Date -Format "yyyy-MM-dd"
            $where = "date <= '$date'"
        } elseif ($NeedGroup) {
            $date = Get-Date -Format "yyyy-MM-dd"

            $need_group = ($global:IIMitaAccount.need_group.foreach({ $_.id }) -join ",")

            $where = "date <= '$date' AND (debit_id IN ($need_group) OR " +
                     "credit_id IN ($need_group)) AND (group_name IS NULL OR group_name = '')"
        } elseif ($BelongToGroup) {
            $where = "group_name IS NOT NULL OR group_name <> ''"
        } else {
            $date = Convert-IIMitaMonth -Month $Month.Trim()

            if ($date -eq $null -or $date -eq "") {
                return
            }

            $where = "substr(date,1,7) = '$date'"
        }

        $command.CommandText = @"
SELECT id, date, debit_id, credit_id, amount, note, group_name FROM transactions
WHERE $where
ORDER BY date, id
"@

        $reader = $command.ExecuteReader()

        while ($reader.read()) {
            $debit = $global:IIMitaAccount.table[$reader["debit_id"].ToString()].name
            $credit = $global:IIMitaAccount.table[$reader["credit_id"].ToString()].name

            $obj = [PSCustomObject]@{
                id = $reader["id"].ToString()
                date = $reader["date"].ToString()
                debit_id = $reader["debit_id"].ToString()
                debit = $debit
                credit_id = $reader["credit_id"].ToString()
                credit = $credit
                amount = [int]$reader["amount"]
                note = $reader["note"].ToString()
                group = $reader["group_name"].ToString()
            }

            Write-Output $obj
        }

        $command.Dispose()
    }

    end {
        $con.Close()
    }
}

function Remove-IIMitaTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Transaction
    )

    begin {
        $con = [System.Data.SQLite.SQLiteConnection]::new($global:IIMitaDBCon)
        $con.Open()
        $command = $con.CreateCommand()
    }

    process {
        if ($_.id -eq $null -or $_.id -notmatch "^\d+$") {
            return
        }


        $command.CommandText = "DELETE FROM transactions WHERE id = $($_.id)"
        $command.ExecuteNonQuery() | Out-Null
    }

    end {
        $con.Close()
    }
}

function Edit-IIMitaTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Transaction
    )

    begin {
        $con = [System.Data.SQLite.SQLiteConnection]::new($global:IIMitaDBCon)
        $con.Open()
        $command = $con.CreateCommand()

        $cmd_arr = "d", "l", "r", "a", "n", "g"

        do {
            $cmd = Read-Host -Prompt "(d)ate, (l)eft, (r)ight, (a)mount, (n)ote, (g)roup"
            $cmd = $cmd.Trim()
        } while (-not $cmd_arr.Contains($cmd))

        switch ($cmd) {
            "q" {
                return
            }

            "d" {
                do {
                    $date = Read-IIMitaDate -Prompt "日付"
                } while ($date -eq $null)

                $set = "date = '$date'"
            }

            "l" {
                do {
                    $debit_id = Select-IIMitaAccount
                } while ($debit_id -eq $null)

                $set = "debit_id = '$debit_id'"
            }

            "r" {
                do {
                    $credit_id = Select-IIMitaAccount
                } while ($credit_id -eq $null)

                $set = "credit_id = '$credit_id'"
            }

            "a" {
                do {
                    $amount_str = Read-Host -Prompt "金額"
                    $amount_str = $amount_str.Trim()
                } while ($amount_str -notmatch "^\d+$")

                $set = "amount = $amount_str"
            }

            "n" {
                $note = Read-Host -Prompt "摘要"

                $set = "note = '$note'"
            }

            "g" {
                $group = Read-Host -Prompt "グループ名"

                $set = "group_name = '$group'"
            }
        }
    }

    process {
        if ($_.id -eq $null -or $_.id -notmatch "^\d+$") {
            return
        }

        $command.CommandText = "UPDATE transactions SET $set WHERE id = $($_.id)"
        $command.ExecuteNonQuery() | Out-Null
    }

    end {
        $con.Close()
    }
}

function Out-IIMitaUnbalancedGroup {
    $groups = @{}

    Get-IIMitaTransactions -BelongToGroup | ForEach-Object {
        if (-not $groups.ContainsKey($_.group)) {
            $groups[$_.group] = 0
        }

        $debit = $global:IIMitaAccount.table[$_.debit_id]
        $credit = $global:IIMitaAccount.table[$_.credit_id]

        if ($debit.need_group -ne $null) {
            $groups[$_.group] += $_.amount
        }

        if ($credit.need_group -ne $null) {
            $groups[$_.group] -= $_.amount
        }
    }

    $groups.GetEnumerator() | Where-Object { $_.value -ne 0 }
}
