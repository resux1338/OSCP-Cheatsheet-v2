# Linux host checks

[← Linux quick reference](../03-linux-privesc.md)

Start with current user, credentials, and reachable services.

```bash
./linpeas.sh | tee linpeas.txt
./pspy64
```

Verify permission, owner, and trigger behind tool hits.

```bash
id
ls -la /home/* /opt /srv /var/www 2>/dev/null
find /var/backups /opt /srv /var/www -maxdepth 3 -type f 2>/dev/null
ss -tlnp
ps -eo user,pid,ppid,cmd --forest
```

Search app/DB configs, histories, mail, backups, SSH keys; test recovered creds against their account/service.

```bash
find /home /opt /srv /var/www -type f \( -name '.*history' -o -name '.viminfo' -o -name 'id_rsa' -o -name '*.conf' -o -name '.env' \) 2>/dev/null
grep -RniE 'pass(word)?|secret|token|api.?key' /var/www /opt /srv 2>/dev/null
```

Loopback service: verify port, then [forward it](../06-pivoting.md).
