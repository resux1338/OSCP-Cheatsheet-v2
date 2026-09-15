# SMB and RPC

[← Service index](service-triage.md) · [AD shares and ACLs](../ad/spn-acl-shares.md)

Anonymous/guest first; repeat with credentials. Test each share's read/write access.

```bash
smbclient -L //<target-ip>/ -U '' -N
nxc smb <target-ip> -u '' -p '' --shares
nxc smb <target-ip> -u 'guest' -p '' --shares
enum4linux-ng -A <target-ip>
smbmap -H <target-ip> -u null
```

Open share (`-U` prompts for password):

```bash
smbclient //<target-ip>/<share> -U '<domain>/<user>'
smbclient //<target-ip>/<share> -U '<domain>/<user>' -c 'ls; get notes.txt'
```

Inside: `pwd`, `ls`, `cd`, `get`; harmless `put` to test write. Check `SYSVOL`; retain source paths.

RPC null session:

```bash
rpcclient -U '' -N <target-ip> -c 'enumdomusers'
rpcclient -U '' -N <target-ip> -c 'enumdomgroups'
```

Known account RID enumeration: `nxc smb <target-ip> -u <user> -p '<password>' --rid-brute`.

SMB signing check (relay still needs a viable auth path):

```bash
nmap -p445 --script smb2-security-mode <target-ip>
```

References: [Samba `smbclient`](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html) · [Nmap SMB signing check](https://nmap.org/nsedoc/scripts/smb2-security-mode.html).
