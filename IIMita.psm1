Import-Module "$PSScriptRoot\lib\System.Data.SQLite.dll"

[string]$global:IIMitaData = "$HOME\.mita"
[string]$global:IIMitaAccountsFile = "$IIMitaData\accounts.json"
$global:IIMitaAccount = $null
[string]$global:IIMitaDBFile = "$IIMitaData\transactions.sqlite3"
[string]$global:IIMitaDBCon = "Data Source=$IIMitaDBFile"

$psfiles = @("accounts.ps1", "transactions.ps1", "bspl.ps1")

$psfiles = $psfiles.foreach({ "$PSScriptRoot\$_" })
$files = @(Get-ChildItem -Path $psfiles -ErrorAction SilentlyContinue)

foreach ($import in $files) {
    try {
        . $import.fullname
    } catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
