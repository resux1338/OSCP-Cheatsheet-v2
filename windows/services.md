# Windows services and scheduled tasks

[← Windows quick reference](../04-windows-privesc.md)

For each service: account + changeable object/file + trigger.

- [Service binary hijacking](service-binary-hijacking.md): you can write to the executable on disk.
- [Service permissions](service-permissions.md): you can change the service configuration, including `binPath`.
- [Unquoted service paths](unquoted-service-paths.md): you can write to a filename Windows may try before the intended executable.

## Scheduled tasks

```powershell
Get-ScheduledTask | Select-Object TaskName,State,Actions,Principal
schtasks.exe /query /fo LIST /v
```

Task: principal, action, trigger, writable executable/script; restore replaced file.

## Installer policy

`AlwaysInstallElevated`: both policy values must be `1`:

```powershell
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

If both are `1`: `msiexec /quiet /qn /i <payload>.msi` ([payload formats](../foothold/shells.md#msfvenom-payloads)).
