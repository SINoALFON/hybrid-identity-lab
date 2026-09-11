# Hybrid Identity Environment

## Overview
This lab simulates a post-production media company, using Active Directory administration, identity lifecycle management, and synchronization to Microsoft Entra ID. The goal is a system where assets and tools can be coordinated seamlessly among a team of staff, freelancers, and vendors, within tightly scoped access boundaries.

## Scenario
SINoALFON Media (S-Media for short) is a post-production facility that handles a breadth of assets for streaming and production companies. In order to process the amount of incoming work, S-Media employs in-house staff as well as contracting out overflow to individual freelancers and vendors, who may work on anywhere from a single project to several. As most of the assets S-Media handles are sensitive, unreleased client content, they need a system through which they can coordinate access while simultaneously reinforcing content security. This system also needs to be highly fluid, able to handle onboarding and deprovisioning of workers quickly while keeping project material access scoped to what is needed.

## Architecture
- Hyper-V on Windows 11, internal virtual switch
- Network: 10.10.10.0/24
- DC01 — Windows Server 2025, 10.10.10.10, domain controller and DNS
- Domain: corp.sinoalfon.com (NetBIOS: SINOALFON)

## Build log
### Session 1: Domain controller
- Hyper-V VM (DC01), Server 2025 Standard eval, Gen 2, 4GB RAM, 2 vCPU
- Internal virtual switch, 10.10.10.0/24, host at .1 and DC at .10
- Static IP set before promotion; DNS pointed at loopback
- Promoted to new forest: corp.sinoalfon.com (NetBIOS SINOALFON)

### Session 2: OU structure and groups
- OUs follow departments, not job titles — titles churn and Group Policy
  links to OUs, so a stable structure matters more than a descriptive one
- Departments: VFX, Finishing, Dailies, Infrastructure, Business
  (HR/Finance/Admin nested under Business)
- Groups use prefixes: DEPT- for departments, ROLE- for job function,
  PROJ- for project access
- Role groups nested into department groups so role membership grants
  department access transitively
- Role layer only added where a department has internally different
  access needs — Dailies and Business use department groups directly

### Session 3: Staff provisioning
- Two accounts created manually first to work through the parameters,
  then converted to a CSV-driven script for the remaining eight
- Department and Title populated as real AD attributes to support
  later automation and dynamic groups

### Session 4: Contractors and lifecycle
- Contractors kept in a separate OU with no department group membership —
  project access only, via PROJ- groups
- Accounts provisioned with -AccountExpirationDate so deprovisioning
  happens without anyone remembering to act
- Chose disable-and-retain over delete for rehires, paired with automated
  reporting so retained accounts don't become orphans
- Reporting script covers three states: expired, expiring soon, and
  no expiration set (policy exception)
- Verified the policy-exception detection by deliberately creating a
  non-compliant account

### Session 5: Joiner/Mover/Leaver

**Offboarding (leaver)**
- Sequence: capture group memberships to CSV, strip all groups, disable
  account, stamp description with offboarding date, move to Disabled OU
- Capturing memberships before removal matters for two reasons: rehires
  are common in post, and audit requires being able to show what someone
  had and when it was revoked
- Domain Users is untouched because it's the primary group and isn't
  returned by MemberOf — removing a primary group breaks the account
- Known gap at the time: this handled AD only. Disabling the on-prem
  account does not immediately revoke active cloud sessions or refresh
  tokens. Resolved in Session 8

**Transfers (mover)**
- Design decision: DEPT- and ROLE- groups are removed automatically, but
  PROJ- groups are retained and flagged for review rather than stripped
- Reasoning: departmental access reflects day-to-day function and should
  follow the transfer immediately. Project access may still be needed for
  handover on an active show, and silently revoking it mid-production is
  how "temporary" exceptions get created and never cleaned up. Surfacing
  it forces a decision instead of hiding one
- Nesting paid off here — removing one role group also removed the
  inherited department access, so a transfer is a single membership change
  rather than hunting down individual grants

**Verification**
- Both script branches tested against the conditions they handle: the
  transfer path with and without retained project access, and the
  contractor report's policy-exception detection against a deliberately
  non-compliant account

### Session 6: Entra Connect and hybrid sync

**Prep**
- Added `SINoALFON.onmicrosoft.com` as an alternative UPN suffix in AD and
  reassigned all users to it. Without this, synced users would fall back to
  the tenant's onmicrosoft.com address anyway, but the on-prem and cloud
  identifiers would not match — which breaks the single-identity assumption
  hybrid identity exists to provide
- Added a second network adapter on an External switch so the DC could
  reach Microsoft endpoints. Kept the internal adapter on 10.10.10.10 for
  domain traffic so lab DNS and domain services stay isolated
- Chose the second-adapter approach over host connection sharing because
  ICS forces the shared adapter to 192.168.137.1, which would have
  renumbered the lab network

**Configuration decisions**
- Customize rather than Express, so the sync could be scoped by OU. Express
  syncs the entire directory including built-in accounts
- Password Hash Synchronization for sign-in. Entra authenticates
  independently, so cloud access survives an on-prem outage. What syncs is
  a re-hash of the NTLM hash with a per-user salt, so the stored value
  can't be replayed against on-prem
- Source anchor left to Entra, which uses mS-DS-ConsistencyGuid. This
  replaced objectGUID because objectGUID is unique per forest and breaks
  the on-prem-to-cloud link during cross-forest migration
- OU filtering scoped to the SINoALFON OU only. Builtin, Users, and
  Computers excluded — the default Users container holds Administrator,
  Guest, and krbtgt, none of which belong in the cloud directory
- Disabled OU deliberately left in scope so offboarded accounts sync as
  disabled rather than being absent. Excluding disabled accounts is a
  common mistake that leaves stale enabled accounts in the cloud after
  on-prem offboarding

**Verified**
- All 13 accounts synced with correct UPNs
- On-premises sync enabled shows Yes, distinguishing synced accounts from
  the cloud-only admin
- Offboarded contractor present and disabled
- Group nesting preserved — ROLE- groups remain members of DEPT- groups
  in Entra

**Known limitations**
- Password writeback requires Entra ID P1, so self-service password reset
  is unavailable for synced users on the free tier

### Session 7: Sync verification and joiner test

**Live sync confirmed**
- Changed a user's title on-prem, forced a delta sync with
  Start-ADSyncSyncCycle, and confirmed the change appeared in Entra.
  Delta processes only changes since the last cycle; a full sync
  reprocesses everything and is needed after changing filtering rules

**Joiner tested end to end**
- Added a row to the staffing CSV and reran the provisioning script.
  New account created on-prem, synced to Entra with correct UPN,
  department, title, and group membership intact
- Rerunning the script against existing users produced eight expected
  failures handled by the try/catch, and completed rather than halting.
  Reruns are safe — worth confirming, since provisioning jobs get
  triggered accidentally

**Tenant cleanup**
- Removed cloud-only users and groups left over from earlier Microsoft
  Learn exercises so the tenant reflects only the synced directory.
  Synced objects can't be deleted in Entra — AD is authoritative, and
  deletion has to happen on-prem or via sync scope

### Session 8: Cloud session revocation

**Closing the offboarding gap**
- Disabling an account on-prem does not invalidate tokens already issued
  by Entra. Access tokens remain valid until expiry, and refresh tokens
  far longer, so a user offboarded during an active session keeps working
  until the token is refused. For a freelancer being walked out on the last
  day of a show, with unreleased content on screen, that window matters
- Revoke-MgUserSignInSession invalidates refresh tokens and forces
  reauthentication everywhere. Since the account is disabled, that
  reauthentication then fails
- Added to the offboarding script ahead of the AD teardown, so there is no
  interval where the cloud account is still live after revocation has begun
- Wrapped in its own try/catch. If Graph is unreachable the AD teardown has
  already succeeded and should not be rolled back — failing loudly on the
  revocation while preserving the rest is the right behaviour

**Known simplifications**
- Connect-MgGraph authenticates interactively on every run. Production
  automation would use certificate-based app authentication instead
- Graph requires PowerShell 7 while the AD module targets 5.1. Consolidated
  on pwsh, which loads the AD module through its compatibility layer.
  Objects returned that way are deserialized — properties survive, methods
  do not

### Session 9: Group Policy and domain-joined client

**Group Policy design**
- Created a GPO linked to the Contractors OU for session security, then
  realized the setting chosen (Interactive logon: Machine inactivity limit)
  is under Computer Configuration while the OU contains only user objects.
  Computer settings do not apply to user OUs, so the policy would never
  have taken effect
- This led to loopback processing, which is the correct mechanism for the
  actual requirement: session policy should follow the workstation, not the
  person. A contractor at a shared edit bay should get stricter settings
  because of where they are sitting, and so should a staff editor at the
  same machine
- Loopback needs computer objects to link against, which the lab did not
  have — prompting the client VM build

**Client workstation (WS01)**
- Windows 11 Pro, Gen 2 VM with virtual TPM enabled (Windows 11 refuses to
  install without it), 4GB, internal switch only — no internet needed
- Static IP 10.10.10.20, DNS pointed at the DC before joining. Domain join
  fails without name resolution against the domain controller
- Joined with Add-Computer, signed in as a synced domain user

**Verification**
- whoami /groups on a real login shows both ROLE-VFX-Artist and DEPT-VFX in
  the security token. The department membership was never assigned directly
  — it resolves through group nesting at authentication time
- This is the definitive check for effective access. Directory queries
  report what is configured; the token reports what actually governs
  authorization

### Session 10: Loopback processing verified

**Computer OU structure**
- Created Computers → Workstations → SharedBays. The depth is driven by
  policy boundaries rather than tidiness: Workstations separates end-user
  machines from servers, SharedBays separates machines anyone might sit at
  from assigned desks, which is the distinction that justifies stricter
  session policy
- WS01 had joined into the default Computers container. Domain join always
  lands machines there unless the default is redirected with redircmp

**The GPO**
- Single GPO linked to SharedBays doing two different jobs:
  - Computer Configuration enables loopback processing in Merge mode
  - User Configuration carries the screen saver settings (enable, 600s
    timeout, password protect)
- Without loopback, the User Configuration half would be ignored, because
  the linked OU contains computer objects rather than users
- Merge over Replace: Merge applies the user's own policy first and layers
  the machine-based settings on top, with the machine winning conflicts.
  A VFX artist keeps their departmental settings and picks up the stricter
  session policy from the shared bay. Replace discards the user's policy
  entirely, which suits kiosks but not workstations

**Verification**
- Signed in as a user whose account lives in Staff → VFX, on a machine in
  SharedBays. gpresult /r /scope:user lists SharedBay - Session Security
  under Applied Group Policy Objects — the policy reached a user from an
  entirely different branch of the tree, which is loopback working
- Confirmed end to end by checking the registry values the policy writes
  under HKCU:\Software\Policies\Microsoft\Windows\Control Panel\Desktop.
  ScreenSaveActive 1, ScreenSaveTimeOut 600, ScreenSaverIsSecure 1
- User-side settings apply at logon, so a sign-out is needed after
  gpupdate /force before they take effect
  
## Problems and solutions
**Transitive group membership is not visible through the obvious cmdlets.**
Get-ADGroupMember and Get-ADPrincipalGroupMembership return direct
membership only, so a user inheriting access through a nested group appears
not to have it. The recursive LDAP matching rule
(1.2.840.113556.1.4.1941) enumerates effective membership correctly.
Confirmed later against a real login — whoami /groups shows the inherited
group in the security token, which is the ground truth for authorization.

**Provisioning script carried the old UPN suffix after the reassignment.**
The alternative UPN suffix was added and existing users were reassigned to
`SINoALFON.onmicrosoft.com`, but the provisioning script still hardcoded
`corp.sinoalfon.com`. A newly created user therefore synced with an on-prem
UPN that did not match the cloud value — Entra rewrote it to the verified
domain on sync, so the account looked correct in the portal while the
on-prem attribute was wrong.

The failure is silent, which is what makes it worth noting: nothing errors,
and the cloud object appears fine. It would surface later in scenarios that
depend on the identifier matching across both directories, such as Seamless
SSO or correlating cloud sign-in logs to on-prem accounts. Every subsequent
hire created by the script would have drifted the same way.

Fixed both the affected account and the script. The lesson is that a
one-time remediation against existing objects is incomplete if the process
that creates new ones still produces the old state.

**Nested OU paths reverse in distinguished names.**
The provisioning script built `OU=Business,OU=Finance,...` from a CSV
column written `Business\Finance`. DNs read innermost-first, so the path
was inverted and creation failed. Fixed by reversing the segments before
joining.

**Non-terminating errors hid the failure.**
The same script printed a success message for the account that failed,
because AD cmdlet errors are non-terminating by default and the loop
continued. Added -ErrorAction Stop with try/catch.

**`$_` rebinds inside catch blocks.**
The provisioning script's error handler referenced `$_.SamAccountName`,
but within a catch block `$_` is the error record rather than the pipeline
object, so failures logged as "FAILED :" with no username. Fixed by
assigning the pipeline object to a named variable at the top of the loop.

**Restarting the Connect wizard orphans the sync service account.**
The first run created an MSOL_ service account with a generated password.
Restarting the wizard prompted for directory credentials again, and the
existing account's password was unknown. Removed the orphaned account and
let the wizard create a fresh one.

**Sign-in configuration reported the tenant domain as "Not Added."**
Both UPN suffixes showed as not matching a verified Entra domain, despite
`SINoALFON.onmicrosoft.com` being verified and primary in the tenant, and
despite `Get-ADForest` confirming the suffix was registered. Restarting the
wizard did not clear it. Proceeded using the "Continue without matching all
UPN suffixes to verified domains" checkbox; the sync produced correct UPNs,
confirming the warning was cosmetic.

**Newer Connect Sync versions refuse privileged accounts for the AD
connector.** Attempting to use a domain admin account is blocked outright —
the installer requires either a purpose-created service account or one with
delegated permissions. This is a security improvement over older releases
where domain admin was commonly used.

**Modules installed to a path PowerShell does not search.**
Install-Module with -Scope CurrentUser reported success, but
Get-Module -ListAvailable found nothing. The server's PSModulePath had no
CurrentUser entry, so the module landed somewhere PowerShell never looks.
No error, no module. Installing with -Scope AllUsers targeted a path that
was on the search list and resolved it. PSModulePath is the first thing to
check when a module installs but cannot be found.

**Microsoft Graph does not load on Windows PowerShell 5.1.**
Importing Microsoft.Graph.Authentication threw a TypeLoadException —
a method in the module's assembly had no implementation, meaning it was
built against a newer .NET runtime than 5.1 provides. Documentation in
places still suggests 5.1 is supported; it is not for current versions.
Installed PowerShell 7, which runs on .NET Core and sits alongside 5.1
rather than replacing it.

**Computer settings do not apply to user OUs.**
A GPO linked to an OU containing users cannot deliver Computer
Configuration settings. Diagnosed conceptually before deployment; would
have surfaced as a policy showing "not applied" in Group Policy Results.
The fix is either a user-scoped equivalent setting or loopback processing
against an OU of computers.

**Multi-homed domain controller registers both interfaces in DNS.**
After adding the external adapter for Entra Connect, the DC registered both
10.10.10.10 and its DHCP address from the home network. Clients resolving
the domain receive both, and may attempt the unreachable one. Retries mask
it, but the correct fix is disabling DNS registration on the external
adapter and clearing the stale record. This is why multi-homed DCs are
discouraged.

**Hyper-V enhanced session mode blocks standard domain users.**
Enhanced session connects over RDP, which requires membership in Remote
Desktop Users. Ordinary domain users are denied. Adding a department group
to the domain-level Remote Desktop Users group does not help — that group
governs domain controller access, not member workstations. The correct
scoping is domain group nested into the workstation's local group.
Worked around by disabling enhanced session, and the department-wide RDP
grant was reverted rather than left in place.

**Windows 11 out-of-box experience forces a Microsoft account.**
With no internet available, setup stalls rather than offering a local
account. Shift+F10 to a command prompt and OOBE\BYPASSNRO returns setup to
a state where "I don't have internet" is offered.

**Hyper-V VM name and Windows hostname are unrelated.**
The VM was labelled WS01 in Hyper-V, but Windows generated its own
hostname during setup and joined the domain under that. Get-ADComputer
found no object called WS01. Renamed the machine with Rename-Computer,
which requires domain credentials on a joined machine because it updates
the computer object in AD.
