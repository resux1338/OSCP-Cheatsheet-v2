# LDAP, hosts, and sessions

[← Active Directory quick reference](../05-active-directory.md)

Use this when you have a domain foothold but the AD PowerShell module is missing. Search from the domain DN and filter before collecting a large result set.

From Kali, a known account can give a quick user, group, share, and policy baseline:

```bash
nxc smb <dc-ip> -u <user> -p '<password>' --shares --users --groups --pass-pol
nxc smb <dc-ip> -u <user> -p '<password>' --rid-brute
ldapdomaindump -u '<domain>\\<user>' -p '<password>' <dc-ip>
```

If anonymous RPC is available, `rpcclient -U '' -N <dc-ip>` can list users and groups with `enumdomusers` and `enumdomgroups`. A scoped username list can also be checked with `kerbrute userenum -d <domain.tld> --dc <dc-ip> users.txt`.

## LDAP from PowerShell

```powershell
$PDC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
$DN = ([adsi]'').distinguishedName
$LDAP = "LDAP://$PDC/$DN"
$entry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)
$searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
$searcher.Filter = "(samAccountType=805306368)"
$searcher.FindAll()
```

The PDC is one discovered domain controller, not proof that other DCs have stale data. Keep the DN broad enough for the objects you need; adding `CN=Users` limits the search to that container.

For a reusable query:

```powershell
function LDAPSearch {
    param([string]$LDAPQuery)
    $PDC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
    $DN = ([adsi]'').distinguishedName
    $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$PDC/$DN")
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($entry, $LDAPQuery)
    $searcher.FindAll()
}

LDAPSearch -LDAPQuery "(objectClass=group)"
```

Inspect `member` on each returned group and follow nested group DNs. A direct-membership list can miss the route that matters.

## Hosts and sessions

```powershell
. .\PowerView.ps1
Get-NetComputer | Select-Object dnshostname,operatingsystem,operatingsystemversion
Get-NetUser | Select-Object samaccountname,description
Find-LocalAdminAccess
```

`Find-LocalAdminAccess` queries across the domain and can generate noticeable traffic. Use a smaller host set when scope or time calls for it.

```powershell
Get-NetSession -ComputerName <server-01> -Verbose
```

```cmd
PsLoggedon.exe \\<server-01>
```

`Get-NetSession` reads resource sessions; it is not a complete list of interactive logons. PsLoggedOn also depends on remote registry access for locally loaded profiles. Access denied or an empty result does not prove that nobody is logged on. Your own query can appear as a resource session.

## References

- [DirectorySearcher.Filter](https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.directorysearcher.filter)
- [NetSessionEnum](https://learn.microsoft.com/en-us/windows/win32/api/lmshare/nf-lmshare-netsessionenum)
- [PsLoggedOn](https://learn.microsoft.com/en-us/sysinternals/downloads/psloggedon)
