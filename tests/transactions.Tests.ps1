BeforeAll {
    Import-Module "$PSScriptRoot\..\lib\System.Data.SQLite.dll"

    . $PSScriptRoot\..\config.ps1
    . $PSScriptRoot\..\accounts.ps1
    . $PSScriptRoot\..\transactions.ps1

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


Describe "Save-IIMitaTransaction" {
    BeforeEach {
        Delete-AllTransactions
    }

    It "取引がデータベースに保存されているか？" {
        $tr = @{
            date = "2023-09-14"
            debit_id = "401"
            credit_id = "101"
            amount = 1000
            note = "家賃支払い"
        }

        Save-IIMitaTransaction $tr

        $res = Get-IIMitaTransactions -Month "2023-09"

        $res.date | Should -Be "2023-09-14"
        $res.debit_id | Should -Be "401"
        $res.credit_id | Should -Be "101"
        $res.amount | Should -Be 1000
        $res.note | Should -Be "家賃支払い"
        $res.group | Should -BeNullOrEmpty
    }
}


Describe "Get-IIMitaTransactions" {
    BeforeEach {
        Delete-AllTransactions
    }

    It "指定した月だけ取得できるか？" {
        $tr = @{
            date = "2023-08-11"
            debit_id = "401"
            credit_id = "101"
            amount = 2000
            note = "test"
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-14"
            debit_id = "401"
            credit_id = "101"
            amount = 1000
            note = "家賃支払い"
        }

        Save-IIMitaTransaction $tr

        $res = Get-IIMitaTransactions -Month "2023-08"

        $res.date | Should -Be "2023-08-11"
    }

    It "Allスイッチ" {
        $tr = @{
            date = "2023-08-11"
            debit_id = "401"
            credit_id = "101"
            amount = 2000
            note = "test"
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-14"
            debit_id = "401"
            credit_id = "101"
            amount = 1000
            note = "家賃支払い"
        }

        Save-IIMitaTransaction $tr

        $res = Get-IIMitaTransactions -All

        $res.Length | Should -Be 2
        $res[0].date | Should -Be "2023-08-11"
        $res[1].date | Should -Be "2023-09-14"
    }

    It "NeedGroupスイッチ" {
        $tr = @{
            date = "2023-08-11"
            debit_id = "401"
            credit_id = "101"
            amount = 2000
            note = "test"
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-10"
            debit_id = "141"
            credit_id = "301"
            amount = 3000
            note = "給料"
        }

        Save-IIMitaTransaction $tr

        $res = Get-IIMitaTransactions -NeedGroup

        $res.date | Should -Be "2023-09-10"
    }

    It "BelongToGroupスイッチ" {
        $tr = @{
            date = "2023-08-11"
            debit_id = "401"
            credit_id = "101"
            amount = 2000
            note = "test"
        }

        Save-IIMitaTransaction $tr

        $tr = @{
            date = "2023-09-10"
            debit_id = "141"
            credit_id = "301"
            amount = 3000
            note = "給料"
        }

        $id = Save-IIMitaTransaction $tr

        Edit-IIMitaTransaction -Id $id -Group "2023-09_給与"

        $res = Get-IIMitaTransactions -BelongToGroup

        $res.date | Should -Be "2023-09-10"
    }
}


Describe "Edit-IIMitaTransaction" {
    BeforeEach {
        Delete-AllTransactions
    }

    It "変更できているか？" {
        $tr = @{
            date = "2023-08-11"
            debit_id = "401"
            credit_id = "101"
            amount = 2000
            note = ""
        }

        $id = Save-IIMitaTransaction $tr

        Edit-IIMitaTransaction -Id $id -Date "2023-09-08" -DebitId "141" -CreditId "301" -Amount 100 -Note "test" -Group "2023-09_給与"

        $res = Get-IIMitaTransactions -All

        $res.date | Should -Be "2023-09-08"
        $res.debit_id | Should -Be "141"
        $res.credit_id | Should -Be "301"
        $res.amount | Should -Be 100
        $res.note | Should -Be "test"
        $res.group | Should -Be "2023-09_給与"
    }
}


Describe "Out-IIMitaUnbalancedGroup" {
    BeforeEach {
        Delete-AllTransactions
    }

    It "借方と貸方の合計が釣り合っているときは表示しない。" {
        # id: 141 はneed_group
        $tr = @{
            date = "2023-08-31"
            debit_id = "141"
            credit_id = "301"
            amount = 10000
            note = ""
        }

        $id = Save-IIMitaTransaction $tr
        Edit-IIMitaTransaction -id $id -group "2023-08_給与"

        $tr = @{
            date = "2023-08-31"
            debit_id = "423"
            credit_id = "141"
            amount = 500
            note = ""
        }

        $id = Save-IIMitaTransaction $tr
        Edit-IIMitaTransaction -id $id -group "2023-08_給与"

        $tr = @{
            date = "2023-09-14"
            debit_id = "101"
            credit_id = "141"
            amount = 9500
            note = ""
        }

        $id = Save-IIMitaTransaction $tr
        Edit-IIMitaTransaction -id $id -group "2023-08_給与"

        $res = Out-IIMitaUnbalancedGroup

        $res | Should -Be $null
    }

    It "借方と貸方の合計が釣り合っていないときは表示する。" {
        # id: 141 はneed_group
        $tr = @{
            date = "2023-08-31"
            debit_id = "141"
            credit_id = "301"
            amount = 10000
            note = ""
        }

        $id = Save-IIMitaTransaction $tr
        Edit-IIMitaTransaction -id $id -group "2023-08_給与"

        $tr = @{
            date = "2023-08-31"
            debit_id = "423"
            credit_id = "141"
            amount = 500
            note = ""
        }

        $id = Save-IIMitaTransaction $tr
        Edit-IIMitaTransaction -id $id -group "2023-08_給与"

        $res = Out-IIMitaUnbalancedGroup
        Write-Host $res

        $res.Length | Should -Be 1
        $res.name | Should -Be "2023-08_給与"
        $res.value | Should -Be 9500
    }
}
