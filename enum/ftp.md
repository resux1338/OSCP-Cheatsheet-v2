# FTP

[← Service index](service-triage.md)

Check the banner and anonymous login, then list the directories the account can actually reach. Do not assume that a successful login grants file reads or writes.

```bash
nmap -p21 -sV --script ftp-anon <target-ip>
ftp <target-ip>
```

At the FTP prompt, try `anonymous` with a simple email address as the password when appropriate:

```text
pwd
ls -la
binary
get notes.txt
bye
```

For a quick anonymous listing or download without an interactive client:

```bash
curl -v 'ftp://<target-ip>/'
curl --list-only 'ftp://<target-ip>/pub/'
curl -o notes.txt 'ftp://<target-ip>/pub/notes.txt'
```

`--list-only` requests names and can omit directories or hidden files. Check the full listing when a directory looks empty. If upload is in scope, use a harmless file and verify where it lands; a writable FTP directory is useful only if another service consumes it.

References: [Nmap `ftp-anon`](https://nmap.org/nsedoc/scripts/ftp-anon.html) · [curl FTP options](https://curl.se/docs/manpage.html).
