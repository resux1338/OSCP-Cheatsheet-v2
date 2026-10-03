# Root-run files and services

[← Linux quick reference](../03-linux-privesc.md) · [Sudo](sudo.md) · [SUID and capabilities](suid-and-capabilities.md)

Find root-run command/file you control; confirm arguments and trigger.

## Find the path

```bash
ps -eo user,pid,ppid,cmd --forest
find /opt /srv /usr/local/bin /etc/cron.d /etc/systemd/system -xdev -writable -ls 2>/dev/null
stat -Lc '%A %a %U:%G %n' /path/to/root-run-script
namei -l /path/to/root-run-script
getfacl -p /path/to/root-run-script /path/to/parent-directory
```

Scheduled task: inspect the full command/script, run-as identity, dependencies, environment, and actual trigger. Group/ACL access matters as well as world-writable mode bits. File write permission and permission to replace a directory entry are different checks. [Linux ACL semantics](https://man7.org/linux/man-pages/man5/acl.5.html).

```bash
cat /etc/crontab
ls -lah /etc/cron.* /var/spool/cron 2>/dev/null
systemctl list-timers --all
systemctl cat <service>
systemctl show <service> -p User -p Group -p ExecStart -p Environment \
  -p EnvironmentFiles -p WorkingDirectory -p FragmentPath -p DropInPaths
```

Check relative commands, writable paths, wildcards, preserved environment:

```bash
printf '%s\n' "$PATH"
find / -xdev -type d -writable -ls 2>/dev/null
rg '\*' /etc/cron.* /etc/systemd/system /usr/lib/systemd/system 2>/dev/null
```

Your interactive PATH does not establish the job's PATH. Read cron environment assignments and systemd units/drop-ins. Systemd command directives normally execute programs without a shell, so pipes, redirection, and globs require an actual shell/interpreter in the command. Inspect `EnvironmentFile` and `WorkingDirectory` along with the executable. [systemd execution](https://github.com/systemd/systemd/blob/main/man/systemd.exec.xml), [service command semantics](https://github.com/systemd/systemd/blob/main/man/systemd.service.xml).

If `rg` is unavailable, use the installed text-search tool. A wildcard or relative command is a lead only after the privileged command's arguments, working directory, and search path are established.

## Follow the dependency the privileged process actually consumes

| Lead | Confirm before changing anything |
| --- | --- |
| Writable script | It is invoked by the privileged caller, with the expected interpreter and arguments |
| Relative helper command | The caller's search path reaches your directory before a legitimate helper |
| Python import | Exact module/API and effective import order; see [sudo module proof](sudo.md#workflow-2-fixed-python-script-with-controllable-module-search) |
| Writable configuration | The caller loads it, what the field controls, and when changes take effect |
| Wildcard arguments | Exact expansion directory and option handling; filenames are not always parsed as command options |
| Writable shared library | Selected dependency and search order, loader restrictions, and a reproducible load trigger |

Use `pspy` to correlate short-lived processes and schedules. Read arguments and timestamps; observing a process name alone does not establish which writable component it consumes. [pspy](https://github.com/DominicBreuker/pspy).

## Before modifying a root-run file

Save original bytes, owner/group, mode, ACLs, relevant xattrs, and trigger state. Choose a benign identity/file proof and a single controlled run. Restore the introduced changes before another run consumes them, verify the original metadata, and remove only your proof artifacts. Use [privileged file-write checks](file-write.md) when the primitive writes to a chosen destination.
