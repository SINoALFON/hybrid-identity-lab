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
