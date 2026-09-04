param(
    [Parameter(Mandatory)][string]$SamAccountName,
    [Parameter(Mandatory)][string]$NewDepartment,
    [string]$NewRoleGroup,
    [string]$NewTitle
)

$staffBase = "OU=Staff,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"
$logPath = "C:\Lab\move-log"
if (-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType Directory -Force | Out-Null }

try {
    $user = Get-ADUser -Identity $SamAccountName -Properties MemberOf, Department -ErrorAction Stop
    $currentGroups = $user.MemberOf | ForEach-Object { Get-ADGroup $_ }

    $toRemove = $currentGroups | Where-Object { $_.Name -like "DEPT-*" -or $_.Name -like "ROLE-*" }
    $projects = $currentGroups | Where-Object { $_.Name -like "PROJ-*" }

    # Record before changing
    [PSCustomObject]@{
        SamAccountName   = $user.SamAccountName
        MovedOn          = (Get-Date).ToString("yyyy-MM-dd")
        FromDepartment   = $user.Department
        ToDepartment     = $NewDepartment
        GroupsRemoved    = ($toRemove.Name -join "; ")
        ProjectsRetained = ($projects.Name -join "; ")
    } | Export-Csv "$logPath\$SamAccountName-move.csv" -NoTypeInformation

    foreach ($g in $toRemove) {
        Remove-ADGroupMember -Identity $g -Members $user.DistinguishedName -Confirm:$false
    }

    if ($NewRoleGroup) {
        Add-ADGroupMember -Identity $NewRoleGroup -Members $user.SamAccountName
    } else {
        Add-ADGroupMember -Identity "DEPT-$NewDepartment" -Members $user.SamAccountName
    }

    Set-ADUser -Identity $user.DistinguishedName -Department $NewDepartment
    if ($NewTitle) { Set-ADUser -Identity $user.DistinguishedName -Title $NewTitle }

    Move-ADObject -Identity $user.DistinguishedName -TargetPath "OU=$NewDepartment,$staffBase"

    Write-Host "Moved $SamAccountName to $NewDepartment" -ForegroundColor Green
    Write-Host "Removed: $($toRemove.Name -join ', ')" -ForegroundColor Yellow
    if ($projects) {
        Write-Host "REVIEW - project access retained: $($projects.Name -join ', ')" -ForegroundColor Magenta
    }
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
