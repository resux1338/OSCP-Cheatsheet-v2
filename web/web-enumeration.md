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
