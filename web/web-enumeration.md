# Web enumeration

[← Recon quick reference](../01-recon.md)

Add the discovered hostname to `/etc/hosts` before testing virtual hosts or an HTTPS site that uses SNI. Read source, JavaScript, `/robots.txt`, `/sitemap.xml`, and backup files before choosing an attack path.

```bash
whatweb http://<target-ip>
curl -sI http://<target-ip>
```

```bash
feroxbuster -u http://<target-ip> -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -x php,txt,html,bak,zip
ffuf -u http://<target-ip>/FUZZ -w <wordlist> -e .php,.txt,.bak -mc all -fc 404
```

For virtual hosts and parameters, establish a baseline response size first. A copied `-fs` value can hide valid results.

```bash
ffuf -u http://<target-ip> -H 'Host: FUZZ.<domain.tld>' -w <subdomain-list> -fs <baseline-size>
ffuf -u 'http://<target-ip>/page.php?FUZZ=test' -w <parameter-list> -fs <baseline-size>
```

Scan output is a lead. Manually confirm any claimed file exposure, input reflection, or authentication weakness.

When a CMS is identified, enumerate that product and its installed components:

```bash
wpscan --url http://<target> --enumerate u,vp,vt
droopescan scan drupal -u http://<target>
joomscan -u http://<target>
```

Check exposed `.git/`, backup extensions, `robots.txt`, and JavaScript for endpoints or credentials before trying a generic exploit.
