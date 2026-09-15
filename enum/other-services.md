# SSH, Telnet, Finger, rsync, and TFTP

[← Service index](service-triage.md)

Check every identified service, including non-web ports.

## SSH: 22

```bash
ssh-keyscan -T 5 <target-ip>
ssh -v <user>@<target-ip>
```

`ssh-keyscan` records advertised key only. Supplied key: `chmod 600 <key-file>; ssh -i <key-file> <user>@<target-ip>`.

## Telnet and Finger: 23, 79

```bash
nc -nv <target-ip> 23
finger @<target-ip>
finger <user>@<target-ip>
```

Telnet is plaintext. Finger can disclose users/sessions; empty output is inconclusive.

## rsync daemon: 873

```bash
rsync rsync://<target-ip>/
rsync rsync://<target-ip>/<module>/
rsync rsync://<target-ip>/<module>/<known-file> ./
```

Rsync: list modules → list selected module → copy file. Hidden/authenticated modules may not list; daemon transport is plaintext.

## TFTP: 69/UDP

TFTP has no normal listing; request a known filename:

```bash
curl -o <local-file> 'tftp://<target-ip>/<known-file>'
```

References: [OpenSSH `ssh-keyscan`](https://man.openbsd.org/ssh-keyscan.1) · [rsync daemon syntax](https://download.samba.org/pub/rsync/rsync.1) · [curl TFTP](https://curl.se/docs/manpage.html).
