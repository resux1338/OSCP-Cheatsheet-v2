# AD credential access

[← Active Directory quick reference](../05-active-directory.md) · [Windows token rights](../windows/token-groups.md)

This page covers the DC database and directory replication. For local SAM, LSA, LSASS, and cached material on a Windows foothold, use [Windows credential access](../windows/credential-access.md).

## DC database or replication

| Path | Prerequisite |
| --- | --- |
| Offline NTDS analysis | A usable DC database copy and its corresponding SYSTEM boot-key material |
| Snapshot creation | Local administrator/equivalent snapshot rights, available VSS provider, and correct volume |
| Backup-mode copy | Present/usable backup privilege and a tool requesting backup semantics |
| DCSync | Effective replication rights at the domain root and reachable directory-replication services |

SeBackupPrivilege alone does not promise permission to create a snapshot. A DC's local SAM is separate from NTDS and does not contain the entire domain. [Diskshadow prerequisites](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow).

## Snapshot and offline analysis

Example lab prerequisites: an authorized administrator context on the selected DC, NTDS located at `C:\Windows\NTDS`, an unused `X:` drive, a new `C:\Temp\LabNtds` output directory, and verified copy/cleanup access. Check actual database/system volumes rather than assume default paths. Capture current shadows and writer state before adding one:

```cmd
whoami /priv
vssadmin list shadows
vssadmin list writers
mkdir C:\Temp\LabNtds
```

Save this complete script as `C:\Temp\LabNtds\snapshot.dsh` using an available editor. This example keeps writer participation enabled; verify writer results and database consistency before parsing:

```text
set context persistent
set metadata C:\Temp\LabNtds\metadata.cab
add volume C: alias labntds
create
expose %labntds% X:
```

Run it and record the newly created shadow ID, set ID, exposure, and result. Copy the actual database and matching SYSTEM hive:

```cmd
diskshadow /s C:\Temp\LabNtds\snapshot.dsh
robocopy /b X:\Windows\NTDS C:\Temp\LabNtds ntds.dit
robocopy /b X:\Windows\System32\config C:\Temp\LabNtds SYSTEM
dir C:\Temp\LabNtds\ntds.dit C:\Temp\LabNtds\SYSTEM
```

Check each copy: Robocopy codes below `8` are not necessarily errors, but code `0` alone does not prove a new file was copied. Use a fresh destination, inspect file size, and compare source/copy hashes where readable. A nondefault or dirty database can need consistency/recovery handling; do not claim success from the snapshot command alone. [Robocopy return values](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy).

Transfer only the required analysis files through the existing authorized route. On Kali:

```bash
impacket-secretsdump -ntds ntds.dit -system SYSTEM LOCAL
```

After successful copy/required evidence retention, delete **only** the created shadow. In Diskshadow, use the recorded ID:

```text
delete shadows id <CREATED-SHADOW-ID>
exit
```

Verify that the intended exposure is gone and unrelated shadows remain; remove only the script, metadata, copies, and output created for this exercise. `delete shadows all` is not appropriate cleanup. [Scoped shadow deletion](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/delete-shadows).

## DCSync: inspect rights and select the account

Use [PowerView domain-root ACL checks](powerview.md#dcsync-rights) to confirm Get-Changes and Get-Changes-All or equivalent effective rights, including group memberships/deny entries. Host local-admin rights do not automatically imply replication rights.

For one selected lab account, let the tool prompt for the operator's password:

```bash
impacket-secretsdump -dc-ip <DC-IP> -just-dc-user labuser 'corp.example/operator@dc01.corp.example'
```

If full directory-secret collection is actually the intended scope, `-just-dc` is broader. Record the requested account and output type; `-just-dc-user` limits collection but does not bypass missing replication rights. [Impacket replication options](https://github.com/fortra/impacket/blob/master/examples/secretsdump.py).

Match recovered NT/AES keys to their account and a reachable service in [lateral movement](lateral-movement.md) or [ticket handling](tickets.md). Preserve any original ACL if a separately confirmed object-rights path granted temporary replication permission; restoring that ACL is distinct from deleting local extraction output.

Sources reviewed on 2026-10-02. Snapshot creation/copy, database consistency, DCSync, and cleanup remain pending isolated-DC validation.
