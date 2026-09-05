# Build Log

## Session 1 — Domain controller
- Hyper-V VM (DC01), Server 2025 Standard eval, Gen 2, 4GB RAM, 2 vCPU
- Internal virtual switch, 10.10.10.0/24, host at .1 and DC at .10
- Static IP set before promotion; DNS pointed at loopback
- Promoted to new forest: corp.sinoalfon.com (NetBIOS SINOALFON)

## Session 2 — OU structure and groups
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

## Session 3 — Staff provisioning
- Two accounts created manually first to work through the parameters,
  then converted to a CSV-driven script for the remaining eight
- Department and Title populated as real AD attributes to support
  later automation and dynamic groups

## Session 4 — Contractors and lifecycle
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

## Session 5 — Joiner/Mover/Leaver

**Offboarding (leaver)**
- Sequence: capture group memberships to CSV, strip all groups, disable
  account, stamp description with offboarding date, move to Disabled OU
- Capturing memberships before removal matters for two reasons: rehires
  are common in post, and audit requires being able to show what someone
  had and when it was revoked
- Domain Users is untouched because it's the primary group and isn't
  returned by MemberOf — removing a primary group breaks the account
- Known gap: this handles AD only. Once synced to Entra, offboarding will
  also need to revoke cloud sessions and tokens, since disabling the
  on-prem account doesn't immediately kill an active session

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

## Session 6 — Entra Connect and hybrid sync

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

## Session 7 — Sync verification and joiner test

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
- Offboarding currently handles AD only. Disabling the on-prem account does
  not immediately revoke active cloud sessions or refresh tokens

## Problems encountered

**Nested OU paths reverse in distinguished names.**
The provisioning script built `OU=Business,OU=Finance,...` from a CSV
column written `Business\Finance`. DNs read innermost-first, so the path
was inverted and creation failed. Fixed by reversing the segments before
joining.

**Non-terminating errors hid the failure.**
The same script printed a success message for the account that failed,
because AD cmdlet errors are non-terminating by default and the loop
continued. Added -ErrorAction Stop with try/catch.

**Transitive group membership is not visible through the obvious cmdlets.**
Get-ADGroupMember and Get-ADPrincipalGroupMembership return direct
membership only, so a user inheriting access through a nested group
appears not to have it. The recursive LDAP matching rule
(1.2.840.113556.1.4.1941) enumerates effective membership correctly.

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

**`$_` rebinds inside catch blocks.**
The provisioning script's error handler referenced `$_.SamAccountName`,
but within a catch block `$_` is the error record rather than the pipeline
object, so failures logged as "FAILED :" with no username. Fixed by
assigning the pipeline object to a named variable at the top of the loop.
