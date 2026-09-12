# SSH, Telnet, Finger, rsync, and TFTP

[← Service index](service-triage.md)

These services are easy to skip when a web port is open. Check what each one exposes before trying credentials.

## SSH: 22

```bash
ssh-keyscan -T 5 <target-ip>
ssh -v <user>@<target-ip>
```

The key scan records the server's advertised host key; it does not authenticate the host by itself. With a supplied key, check its permissions and connect with `ssh -i <key-file> <user>@<target-ip>`.

## Telnet and Finger: 23, 79

```bash
nc -nv <target-ip> 23
finger @<target-ip>
finger <user>@<target-ip>
```

Telnet sends login data without TLS unless protected by another layer. Finger may disclose usernames or session details; an empty reply is not a user-validity test.

## rsync daemon: 873

```bash
rsync rsync://<target-ip>/
rsync rsync://<target-ip>/<module>/
rsync rsync://<target-ip>/<module>/<known-file> ./
```

The first command lists advertised modules, the second lists a selected module, and the third copies one file. A module can be hidden or require credentials. Direct daemon connections are not encrypted, so avoid sending sensitive credentials over an untrusted path.

## TFTP: 69/UDP

TFTP has no normal directory-list command. Try a known filename from a configuration, web page, or device hint:

```bash
curl -o <local-file> 'tftp://<target-ip>/<known-file>'
```

References: [OpenSSH `ssh-keyscan`](https://man.openbsd.org/ssh-keyscan.1) · [rsync daemon syntax](https://download.samba.org/pub/rsync/rsync.1) · [curl TFTP](https://curl.se/docs/manpage.html).
