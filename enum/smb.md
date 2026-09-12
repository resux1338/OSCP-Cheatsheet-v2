# SMB and RPC

[← Service index](service-triage.md) · [AD shares and ACLs](../ad/spn-acl-shares.md)

Start with anonymous and guest access, then repeat with a known account. A share listing does not prove that you can read the share or write to it.

```bash
smbclient -L //<target-ip>/ -U '' -N
nxc smb <target-ip> -u '' -p '' --shares
nxc smb <target-ip> -u 'guest' -p '' --shares
enum4linux-ng -A <target-ip>
smbmap -H <target-ip> -u null
```

Open one share and inspect its contents. `-U` prompts for the password when you omit it from the argument:

```bash
smbclient //<target-ip>/<share> -U '<domain>/<user>'
smbclient //<target-ip>/<share> -U '<domain>/<user>' -c 'ls; get notes.txt'
```

Inside `smbclient`, use `pwd`, `ls`, `cd`, and `get`. Use `put` only after confirming write scope and choosing a harmless test file. Check `SYSVOL` for scripts and policy files, and keep the remote path with anything you copy.

If RPC allows a null session, query users and groups without guessing names:

```bash
rpcclient -U '' -N <target-ip> -c 'enumdomusers'
rpcclient -U '' -N <target-ip> -c 'enumdomgroups'
```

With a known account, `nxc smb <target-ip> -u <user> -p '<password>' --rid-brute` can fill in names that anonymous RPC hides. Check the account lockout policy before any login testing.

Check SMB2/3 signing before considering any authentication-relay path. This is a configuration check, not proof that a relay will work:

```bash
nmap -p445 --script smb2-security-mode <target-ip>
```

References: [Samba `smbclient`](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html) · [Nmap SMB signing check](https://nmap.org/nsedoc/scripts/smb2-security-mode.html).
