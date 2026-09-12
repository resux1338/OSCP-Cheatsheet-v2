# Windows services and scheduled tasks

[← Windows quick reference](../04-windows-privesc.md)

For a service finding, check what account runs it, what you can change, and how it starts. These are separate paths:

- [Service binary hijacking](service-binary-hijacking.md): you can write to the executable on disk.
- [Service permissions](service-permissions.md): you can change the service configuration, including `binPath`.
- [Unquoted service paths](unquoted-service-paths.md): you can write to a filename Windows may try before the intended executable.

## Scheduled tasks

```powershell
Get-ScheduledTask | Select-Object TaskName,State,Actions,Principal
schtasks.exe /query /fo LIST /v
```

Record the task's principal, action, trigger, and whether its executable or script is writable. Restore any replaced file after verification.

## Installer policy

`AlwaysInstallElevated` needs both policy values set to `1`. Check both before considering an MSI path:

```powershell
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

If both are `1` and you have a suitable MSI payload, `msiexec /quiet /qn /i <payload>.msi` tests the path. See [payload formats](../foothold/shells.md#msfvenom-payloads).
