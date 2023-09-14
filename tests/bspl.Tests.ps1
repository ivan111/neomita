BeforeAll {
    Import-Module "$PSScriptRoot\..\lib\System.Data.SQLite.dll"

    . $PSScriptRoot\..\config.ps1
    . $PSScriptRoot\..\accounts.ps1
    . $PSScriptRoot\..\transactions.ps1
    . $PSScriptRoot\..\bspl.ps1

    $accounts_file = [string]$global:IIMitaAccountsFile
    $global:IIMitaAccountsFile = "$PSScriptRoot\data\accounts.json"

    Import-IIMitaAccounts

    $db_con = $global:IIMitaDBCon
    $db_file = "$PSScriptRoot\data\test_transactions.sqlite3"
    $global:IIMitaDBCon = "Data Source=$db_file"

    function Delete-AllTransactions {
        $con = [System.Data.SQLite.SQLiteConnection]::new($global:IIMitaDBCon)
        $con.Open()
        $command = $con.CreateCommand()

        $command.CommandText = "DELETE FROM transactions"
        $command.ExecuteNonQuery() | Out-Null

        $con.Close()
    }
}


AfterAll {
    $global:IIMitaAccountsFile = $accounts_file
    $global:IIMitaDBCon = $db_con
}


Describe "Out-IIMitaBS" {
    BeforeEach {
        Delete-AllTransactions
    }

    It "B/Sが正しく計算されるか？" {
        $tr = @{
            date = "2023-09-01"
            debit_id = "101"  # 現金
            credit_id = "301"  # 給与
            amount = 10000
            note = ""
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-02"
            debit_id = "101"  # 現金
            credit_id = "301"  # 給与
            amount = 8000
            note = ""
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-03"
            debit_id = "301"  # 給与
            credit_id = "101"  # 現金
            amount = 1000
            note = "給料払い過ぎた"
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-04"
            debit_id = "401"  # 家賃
            credit_id = "101"  # 現金
            amount = 2000
            note = ""
        }

        Save-IIMitaTransaction $tr

        Out-IIMitaBS | Out-Null

        $tbl = $global:IIMitaAccount.table

        $bank = $tbl["110"]
        $bank.debit_amount | Should -Be 0
        $bank.credit_amount | Should -Be 0

        $cash = $tbl["101"]
        ($cash.debit_amount - $cash.credit_amount) | Should -Be 15000

        $assets = $tbl["1"]
        ($assets.debit_amount - $assets.credit_amount) | Should -Be 15000
    }
}


Describe "Out-IIMitaPL" {
    BeforeEach {
        Delete-AllTransactions
    }

    It "P/Lが正しく計算されるか？" {
        $tr = @{
            date = "2023-09-01"
            debit_id = "101"  # 現金
            credit_id = "301"  # 給与
            amount = 10000
            note = ""
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-02"
            debit_id = "101"  # 現金
            credit_id = "301"  # 給与
            amount = 8000
            note = ""
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-03"
            debit_id = "301"  # 給与
            credit_id = "101"  # 現金
            amount = 1000
            note = "給料払い過ぎた"
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-04"
            debit_id = "401"  # 家賃
            credit_id = "101"  # 現金
            amount = 30000
            note = ""
        }

        Save-IIMitaTransaction $tr

        Out-IIMitaPL -Month "2023-09" | Out-Null

        $tbl = $global:IIMitaAccount.table

        $sonota = $tbl["302"]
        $sonota.debit_amount | Should -Be 0
        $sonota.credit_amount | Should -Be 0

        $kyuyo = $tbl["301"]
        ($kyuyo.credit_amount - $kyuyo.debit_amount) | Should -Be 17000

        $income = $tbl["3"]
        ($income.credit_amount - $income.debit_amount) | Should -Be 17000

        $yatin = $tbl["401"]
        ($yatin.credit_amount - $yatin.debit_amount) | Should -Be -30000

        $expense = $tbl["4"]
        ($expense.credit_amount - $expense.debit_amount) | Should -Be -30000
    }
}
