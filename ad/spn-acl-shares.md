# SPNs, object rights, and shares

[← Active Directory quick reference](../05-active-directory.md)

After the user, group, and host baseline, map service accounts and object rights. Record the principal, right, target, and whether the right is inherited before testing a path.

## Service principal names

An SPN identifies a Kerberos service instance. It can also point to a service account, hostname, and port worth checking.

```powershell
Get-NetUser -SPN | Select-Object samaccountname,serviceprincipalname
nslookup.exe <service-host>.<domain.tld>
```

```cmd
setspn -L <service-account>
```

## Object ACLs

Look for `GenericAll`, `GenericWrite`, `WriteOwner`, `WriteDACL`, `AllExtendedRights`, and `ForceChangePassword` on the exact target object. Resolve SIDs; a raw ACE is not yet an attack path.

```powershell
Get-ObjectAcl -Identity <user>
Convert-SidToName <principal-sid>
Get-ObjectAcl -Identity '<group>' |
    Where-Object {$_.ActiveDirectoryRights -eq 'GenericAll'} |
    Select-Object SecurityIdentifier,ActiveDirectoryRights
```

For a confirmed `WriteOwner` or `WriteDACL` path, save the original owner and ACL before a manual change. Restore both afterward.

## Shares and SYSVOL

Check custom shares, scripts, policy backups, and documentation. A recovered password may be old; record its file and test it only within scope.

```powershell
Find-DomainShare
Get-ChildItem \\<dc-fqdn>\sysvol\<domain.tld>\Policies\
Get-ChildItem \\<file-server>\<share>
```

```bash
gpp-decrypt '<CPASSWORD>'
```

An accessible share becomes an execution path only if a higher-privileged process loads something from it. Confirm that trigger before treating write access as code execution.

For larger share sets, search readable content for credentials and configuration files:

```bash
nxc smb <subnet> -u <user> -p '<password>' -M spider_plus
manspider <subnet> -u <user> -p '<password>' -c password
nxc smb <dc-ip> -u <user> -p '<password>' -M gpp_password
nxc ldap <dc-ip> -u <user> -p '<password>' -M laps
```

If `SYSVOL` contains a Group Policy Preferences `cpassword`, use `gpp-decrypt <cpassword>` on the recovered value. Keep the source share and path with the result. A writable extension, startup script, or application plug-in path matters only when a privileged process loads it.
