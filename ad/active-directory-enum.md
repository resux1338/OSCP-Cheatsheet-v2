# Active Directory enumeration

[← index](../README.md) · [AD quick reference](../05-active-directory.md)

Start with the supplied or recovered domain credential. Record `<DOMAIN.TLD>`, NetBIOS `<DOMAIN>`, `<DC-IP>`, `<DC-FQDN>`, `<USER>`, and the credential type. Repeat the useful checks after every new credential.

## Establish the domain picture

Confirm routing, DNS, the DC, and the services actually reachable from the current network position.

```bash
ip route get <DC-IP>
dig @<DC-IP> <DOMAIN.TLD> SOA +short
dig @<DC-IP> _ldap._tcp.dc._msdcs.<DOMAIN.TLD> SRV +short
nmap -Pn -sV -p 53,88,135,139,389,445,464,636,3268,3269,3389,5985,5986 <DC-IP>
nxc smb <DC-IP>
```

Kerberos failures: verify the FQDN, DNS server, and clock before changing tools. See [Kerberos troubleshooting](kerberos-troubleshooting.md).

## No-credential and guest checks

Try one controlled null and guest check. A rejected null session is not evidence that authenticated enumeration will fail.

```bash
nxc smb <DC-IP> -u '' -p '' --shares --users --groups --pass-pol
nxc smb <DC-IP> -u guest -p '' --shares
rpcclient -U '' -N <DC-IP> -c 'enumdomusers; enumdomgroups; getdompwinfo'
smbclient -N -L //<DC-IP>
```

If no usernames are known, a scoped Kerberos check can distinguish valid candidates. Failed pre-authentication counts toward lockout; learn the policy first when possible.

```bash
kerbrute userenum -d <DOMAIN.TLD> --dc <DC-IP> <USER-LIST>
```

## Known credential from Kali

Start with users, groups, policy, shares, and RID-derived accounts. Inline passwords are visible in shell history and sometimes process listings; prefer the tool's prompt or a protected local credential file when practical.

```bash
nxc smb <DC-IP> -d <DOMAIN> -u <USER> -p '<PASSWORD>' --shares --users --groups --pass-pol
nxc smb <DC-IP> -d <DOMAIN> -u <USER> -p '<PASSWORD>' --rid-brute
nxc smb <SUBNET-CIDR> -d <DOMAIN> -u <USER> -p '<PASSWORD>' --shares
ldapdomaindump -u '<DOMAIN>\\<USER>' -p '<PASSWORD>' -o <OUTPUT-DIR> <DC-IP>
```

Read the user descriptions, custom groups, computer operating systems, password and lockout policy, and every accessible non-default share. For each credential, record where it authenticates and whether it has local admin rights.

## From a domain Windows shell

Use built-ins first; they work when PowerView or the Active Directory module is unavailable.

```cmd
whoami /all
set USERDOMAIN
set USERDNSDOMAIN
set LOGONSERVER
nltest /dsgetdc:<DOMAIN.TLD>
nltest /dclist:<DOMAIN.TLD>
nltest /domain_trusts
net accounts /domain
net user /domain
net group /domain
net group "Domain Admins" /domain
net view /domain
```

```powershell
[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
([adsi]'').distinguishedName
Get-ChildItem "\\<DC-FQDN>\SYSVOL\<DOMAIN.TLD>\Policies" -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object FullName
```

## PowerView: prioritize useful fields

PowerView performs domain enumeration; PowerUp in the next section checks the local Windows host.

```powershell
. .\PowerView.ps1
Get-Domain
Get-DomainController
Get-DomainPolicyData
Get-DomainUser | Select-Object samaccountname,description,pwdlastset,lastlogon
Get-DomainUser -SPN | Select-Object samaccountname,serviceprincipalname
Get-DomainUser -PreauthNotRequired | Select-Object samaccountname,useraccountcontrol
Get-DomainGroup -Identity '*admin*' | Select-Object samaccountname,description
Get-DomainGroupMember -Identity 'Domain Admins' -Recurse
Get-DomainComputer | Select-Object dnshostname,operatingsystem,operatingsystemversion
Get-DomainTrust
Get-DomainGPO | Select-Object displayname,name
Get-DomainOU | Select-Object name,distinguishedname,gplink
Find-DomainShare -CheckShareAccess
Find-LocalAdminAccess
Find-InterestingDomainAcl -ResolveGUIDs
```

Session calls can be incomplete or require extra rights. An empty result or access denied does not prove that nobody is logged on.

```powershell
Get-NetSession -ComputerName <HOSTNAME> -Verbose
```

## BloodHound collection

Use a current collector matching the BloodHound edition. Default or all-method collection can contact many domain hosts; inspect the collector help and collection scope first.

```bash
bloodhound-ce-python -u <USER> -p '<PASSWORD>' -d <DOMAIN.TLD> -ns <DC-IP> -c Default --zip
nxc ldap <DC-IP> -d <DOMAIN> -u <USER> -p '<PASSWORD>' --bloodhound -c all --dns-server <DC-IP>
```

```powershell
.\SharpHound.exe -c Default --zipfilename <DOMAIN>-enum.zip
```

Mark the controlled principal as owned, confirm collection errors, and inspect shortest paths plus direct rights. See [BloodHound collection and path checks](bloodhound.md).

Check whether AD CS is present and whether the controlled account can enroll in a relevant template. `find` enumerates configuration; do not request a certificate from this sheet.

```bash
certipy find -u '<USER>@<DOMAIN.TLD>' -p '<PASSWORD>' -dc-ip <DC-IP> -vulnerable -stdout
```

Verify every reported template setting and enrollment right in [AD CS template checks](adcs.md).

## PowerUp: local enumeration only

Run this on each Windows foothold in the domain. These commands report local privilege-escalation leads; they do not enumerate AD objects.

```powershell
. .\PowerUp.ps1
Invoke-PrivescAudit
# Alias for the same audit in the PowerSploit version:
Invoke-AllChecks

Get-ProcessTokenPrivilege -Special
Get-UnquotedService
Get-ModifiableServiceFile
Get-ModifiableService
Get-RegistryAutoLogon
Get-ModifiableScheduledTaskFile
Get-UnattendedInstallFile
```

`Invoke-AllChecks` can display the name of a suggested abuse function, but it does not run that function. Keep this sheet to the audit commands above and verify every hit with native ACL, service, or task queries. See the full [Windows host enumeration](../windows/windows-host-enum.md#powerup-enumeration-only) checklist.

## Triage the findings

| Signal | Confirm next | Deeper notes |
| --- | --- | --- |
| Password or clue in a user description | Account state, scope, and lockout policy | [Authentication](authentication.md) |
| User-backed SPN or pre-auth disabled | Exact account, SPN, encryption, and policy | [Authentication](authentication.md) |
| Readable share or SYSVOL file | File contents, intended reader, and credential scope | [Shares and SPNs](spn-acl-shares.md) |
| Local-admin access or useful session | Target host, service, account scope, and route | [LDAP and sessions](ldap-and-sessions.md) · [Lateral movement](lateral-movement.md) |
| Interesting object ACL | Principal, exact right, target, inheritance, and current state | [Object rights](object-rights.md) |
| GPO relationship | Right on the GPO, linked scope, and affected objects | [GPO edges](gpo-edges.md) |
| Enrollment service or template | Enrollment rights and all template settings | [AD CS](adcs.md) |
| BloodHound path | Every edge and prerequisite, manually | [BloodHound](bloodhound.md) |

## References

- [OffSec: What to Expect From the New OSCP Exam](https://www.offsec.com/blog/what-to-expect-new-oscp-exam/)
- [NetExec SMB enumeration](https://www.netexec.wiki/smb-protocol/enumeration)
- [PowerSploit Recon / PowerView command reference](https://github.com/PowerShellMafia/PowerSploit/blob/master/Recon/README.md)
- [LDAPDomainDump](https://github.com/dirkjanm/ldapdomaindump)
- [SpecterOps: SharpHound target selection and collection](https://specterops.io/blog/2018/03/05/sharphound-target-selection-and-api-usage/)

## Where is the flag?

Check the expected desktop locations first, then search the full drive if a flag is missing. Run the search in the privilege context that should be able to read the flag.

```powershell
Get-ChildItem 'C:\Users\*\Desktop\local.txt','C:\Users\*\Desktop\proof.txt' `
    -Force -ErrorAction SilentlyContinue | Select-Object FullName

Get-ChildItem -Path C:\ -Include local.txt,proof.txt -File -Recurse -Force `
    -ErrorAction SilentlyContinue | Select-Object FullName
```

```cmd
where /r C:\ local.txt 2>nul
where /r C:\ proof.txt 2>nul
type "<FLAG-PATH>"
```

On an AD set, record the hostname and full path with each flag so results from different members are not mixed together.
