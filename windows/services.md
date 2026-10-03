# Windows services and installer policy

[← Windows quick reference](../04-windows-privesc.md)

For each service: account + changeable object/file + trigger.

- [Service binary hijacking](service-binary-hijacking.md): you can write to the executable on disk.
- [Service permissions](service-permissions.md): you can change the service configuration, including `binPath`.
- [Unquoted service paths](unquoted-service-paths.md): you can write to a filename Windows may try before the intended executable.

## Scheduled tasks

Use [scheduled tasks and autoruns](scheduled-tasks-and-autoruns.md) for action/principal inspection, file versus task permissions, a benign identity proof, run-result diagnosis, and restoration.

## Installer policy

`AlwaysInstallElevated`: both policy values must be `1`:

```powershell
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

If both are `1`: `msiexec /quiet /qn /i <payload>.msi` ([payload formats](../foothold/shells.md#msfvenom-payloads)).
