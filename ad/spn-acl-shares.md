# SPNs, object rights, and shares

[← Active Directory quick reference](../05-active-directory.md)

Map SPNs and ACLs; record principal + right + target + inheritance.

## Service principal names

Use SPNs to find service accounts, hosts, and ports.

```powershell
Get-NetUser -SPN | Select-Object samaccountname,serviceprincipalname
nslookup.exe <service-host>.<domain.tld>
```

```cmd
setspn -L <service-account>
```

## Object ACLs

Resolve SIDs; verify `GenericAll`, `GenericWrite`, `WriteOwner`, `WriteDACL`, `AllExtendedRights`, `ForceChangePassword` on exact target.

```powershell
Get-ObjectAcl -Identity <user>
Convert-SidToName <principal-sid>
Get-ObjectAcl -Identity '<group>' |
    Where-Object {$_.ActiveDirectoryRights -eq 'GenericAll'} |
    Select-Object SecurityIdentifier,ActiveDirectoryRights
```

`WriteOwner`/`WriteDACL`: save and restore owner + ACL.

## Shares and SYSVOL

Search custom shares, scripts, policy backups, docs; retain source path for recovered creds.

```powershell
Find-DomainShare
Get-ChildItem \\<dc-fqdn>\sysvol\<domain.tld>\Policies\
Get-ChildItem \\<file-server>\<share>
```

```bash
gpp-decrypt '<CPASSWORD>'
```

Writable share needs a privileged load trigger for execution.

Search larger share sets:

```bash
nxc smb <subnet> -u <user> -p '<password>' -M spider_plus
manspider <subnet> -u <user> -p '<password>' -c password
nxc smb <dc-ip> -u <user> -p '<password>' -M gpp_password
nxc ldap <dc-ip> -u <user> -p '<password>' -M laps
```

GPP `cpassword`: `gpp-decrypt <cpassword>`. Writable script/plugin needs a privileged load trigger.
