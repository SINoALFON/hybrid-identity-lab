$base = "OU=Staff,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"
$pw = Read-Host -AsSecureString "Enter initial password for new accounts"

Import-Csv C:\Lab\new-staff.csv | ForEach-Object {
    try {
        $segments = $_.OU -split '\\'
        [array]::Reverse($segments)
        $ouPath = "OU=" + ($segments -join ',OU=') + ",$base"

        New-ADUser -Name "$($_.FirstName) $($_.LastName)" `
            -GivenName $_.FirstName -Surname $_.LastName `
            -SamAccountName $_.SamAccountName `
            -UserPrincipalName "$($_.SamAccountName)@corp.sinoalfon.com" `
            -Path $ouPath `
            -Title $_.Title `
            -Department $_.Department `
            -AccountPassword $pw `
            -ChangePasswordAtLogon $true `
            -Enabled $true `
            -ErrorAction Stop

        Add-ADGroupMember -Identity $_.Role -Members $_.SamAccountName -ErrorAction Stop

        Write-Host "Created $($_.SamAccountName) in $ouPath" -ForegroundColor Green
    }
    catch {
        Write-Host "FAILED $($_.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
