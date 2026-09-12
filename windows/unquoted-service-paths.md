# Unquoted service paths

[← Windows services](services.md)

An executable path with spaces and no surrounding quotes can make Windows try an earlier `<prefix>.exe`. The finding needs a writable **tested filename**, a service running as a more privileged account, and a trigger. A writable application directory by itself is not enough.

For `C:\Program Files\Acme Tools\agent.exe`, Windows may try `C:\Program.exe` and `C:\Program Files\Acme.exe` before the intended file. Check the parent directory of each candidate, not just `C:\Program Files\Acme Tools`.

A writable application directory can matter when it contains one of the prefixes. For `C:\Apps\Team Tools\Service Agent\svc.exe`, one candidate is `C:\Apps\Team Tools\Service.exe`. Check whether that exact file exists and whether you can create it in `C:\Apps\Team Tools`.

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

The filter only finds candidates. Read `PathName` yourself to separate the executable from its arguments and check whether it is actually unquoted. Do not overwrite an existing prefix executable. If a writable candidate and trigger are confirmed, place your file at that exact path, test, and remove it afterward.

PowerUp's `Get-UnquotedService` is another discovery check:

```powershell
. .\PowerUp.ps1
Get-UnquotedService
```

[Microsoft `CreateProcess` path parsing](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa)
