# 03 · Linux Privilege Escalation

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Run baseline; confirm the privilege, writable target, and trigger for each lead.

```bash
id; sudo -l; uname -r; cat /etc/os-release
```

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Sudo rule | Read the exact binary, arguments, and environment that `sudo -l` allows. | [Sudo and root-run paths](linux/root-run.md) |
| SUID or capability | List unusual binaries and capabilities; inspect what the binary does. | [SUID and capabilities](linux/root-run.md#sudo-and-suid) |
| Root-run script or service | Can you change the file, a called command, its path, or its environment? Find the trigger. | [Root-run files](linux/root-run.md) |
| Cron or timer | Confirm the run-as user, action, schedule, and writable component. | [Root-run files](linux/root-run.md#find-the-path) |
| Privileged file write | Check whether a root process follows a path or archive entry you control. | [File-write paths](linux/file-write.md) |
| Docker or LXD | Confirm group membership and access to a rootful daemon socket. | [Groups and containers](linux/groups-and-nfs.md) |
| NFS export | Check the export, client access, write permission, and root squashing. | [NFS](linux/groups-and-nfs.md#nfs) |
| Saved credential | Search targeted configs, history, backups, and local-only services. | [Host checks](linux/host-checks.md) |
| Restricted shell | Test whether an allowed interpreter or command can start a normal shell. | [Restricted shells](linux/restricted-shells.md) |
| Kernel or package issue | Match the exact build, architecture, and patch state after local paths fail. | [Kernel checks](linux/kernel-checks.md) |

Failed path: check current user, ACL, and whether the privileged trigger ran.
