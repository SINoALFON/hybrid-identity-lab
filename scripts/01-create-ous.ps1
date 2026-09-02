$domain = "DC=corp,DC=sinoalfon,DC=com"

New-ADOrganizationalUnit -Name "SINoALFON" -Path $domain

$root = "OU=SINoALFON,$domain"

New-ADOrganizationalUnit -Name "Staff" -Path $root
New-ADOrganizationalUnit -Name "Contractors" -Path $root
New-ADOrganizationalUnit -Name "ServiceAccounts" -Path $root
New-ADOrganizationalUnit -Name "Computers" -Path $root
New-ADOrganizationalUnit -Name "Groups" -Path $root

$staff = "OU=Staff,$root"

New-ADOrganizationalUnit -Name "VFX" -Path $staff
New-ADOrganizationalUnit -Name "Finishing" -Path $staff
New-ADOrganizationalUnit -Name "Dailies" -Path $staff
New-ADOrganizationalUnit -Name "Infrastructure" -Path $staff
New-ADOrganizationalUnit -Name "Business" -Path $staff

$business = "OU=Business,$staff"

New-ADOrganizationalUnit -Name "HR" -Path $business
New-ADOrganizationalUnit -Name "Finance" -Path $business
New-ADOrganizationalUnit -Name "Admin" -Path $business
