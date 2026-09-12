# Linux host checks

[← Linux quick reference](../03-linux-privesc.md)

Look for credentials and reachable services before chasing a kernel issue. Record the current user and the exact file or process that exposed each lead.

```bash
./linpeas.sh | tee linpeas.txt
./pspy64
```

Use automated output to select a path, then verify the permission, owner, and trigger manually.

```bash
id
ls -la /home/* /opt /srv /var/www 2>/dev/null
find /var/backups /opt /srv /var/www -maxdepth 3 -type f 2>/dev/null
ss -tlnp
ps -eo user,pid,ppid,cmd --forest
```

Check readable application configs, database settings, shell history, `.mysql_history`, `.viminfo`, mail, backups, and SSH keys. A found password may work for `su`, SSH, an app, or another service, but test the matching account deliberately.

For a loopback-only service, confirm its port from the host and forward just that service through the [pivoting notes](../06-pivoting.md).
