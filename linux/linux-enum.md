# Linux enumeration

[← index](../README.md) · [Linux privilege escalation](../03-linux-privesc.md)

Catch the low-hanging fruit before choosing a privilege-escalation path. Record the current identity, host and kernel, privileged process or file, your exact permission, and the trigger.

## First pass

```bash
id
groups
sudo -l
hostname
uname -a
cat /etc/os-release
env
printf '%s\n' "$PATH"
```

Read the exact command, arguments, run-as user, and environment allowed by every sudo rule. For a promising binary, continue with [sudo, SUID, and root-run paths](root-run.md).

## Users, homes, and credentials

```bash
getent passwd
getent group
w
last -n 20
ls -la /home /home/* /opt /srv /var/www /var/backups 2>/dev/null
```

Search likely application and user locations, not the entire filesystem first.

```bash
find "$HOME" /home /opt /srv /var/www /var/backups -maxdepth 4 -type f \
  \( -name '.*history' -o -name '.viminfo' -o -name 'id_rsa' -o -name '*.conf' \
     -o -name '*.ini' -o -name '*.yml' -o -name '*.yaml' -o -name '.env' -o -name '*.bak' \) \
  -readable 2>/dev/null

grep -RniE 'pass(word)?|secret|token|api.?key|connection.?string' \
  "$HOME" /opt /srv /var/www 2>/dev/null

ls -la /var/mail /var/spool/mail 2>/dev/null
```

Treat recovered material as a candidate. Record its source, likely account, and service; test reuse only against plausible accounts and services.

## Processes, cron, timers, and services

```bash
ps -eo user,pid,ppid,cmd --forest
crontab -l 2>/dev/null
cat /etc/crontab 2>/dev/null
ls -la /etc/cron.* /var/spool/cron /var/spool/cron/crontabs 2>/dev/null
systemctl list-timers --all 2>/dev/null
systemctl list-units --type=service --state=running 2>/dev/null
```

Watch short-lived privileged jobs when static files do not reveal the command.

```bash
./pspy64
```

For each lead, identify the privileged caller, every script or binary it invokes, whether any component is writable, and how often or how reliably it triggers.

## Network, mounts, and containers

```bash
ip -brief address
ip route
cat /etc/resolv.conf
ss -lntup
findmnt
cat /etc/fstab
mount
```

```bash
ls -l /var/run/docker.sock /run/containerd/containerd.sock 2>/dev/null
systemd-detect-virt 2>/dev/null
cat /proc/1/cgroup 2>/dev/null
```

A loopback listener may expose a management interface, database, or reused credential. A container socket or privileged group is only a lead until its daemon and permissions are confirmed. See [groups, containers, and NFS](groups-and-nfs.md).

## SUID, SGID, and capabilities

```bash
find / -xdev -perm -4000 -type f -exec ls -la {} \; 2>/dev/null
find / -xdev -perm -2000 -type f -exec ls -la {} \; 2>/dev/null
getcap -r / 2>/dev/null
```

Compare unusual binaries with their owner, version, arguments, and intended behavior. `-xdev` keeps the first pass fast; inspect other mounted filesystems separately when they matter.

## Writable privileged paths

Focus on places commonly referenced by services, timers, cron, and custom software.

```bash
find /etc/cron.d /etc/cron.daily /etc/systemd/system /usr/local/bin /opt /srv \
  -xdev -writable -ls 2>/dev/null

find /opt /srv /var/www -xdev -type f -writable -ls 2>/dev/null
```

A writable file is not automatically a privilege escalation. Confirm that a more-privileged process reads or executes it and that you can trigger or observe that action. Continue with [root-run files and services](root-run.md) or [privileged file-write paths](file-write.md).

## Automated enumeration

Run current tools as a supplement to the manual pass. Save output where the current user can write and verify highlighted findings yourself.

```bash
./linpeas.sh | tee /tmp/linpeas.txt
./lse.sh -l 1
./pspy64
```

Inspect a script and its version before running it. OffSec permits automatic enumeration, not automatic exploitation; current tool behavior matters.

## Triage the findings

| Signal | Confirm next | Deeper notes |
| --- | --- | --- |
| Sudo rule | Exact binary, arguments, environment, and run-as user | [Root-run paths](root-run.md) |
| Unusual SUID/SGID or capability | Owner, capability or mode, program behavior, and version | [SUID and capabilities](root-run.md#sudo-and-suid) |
| Root cron, timer, or service | Privileged caller, writable component, and trigger | [Root-run files](root-run.md) |
| Writable privileged destination | Whether the privileged process follows or overwrites that path | [File-write paths](file-write.md) |
| Docker, LXD, or privileged socket | Group membership, socket ACL, and rootful daemon | [Groups and containers](groups-and-nfs.md) |
| NFS mount or export | Client access, write permission, UID behavior, and root squashing | [NFS](groups-and-nfs.md#nfs) |
| Saved credential | Account, service, scope, and reuse | [Host checks](host-checks.md) |
| Kernel or package candidate | Exact build, architecture, configuration, and patch state | [Kernel checks](kernel-checks.md) |

## References

- [g0tmi1k: Basic Linux Privilege Escalation](https://blog.g0tmi1k.com/2011/08/basic-linux-privilege-escalation/)
- [HackTricks Linux privilege-escalation checklist](https://book.hacktricks.wiki/en/linux-hardening/checklist-linux-privilege-escalation.html)
- [0xNeel: OSCP privilege-escalation enumeration checklist](https://0xneel.medium.com/privilege-escalation-enumeration-checklist-2d995e9ddfe7)
- [FalconSpy: OSCP methodology](https://falconspy.medium.com/oscp-developing-a-methodology-32f4ab471fd6)
- [PEASS-ng linPEAS](https://github.com/peass-ng/PEASS-ng/tree/master/linPEAS)
- [pspy](https://github.com/DominicBreuker/pspy)
- [OffSec: Understanding Penetration Testing Tools](https://www.offsec.com/blog/understanding-penetration-testing-tools/)

## Where is the flag?

Check home directories first, then search `/` if the expected flag is missing. Permission errors are suppressed; repeat after elevation to reach root-only paths.

```bash
find /home /root -type f \( -name local.txt -o -name proof.txt \) -print 2>/dev/null
find / -type f \( -name local.txt -o -name proof.txt \) -print 2>/dev/null
cat '<FLAG-PATH>'
```

`local.txt` normally belongs to the user-level context; `proof.txt` normally requires root. Record the hostname and full path with the value.
