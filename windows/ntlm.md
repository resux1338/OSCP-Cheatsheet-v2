# NT hashes and NetNTLMv2

[← Windows quick reference](../04-windows-privesc.md)

NT hash: offline crack or Pass the Hash on NTLM service. NetNTLMv2: crack first; it is not passable.

For induced authentication without local admin rights, see [Net-NTLM capture with `ntlm_theft`](ntlm-capture.md).

Local accounts' unsalted NT hashes reside in the SAM; direct copying of the live hive can fail because it is in use. An authorized `reg save`/offline extraction or Mimikatz dump is a different path from inducing a network challenge-response. LSASS handles logon material, but its contents depend on the logon type and Windows protections: administrative rights and `SeDebugPrivilege` do **not** guarantee readable credentials when LSA protection or Credential Guard is active. See [Windows credential checks](credentials.md) for registry-hive and credential sources.

Administrator/SYSTEM, non-interactive Mimikatz under WinRM:

```powershell
.\mimikatz.exe "privilege::debug" "token::elevate" "lsadump::sam" "exit"
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
```

Run the quoted commands with `"exit"` under non-interactive WinRM; launching Mimikatz alone expects an interactive prompt. `privilege::debug` needs sufficient rights, and `token::elevate` only works if a usable token is available. An empty or protected LSASS result is not evidence that the user has no credentials. Do not rely on plaintext: WDigest plaintext caching is disabled by default on modern Windows, and Credential Guard/LSA protection may prevent memory access.

```bash
hashcat -m 1000 nt.txt /usr/share/wordlists/rockyou.txt
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
```

If LSASS minidump rights are available:

```powershell
procdump -accepteula -ma lsass.exe C:\Windows\Temp\lsass.dmp
```

```bash
pypykatz lsa minidump lsass.dmp
```

References: [Microsoft credential processes](https://learn.microsoft.com/en-us/windows-server/security/windows-authentication/credentials-processes-in-windows-authentication) · [LSA protection](https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection) · [Credential Guard](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/how-it-works).
