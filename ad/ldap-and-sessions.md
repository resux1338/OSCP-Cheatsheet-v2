# LDAP, hosts, and sessions

[← Active Directory quick reference](../05-active-directory.md)

Without AD module: query LDAP from domain DN with a narrow filter.

Kali baseline with known account:

```bash
nxc smb <dc-ip> -u <user> -p '<password>' --shares --users --groups --pass-pol
nxc smb <dc-ip> -u <user> -p '<password>' --rid-brute
ldapdomaindump -u '<domain>\\<user>' -p '<password>' <dc-ip>
```

Anonymous RPC: `rpcclient -U '' -N <dc-ip>` → `enumdomusers`, `enumdomgroups`. Scoped user check: `kerbrute userenum -d <domain.tld> --dc <dc-ip> users.txt`.

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

PDC discovery does not compare DC freshness. `CN=Users` limits search to that container.

Reusable LDAP query:

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

Follow nested group DNs via `member`.

## Hosts and sessions

```powershell
. .\PowerView.ps1
Get-NetComputer | Select-Object dnshostname,operatingsystem,operatingsystemversion
Get-NetUser | Select-Object samaccountname,description
Find-LocalAdminAccess
```

`Find-LocalAdminAccess` is domain-wide; use a smaller host set when needed.

```powershell
Get-NetSession -ComputerName <server-01> -Verbose
```

```cmd
PsLoggedon.exe \\<server-01>
```

`Get-NetSession` = resource sessions; PsLoggedOn needs remote registry. Empty/access denied ≠ nobody logged on; your query may appear.

## References

- [DirectorySearcher.Filter](https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.directorysearcher.filter)
- [NetSessionEnum](https://learn.microsoft.com/en-us/windows/win32/api/lmshare/nf-lmshare-netsessionenum)
- [PsLoggedOn](https://learn.microsoft.com/en-us/sysinternals/downloads/psloggedon)
