# Unquoted service paths

[← Windows services](services.md)

Need unquoted path + writable tested `<prefix>.exe` + privileged service + trigger.

`C:\Program Files\Acme Tools\agent.exe` candidates: `C:\Program.exe`, `C:\Program Files\Acme.exe`. Check each parent ACL.

`C:\Apps\Team Tools\Service Agent\svc.exe` candidate: `C:\Apps\Team Tools\Service.exe`. Check exact path.

```powershell
Get-CimInstance -ClassName Win32_Service |
  Where-Object { $_.PathName -match '^[^"].*\s.*\.exe' -and $_.PathName -notmatch 'C:\\Windows' } |
  Select-Object Name, StartName, State, PathName

Test-Path 'C:\Program.exe'
icacls 'C:\'
icacls 'C:\Program Files'
Test-Path 'C:\Apps\Team Tools\Service.exe'
icacls 'C:\Apps\Team Tools'
sc.exe query <service-name>
```

Check `PathName` and arguments manually; avoid overwriting existing prefixes. Test exact path, then remove your file.

PowerUp discovery:

```powershell
. .\PowerUp.ps1
Get-UnquotedService
```

[Microsoft `CreateProcess` path parsing](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa)
