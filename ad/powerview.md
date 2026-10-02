# PowerView

[← Active Directory quick reference](../05-active-directory.md) · [AD enumeration](active-directory-enum.md)

Windows PowerShell 5.1. Record account + right + target + service.

[Initial enumeration](#initial-enumeration) · [Lateral movement](#lateral-movement) · [Post-exploitation](#post-exploitation)

## Load and scope

Transfer [PowerView.ps1](https://github.com/PowerShellMafia/PowerSploit/blob/d943001a7defb5e0d1657085a77a0e78609be58f/Recon/PowerView.ps1), then load:

```powershell
. .\PowerView.ps1

$Domain = '<DOMAIN.TLD>'
$DC = '<DC-FQDN>'
$Principal = '<USER>'
$DomainDN = ($Domain.Split('.') | ForEach-Object { "DC=$_" }) -join ','
$LDAP = @{ Domain = $Domain; Server = $DC }
$Net = @{}
$Targets = @('<HOST1-FQDN>', '<HOST2-FQDN>')
```

`@LDAP` = domain/DC arguments. `@Net` = optional credentials for host calls.

Current logon by default. For another account:

```powershell
$Cred = Get-Credential -UserName '<DOMAIN>\<USER>' -Message 'Domain credential'
$LDAP.Credential = $Cred
$Net.Credential = $Cred
```

`-Credential` applies to that function. Native UNC reads need their own network context.

## Initial enumeration

### Domain, DCs, trusts

```powershell
whoami /all
Get-Domain -Domain $Domain @Net | Select-Object Name,Forest,PdcRoleOwner
Get-DomainSID @LDAP
Get-DomainController -LDAP @LDAP |
    Select-Object dnshostname,operatingsystem,distinguishedname
Get-DomainTrust @LDAP |
    Select-Object SourceName,TargetName,TrustDirection,TrustType,TrustAttributes
Get-ForestDomain -Forest '<FOREST-ROOT.TLD>' @Net | Select-Object Name
```

Trust: check direction + selective authentication + SID filtering + route.

### Password and lockout policy

```powershell
(Get-DomainPolicyData -Policy Domain @LDAP).SystemAccess
Get-DomainObject -Identity $DomainDN @LDAP `
    -Properties minpwdlength,pwdhistorylength,lockoutthreshold,lockoutduration,lockoutobservationwindow |
    Format-List

# Fine-grained policy for this user.
$PSO = (Get-DomainUser -Identity $Principal @LDAP `
    -Properties 'msDS-ResultantPSO').'msds-resultantpso'
if ($PSO) {
    Get-DomainObject -Identity $PSO @LDAP `
        -Properties name,'msDS-LockoutThreshold','msDS-LockoutDuration','msDS-LockoutObservationWindow' |
        Format-List
}
```

Check resultant policy before [password tests](authentication.md). LDAP lockout durations: negative 100 ns intervals.

### Users and groups

Read descriptions, notes, service ownership, and custom groups.

```powershell
$Users = Get-DomainUser @LDAP `
    -Properties samaccountname,description,info,pwdlastset,lastlogontimestamp,useraccountcontrol
$Users | Select-Object samaccountname,description,info,pwdlastset,lastlogontimestamp,useraccountcontrol

Get-DomainUser -Identity $Principal @LDAP |
    Select-Object samaccountname,objectsid,memberof,primarygroupid,admincount,badpwdcount
Get-DomainUser -AdminCount @LDAP | Select-Object samaccountname,memberof
Get-DomainGroup @LDAP | Select-Object samaccountname,description
Get-DomainGroup -Identity '*admin*' @LDAP | Select-Object samaccountname,member
Get-DomainGroupMember -Identity '<GROUP>' -Recurse @LDAP |
    Select-Object GroupName,MemberName,MemberSID,MemberDomain
Get-DomainGroup -MemberIdentity $Principal @LDAP |
    Select-Object samaccountname,objectsid
```

| Field / switch | Remember |
| --- | --- |
| `memberof` | Direct groups; primary group omitted |
| `-MemberIdentity` | Nested security groups; upstream skips BUILTIN SIDs |
| `adminCount=1` | Can be stale; verify current groups |
| `lastLogonTimestamp` | Approximate logon history |
| `lastLogon` | History on the queried DC |

Current shell groups: `whoami /groups`. Current sessions: [session checks](#sessions).

### SPNs and pre-auth

```powershell
Get-DomainUser -SPN -UACFilter NOT_ACCOUNTDISABLE @LDAP |
    Select-Object samaccountname,serviceprincipalname,description,pwdlastset
Get-DomainUser -PreauthNotRequired -UACFilter NOT_ACCOUNTDISABLE @LDAP |
    Select-Object samaccountname,useraccountcontrol
```

SPN → service account + host/port. Disabled pre-auth → AS-REP lead. [Roasting](authentication.md).

### Computers

```powershell
$Computers = Get-DomainComputer @LDAP `
    -Properties dnshostname,operatingsystem,operatingsystemversion,description,distinguishedname
$Computers | Select-Object dnshostname,operatingsystem,operatingsystemversion,description,distinguishedname

Get-DomainComputer -OperatingSystem 'Windows Server*' @LDAP |
    Select-Object dnshostname,operatingsystem
Get-DomainComputer -SPN 'MSSQLSvc/*' @LDAP |
    Select-Object dnshostname,serviceprincipalname
Get-DomainComputer -SearchBase '<OU-DN>' @LDAP | Select-Object dnshostname
```

Pick `$Targets` from useful hosts. Confirm DNS + ports; AD entries can be stale.

### Shares and SYSVOL

```powershell
Find-DomainShare -ComputerName $Targets -CheckShareAccess -Threads 1 @Net -Verbose
Get-NetShare -ComputerName '<FILE-SERVER-FQDN>' @Net -Verbose

# Search filenames in one share.
Find-InterestingFile -Path '\\<FILE-SERVER-FQDN>\<SHARE>' @Net `
    -Include '*pass*','*cred*','*.config','unattend*.xml'

# Search shares on selected hosts.
Find-InterestingDomainShareFile -ComputerName $Targets -Threads 1 @Net `
    -Include '*pass*','*.config'
```

`-CheckShareAccess` tests listing only. File searches match names/metadata; inspect contents separately.

SYSVOL with the intended credential:

```powershell
New-PSDrive -Name PVSysvol -PSProvider FileSystem -Root "\\$DC\SYSVOL\$Domain" @Net | Out-Null
Get-ChildItem 'PVSysvol:\scripts' -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object FullName
Get-ChildItem 'PVSysvol:\Policies' -Recurse -File -Filter '*.xml' |
    Select-String -Pattern 'cpassword' -List |
    Select-Object Path,LineNumber,Line
Remove-PSDrive -Name PVSysvol
```

Check scripts, configs, backups, GPP XML. Keep credential source paths.

GPP: `gpp-decrypt '<CPASSWORD>'`. Writable file needs a privileged load trigger. [Share follow-up](spn-acl-shares.md#shares-and-sysvol).

### Object ACLs

Build the account + group SID list. Inspect the exact target.

```powershell
$PrincipalSids = @((Get-DomainObject -Identity $Principal @LDAP -Properties objectsid).objectsid)
$PrincipalSids += @(Get-DomainGroup -MemberIdentity $Principal @LDAP | Select-Object -ExpandProperty objectsid)
$PrincipalSids += 'S-1-1-0','S-1-5-11'   # Everyone / Authenticated Users

$TargetAcl = Get-DomainObjectAcl -Identity '<TARGET-DN-OR-NAME>' -ResolveGUIDs @LDAP
$TargetAcl | Where-Object { $PrincipalSids -contains $_.SecurityIdentifier.Value } |
    Select-Object ObjectDN,ObjectSID,SecurityIdentifier,AceQualifier,ActiveDirectoryRights,
        ObjectAceType,InheritedObjectAceType,AceFlags
ConvertFrom-SID -ObjectSid '<SID>' @LDAP
```

`ObjectSID` = target. `SecurityIdentifier` = ACE principal.

Check allow/deny + inheritance + exact GUID. Include BUILTIN groups and SID history where relevant.

| Right | Check next |
| --- | --- |
| `GenericAll` | User reset / group membership / computer attributes |
| `GenericWrite` / `WriteProperty` | Exact writable attribute |
| `WriteDacl` / `WriteOwner` | Required right; save original DACL/owner |
| `ExtendedRight` | Exact right, e.g. `User-Force-Change-Password` |
| `Self` / `WriteProperty` on `member` | Self-membership versus broader group control |
| GPO write | AD object + SYSVOL + affected scope |

Use [object rights](object-rights.md) or [GPO edges](gpo-edges.md) after confirming the ACL.

Wider search:

```powershell
Find-InterestingDomainAcl -SearchBase '<OU-OR-DOMAIN-DN>' -ResolveGUIDs @LDAP |
    Where-Object { $PrincipalSids -contains $_.SecurityIdentifier.Value } |
    Select-Object ObjectDN,IdentityReferenceName,AceQualifier,ActiveDirectoryRights,ObjectAceType
```

Helper skips low-RID SIDs. Confirm hits with the exact target ACL.

## Lateral movement

### Local admin access

```powershell
Test-AdminAccess -ComputerName $Targets @Net -Verbose |
    Select-Object ComputerName,IsAdmin
Find-LocalAdminAccess -ComputerName $Targets -Threads 1 @Net -Verbose
Get-NetLocalGroupMember -ComputerName '<HOST-FQDN>' -GroupName 'Administrators' -Method API @Net |
    Select-Object ComputerName,GroupName,MemberName,SID,IsGroup,IsDomain
```

`IsAdmin=True` = full Service Control Manager access. Confirm the execution method.

Expand returned domain groups. Localized Windows: use the actual local group name.

```powershell
Test-NetConnection -ComputerName '<HOST-FQDN>' -Port 445
```

| Method | Port / access |
| --- | --- |
| SMB/service exec | 445 + share + service-control rights |
| WinRM | 5985/5986 + endpoint rights |
| WMI/DCOM | 135 + dynamic RPC + target rights |

Account + access + reachable service → [lateral commands](lateral-movement.md).

### Sessions

```powershell
# Resource sessions; CName = connecting client.
Get-NetSession -ComputerName '<HOST-FQDN>' @Net -Verbose |
    Select-Object ComputerName,UserName,CName,Time,IdleTime

# Workstation logons; may need extra rights.
Get-NetLoggedon -ComputerName '<HOST-FQDN>' @Net -Verbose |
    Select-Object ComputerName,UserName,LogonDomain,LogonServer

# Find one user on selected hosts.
Find-DomainUserLocation -ComputerName $Targets -UserIdentity '<USER>' `
    -UserDomain $Domain -Server $DC -Threads 1 @Net -Verbose |
    Select-Object ComputerName,UserDomain,UserName,SessionFrom
```

Empty/access denied ≠ no users. Your query can create sessions.

Session ≠ readable credentials. Logged-on results can include service/batch logons.

`Find-DomainUserLocation`: unreliable `LocalAdmin` field. Check `ComputerName` / `SessionFrom` with `Test-AdminAccess` separately.

### GPO admin mappings

```powershell
Get-DomainOU @LDAP | Select-Object name,distinguishedname,gplink,gpoptions
Get-DomainGPO @LDAP | Select-Object displayname,name,gpcfilesyspath
Get-DomainGPO -ComputerIdentity '<HOST-FQDN>' @LDAP |
    Select-Object displayname,name,gpcfilesyspath

# Local-group settings in one GPO.
Get-DomainGPOLocalGroup -Identity '<GPO-GUID>' -ResolveMembersToSIDs @LDAP |
    Select-Object GPODisplayName,GPOType,GroupName,GroupSID,GroupMembers,GroupMemberOf

# Account -> hosts with GPO Administrators membership.
Get-DomainGPOUserLocalGroupMapping -Identity $Principal -LocalGroup 'Administrators' @LDAP |
    Select-Object ObjectName,GPODisplayName,ContainerName,ComputerName

# Host -> users/groups with GPO Administrators membership.
Get-DomainGPOComputerLocalGroupMapping -ComputerIdentity '<HOST-FQDN>' `
    -LocalGroup 'Administrators' @LDAP |
    Select-Object ComputerName,ObjectName,IsGroup,GPODisplayName,GPOGuid
```

Confirm live membership + link state + inheritance + security/WMI/item filtering.

GPO link alone ≠ host control. [GPO rights and scope](gpo-edges.md).

## Post-exploitation

### New credentials

```powershell
$Principal = '<NEW-USER>'
$Cred = Get-Credential -UserName '<DOMAIN>\<NEW-USER>' -Message 'New credential'
$LDAP.Credential = $Cred
$Net.Credential = $Cred

Get-DomainGroup -MemberIdentity $Principal @LDAP | Select-Object samaccountname,objectsid
Test-AdminAccess -ComputerName $Targets @Net -Verbose
Find-DomainShare -ComputerName $Targets -CheckShareAccess -Threads 1 @Net -Verbose
```

Rerun denied shares + promising ACLs/hosts. Rebuild `$PrincipalSids` in [ACL checks](#object-acls).

Changed group membership → fresh logon. Local admin/SYSTEM → [Windows credential access](../windows/credential-access.md).

### Delegation

```powershell
# Unconstrained; separate DCs from member hosts.
Get-DomainComputer -Unconstrained @LDAP | Select-Object dnshostname,useraccountcontrol

# Constrained: users and computers.
Get-DomainObject -LDAPFilter '(msDS-AllowedToDelegateTo=*)' @LDAP |
    Select-Object samaccountname,useraccountcontrol,'msDS-AllowedToDelegateTo'

# Protocol-transition flag.
Get-DomainUser -TrustedToAuth @LDAP |
    Select-Object samaccountname,'msDS-AllowedToDelegateTo'
Get-DomainComputer -TrustedToAuth @LDAP |
    Select-Object dnshostname,'msDS-AllowedToDelegateTo'

# Existing RBCD descriptor.
Get-DomainComputer -LDAPFilter '(msDS-AllowedToActOnBehalfOfOtherIdentity=*)' @LDAP `
    -Properties dnshostname,'msDS-AllowedToActOnBehalfOfOtherIdentity' |
    Format-List
```

Constrained: controlled account + allowed SPN. RBCD: decode descriptor → allowed SIDs.

New RBCD path needs target-attribute write + controlled service principal. [Delegation](tickets.md) · [Object rights](object-rights.md).

### LAPS

```powershell
Get-DomainComputer -Identity '<HOST-FQDN>' @LDAP `
    -Properties dnshostname,'ms-Mcs-AdmPwd','msLAPS-Password','msLAPS-EncryptedPassword' |
    Select-Object dnshostname,'ms-Mcs-AdmPwd','msLAPS-Password',
        @{Name='EncryptedLapsPresent';Expression={$null -ne $_.'mslaps-encryptedpassword'}} |
    Format-List
```

| Attribute | Meaning |
| --- | --- |
| `ms-Mcs-AdmPwd` | Legacy LAPS password |
| `msLAPS-Password` | Windows LAPS JSON password |
| `msLAPS-EncryptedPassword` | Ciphertext; needs decryption rights + LAPS module |

Windows LAPS decryption: `Get-LapsADPassword`. Match local account + host.

Empty field: no read right / different storage / no value.

### DCSync rights

Use `$PrincipalSids` from [ACL checks](#object-acls). Query the domain root:

```powershell
$RootAcl = Get-DomainObjectAcl -Identity $DomainDN -ResolveGUIDs @LDAP
$RootAcl | Where-Object { $PrincipalSids -contains $_.SecurityIdentifier.Value } |
    Select-Object SecurityIdentifier,AceQualifier,ActiveDirectoryRights,ObjectAceType,AceFlags
```

| Required right | GUID |
| --- | --- |
| `DS-Replication-Get-Changes` | `1131f6aa-9c07-11d1-f79f-00c04fc2dcd2` |
| `DS-Replication-Get-Changes-All` | `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2` |

Both rights, or broader effective rights, must apply at the domain root.
Check group SIDs + deny ACEs + filtered-set restrictions. [DCSync](credential-access.md#dc-database-or-replication).

## Save results

Export before `Format-*`. Label account + DC + time before switching credentials.

```powershell
$PVOut = Join-Path $PWD ('powerview-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $PVOut | Out-Null
"$Principal | $Domain | $DC | $(Get-Date -Format o)" |
    Set-Content -Path (Join-Path $PVOut 'context.txt')
$Users | Export-Clixml -Depth 5 -Path (Join-Path $PVOut 'users.xml')
$Computers | Export-Clixml -Depth 5 -Path (Join-Path $PVOut 'computers.xml')
$TargetAcl | Export-Clixml -Depth 5 -Path (Join-Path $PVOut 'target-acl.xml')
```

CLIXML preserves arrays; it is not a restorable ACL backup.
Before object edits: save original attributes + owner + DACL. Restore changes afterward.

## Quick fixes

| Problem | Check |
| --- | --- |
| Missing command / bad parameter | `Get-Command`; `Get-Help <FUNCTION> -Full`; loaded version |
| LDAP fails | Credential + DC + domain DN + DNS + LDAP route; add `-Verbose` |
| LDAP works, host calls fail | RPC/SMB route + firewall + host rights + `@Net` credential |
| Finder skips an SMB host | Finders ping first. Use direct `Get-NetShare`, `Get-NetSession`, or `Test-AdminAccess`. |
| UNC access denied | Intended logon or credentialed PSDrive |
| Remoting access differs | Token + [second hop](https://learn.microsoft.com/en-us/powershell/scripting/security/remoting/ps-remoting-second-hop) + [Kerberos](kerberos-troubleshooting.md) |
| ACL/GPO path fails | Groups + deny/inheritance + GUID + policy scope |
| Export loses values | Export raw objects; CLIXML or join arrays for CSV |

Path graph: [BloodHound](bloodhound.md). Native fallbacks: [AD enumeration](active-directory-enum.md).

## Older aliases

Use current parameters, e.g. `-Identity` for groups. Check local help.

| Older name | Current name |
| --- | --- |
| `Get-NetDomain` / `Get-NetDomainController` | `Get-Domain` / `Get-DomainController` |
| `Get-NetForest` | `Get-Forest` |
| `Get-NetUser` / `Get-NetGroup` / `Get-NetComputer` | `Get-DomainUser` / `Get-DomainGroup` / `Get-DomainComputer` |
| `Get-ObjectAcl` / `Convert-SidToName` | `Get-DomainObjectAcl` / `ConvertFrom-SID` |
| `Get-NetGPO` / `Get-NetGPOGroup` | `Get-DomainGPO` / `Get-DomainGPOLocalGroup` |
| `Invoke-ShareFinder` / `Invoke-FileFinder` | `Find-DomainShare` / `Find-InterestingDomainShareFile` |
| `Invoke-UserHunter` | `Find-DomainUserLocation` |

`Get-NetSession` / `Get-NetLoggedon` retain their names.
`Get-NetGPOGroup` reads local-group policy settings, not security-filtering groups.

## References

- [PowerView source — pinned copy](https://github.com/PowerShellMafia/PowerSploit/blob/d943001a7defb5e0d1657085a77a0e78609be58f/Recon/PowerView.ps1) · [Function reference](https://powersploit.readthedocs.io/en/latest/Recon/) · [Author's examples](https://gist.github.com/HarmJ0y/184f9822b195c52dd50c379ed3117993)
- [Microsoft: resultant password policy](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduserresultantpasswordpolicy) · [Protected accounts](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/security-best-practices/appendix-c--protected-accounts-and-groups-in-active-directory)
- [Microsoft: LAPS schema](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-technical-reference) · [LAPS cmdlets](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-management-powershell)
- [Microsoft: Get Changes](https://learn.microsoft.com/en-us/windows/win32/adschema/r-ds-replication-get-changes) · [Get Changes All](https://learn.microsoft.com/en-us/windows/win32/adschema/r-ds-replication-get-changes-all)
- [Starting notes: YousafImtiaz](https://github.com/YousafImtiaz/OSCP-Playbook/tree/main/7%20Active%20Directory/1%20Enumeration/3%20Powerview) · [MGamalCYSEC](https://github.com/MGamalCYSEC/Active-Directory-Enumeration-and-Attacks/blob/main/AD%20Enumeration/Manual%20Enumeration/PowerView.md)
