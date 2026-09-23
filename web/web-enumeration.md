# Web enumeration

[← Recon quick reference](../01-recon.md)

Use discovered hostname for Host/SNI. Check source, JS, `robots.txt`, `sitemap.xml`, backups.

For product and version clues, follow the [web fingerprinting workflow](fingerprinting.md).

```bash
whatweb http://<target-ip>
curl -sI http://<target-ip>
```

```bash
feroxbuster -u http://<target-ip> -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -x php,txt,html,bak,zip
ffuf -u http://<target-ip>/FUZZ -w <wordlist> -e .php,.txt,.bak -mc all -fc 404
```

Measure baseline size before setting `-fs`:

```bash
ffuf -u http://<target-ip> -H 'Host: FUZZ.<domain.tld>' -w <subdomain-list> -fs <baseline-size>
ffuf -u 'http://<target-ip>/page.php?FUZZ=test' -w <parameter-list> -fs <baseline-size>
```

For an identified CMS:

```bash
wpscan --url http://<target> --enumerate u,vp,vt
droopescan scan drupal -u http://<target>
joomscan -u http://<target>
```

Check `.git/`, backup extensions, and JS for endpoints/credentials. Confirm scanner hits manually.

Keep a list of functions, parameters, and roles from real requests. Compare normal and changed responses; repeat path and function checks after login or a role change. [Input and access checks](../02-foothold.md).
