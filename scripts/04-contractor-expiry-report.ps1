$contractorOU = "OU=Contractors,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"
$warningDays = 14

$contractors = Get-ADUser -Filter * -SearchBase $contractorOU `
    -Properties AccountExpirationDate, Description, Enabled, LastLogonDate

$expired = $contractors | Where-Object {
    $_.AccountExpirationDate -and $_.AccountExpirationDate -lt (Get-Date)
}

$expiringSoon = $contractors | Where-Object {
    $_.AccountExpirationDate -and
    $_.AccountExpirationDate -ge (Get-Date) -and
    $_.AccountExpirationDate -lt (Get-Date).AddDays($warningDays)
}

$noExpiry = $contractors | Where-Object { -not $_.AccountExpirationDate }

Write-Host "`n=== EXPIRED - review for offboarding ===" -ForegroundColor Red
$expired | Select-Object Name, SamAccountName, Description, AccountExpirationDate | Format-Table -AutoSize

Write-Host "`n=== EXPIRING WITHIN $warningDays DAYS ===" -ForegroundColor Yellow
$expiringSoon | Select-Object Name, SamAccountName, Description, AccountExpirationDate | Format-Table -AutoSize

Write-Host "`n=== NO EXPIRATION SET - policy exception ===" -ForegroundColor Magenta
$noExpiry | Select-Object Name, SamAccountName, Description | Format-Table -AutoSize
