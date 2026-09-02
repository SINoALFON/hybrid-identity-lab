$groups = "OU=Groups,OU=SINoALFON,DC=corp,DC=sinoalfon,DC=com"

# Department groups
"VFX","Finishing","Dailies","Infrastructure","Business" | ForEach-Object {
    New-ADGroup -Name "DEPT-$_" -GroupScope Global -GroupCategory Security -Path $groups -Description "All staff in $_"
}

# Role groups
New-ADGroup -Name "ROLE-VFX-Artist"     -GroupScope Global -GroupCategory Security -Path $groups -Description "VFX artists - comp and 3D tools"
New-ADGroup -Name "ROLE-VFX-Editor"     -GroupScope Global -GroupCategory Security -Path $groups -Description "VFX editorial"
New-ADGroup -Name "ROLE-Coordinator"    -GroupScope Global -GroupCategory Security -Path $groups -Description "Production coordinators"
New-ADGroup -Name "ROLE-IT-Admin"       -GroupScope Global -GroupCategory Security -Path $groups -Description "Infrastructure administrators"
New-ADGroup -Name "ROLE-Finishing-Editor"   -GroupScope Global -GroupCategory Security -Path $groups -Description "Online and conform editors"
New-ADGroup -Name "ROLE-Finishing-Colorist" -GroupScope Global -GroupCategory Security -Path $groups -Description "Colorists"
New-ADGroup -Name "ROLE-Finishing-Producer" -GroupScope Global -GroupCategory Security -Path $groups -Description "Finishing producers"

# Project groups
New-ADGroup -Name "PROJ-Titan"    -GroupScope Global -GroupCategory Security -Path $groups -Description "Access to Project Titan media"
New-ADGroup -Name "PROJ-Meridian" -GroupScope Global -GroupCategory Security -Path $groups -Description "Access to Project Meridian media"

# Nest role groups into department groups
Add-ADGroupMember -Identity "DEPT-VFX" -Members "ROLE-VFX-Artist","ROLE-VFX-Editor"
Add-ADGroupMember -Identity "DEPT-Finishing" -Members "ROLE-Finishing-Editor","ROLE-Finishing-Colorist","ROLE-Finishing-Producer"
