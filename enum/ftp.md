# FTP

[← Service index](service-triage.md)

Banner → anonymous login → list/read permissions.

```bash
nmap -p21 -sV --script ftp-anon <target-ip>
ftp <target-ip>
```

Interactive anonymous (`anonymous` + email password):

```text
pwd
ls -la
binary
get notes.txt
bye
```

Curl anonymous listing/download:

```bash
curl -v 'ftp://<target-ip>/'
curl --list-only 'ftp://<target-ip>/pub/'
curl -o notes.txt 'ftp://<target-ip>/pub/notes.txt'
```

`--list-only` may omit directories/hidden files. For upload, verify destination and what service consumes it.

References: [Nmap `ftp-anon`](https://nmap.org/nsedoc/scripts/ftp-anon.html) · [curl FTP options](https://curl.se/docs/manpage.html).
