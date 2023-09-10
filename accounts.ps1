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

    if ($Account.need_group -ne $null) {
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

Import-IIMitaAccounts

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
