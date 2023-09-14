BeforeAll {
    . $PSScriptRoot\..\config.ps1
    . $PSScriptRoot\..\accounts.ps1
}

Describe "Import-IIMitaAccounts" {
    BeforeAll {
        $accounts_file = [string]$global:IIMitaAccountsFile
        $global:IIMitaAccountsFile = "$PSScriptRoot\data\accounts.json"

        Import-IIMitaAccounts

        $ac = $global:IIMitaAccount
    }

    AfterAll {
        $global:IIMitaAccountsFile = $accounts_file
    }

    It "親が正しく設定されているか？" {
        $ac.table["111"].parent.id | Should -Be "110"
        $ac.table["111"].parent.parent.id | Should -Be "1"
    }

    It "深さが正しく設定されているか？" {
        $ac.table["1"].depth | Should -Be 1
        $ac.table["110"].depth | Should -Be 2
        $ac.table["111"].depth | Should -Be 3
    }

    It "typeが設定されていないとき、親から引き継がれているか？" {
        $ac.table["201"].type | Should -Be 2
    }

    It "need_groupが設定されている勘定科目がneed_groupリストに入っているか？" {
        $need_group = $global:IIMitaAccount.need_group | % { $_.id }

        $need_group | Should -Contain "141"
        $need_group | Should -Contain "201"
        $need_group | Should -Contain "202"
        $need_group.Length | Should -Be 3
    }
}
