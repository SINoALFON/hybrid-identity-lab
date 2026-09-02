$base = "OU=Staff,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"
$pw = ConvertTo-SecureString "LabP@ssw0rd123!" -AsPlainText -Force

Import-Csv C:\Lab\new-staff.csv | ForEach-Object {
    $ouPath = "OU=" + ($_.OU -replace '\\', ',OU=') + ",$base"
    
    New-ADUser -Name "$($_.FirstName) $($_.LastName)" `
        -GivenName $_.FirstName -Surname $_.LastName `
        -SamAccountName $_.SamAccountName `
        -UserPrincipalName "$($_.SamAccountName)@corp.sinoalfon.com" `
        -Path $ouPath `
        -Title $_.Title `
        -Department $_.Department `
        -AccountPassword $pw `
        -ChangePasswordAtLogon $true `
        -Enabled $true

    Add-ADGroupMember -Identity $_.Role -Members $_.SamAccountName
    
    Write-Host "Created $($_.SamAccountName) in $ouPath"
}
