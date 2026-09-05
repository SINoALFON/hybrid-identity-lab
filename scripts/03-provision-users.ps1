$base = "OU=Staff,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"
$pw = Read-Host -AsSecureString "Enter initial password for new accounts"

Import-Csv C:\Lab\new-staff.csv | ForEach-Object {
    $row = $_
    try {
        $segments = $row.OU -split '\\'
        [array]::Reverse($segments)
        $ouPath = "OU=" + ($segments -join ',OU=') + ",$base"

        New-ADUser -Name "$($row.FirstName) $($row.LastName)" `
            -GivenName $row.FirstName -Surname $row.Surname `
            -SamAccountName $row.SamAccountName `
            -UserPrincipalName "$($row.SamAccountName)@SINoALFON.onmicrosoft.com" `
            -Path $ouPath `
            -Title $row.Title `
            -Department $row.Department `
            -AccountPassword $pw `
            -ChangePasswordAtLogon $true `
            -Enabled $true `
            -ErrorAction Stop

        Add-ADGroupMember -Identity $row.Role -Members $row.SamAccountName -ErrorAction Stop
        Write-Host "Created $($row.SamAccountName) in $ouPath" -ForegroundColor Green
    }
    catch {
        Write-Host "FAILED $($row.SamAccountName): $($_.Exception.Message)" -ForegroundColor Red
    }
}
