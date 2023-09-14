Import-Module "$PSScriptRoot\lib\System.Data.SQLite.dll"

$psfiles = @("config.ps1", "accounts.ps1", "transactions.ps1", "bspl.ps1")

$psfiles = $psfiles.foreach({ "$PSScriptRoot\$_" })
$files = @(Get-ChildItem -Path $psfiles -ErrorAction SilentlyContinue)

foreach ($import in $files) {
    try {
        . $import.fullname
    } catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
