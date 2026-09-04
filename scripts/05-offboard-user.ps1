param([Parameter(Mandatory)][string]$SamAccountName)

$disabledOU = "OU=Disabled,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"
$logPath = "C:\Lab\offboard-log"

if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force | Out-Null }

try {
    $user = Get-ADUser -Identity $SamAccountName -Properties MemberOf, Description -ErrorAction Stop

    # Capture memberships before removing them
    $groups = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }
    $record = [PSCustomObject]@{
        SamAccountName = $user.SamAccountName
        Name           = $user.Name
        OffboardedOn   = (Get-Date).ToString("yyyy-MM-dd")
        Groups         = ($groups -join "; ")
        OriginalDN     = $user.DistinguishedName
    }
    $record | Export-Csv "$logPath\$SamAccountName-offboard.csv" -NoTypeInformation

    # Revoke
    foreach ($g in $user.MemberOf) {
        Remove-ADGroupMember -Identity $g -Members $user.DistinguishedName -Confirm:$false
    }

    Disable-ADAccount -Identity $user.DistinguishedName
    Set-ADUser -Identity $user.DistinguishedName -Description "Offboarded $((Get-Date).ToString('yyyy-MM-dd')) - retained for rehire"
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU

    Write-Host "Offboarded $SamAccountName. Removed from: $($groups -join ', ')" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
