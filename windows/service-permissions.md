# Service permissions

[← Windows services](services.md)

This path is about rights on the **service object**. `SERVICE_CHANGE_CONFIG` can let you change `binPath` even when the existing binary is not writable. `SERVICE_START` and `SERVICE_STOP` are separate rights; check them before relying on a restart.

```powershell
whoami /groups
sc.exe qc <service-name>
accesschk.exe -accepteula -c -w -v "Authenticated Users" *
accesschk.exe -c -v <your-user-or-group> <service-name>
```

Use your actual user and groups when reading AccessChk output. A broad `Authenticated Users` result is a lead, not proof that a particular service can be changed from your session. Save the full `sc.exe qc` output, especially `BINARY_PATH_NAME`, `SERVICE_START_NAME`, and the start mode.

If you have `SERVICE_CHANGE_CONFIG` and a reachable start trigger, a manual check is:

```powershell
sc.exe config <service-name> binPath= "C:\Path\To\replacement.exe"
sc.exe query <service-name>
sc.exe stop <service-name>
sc.exe start <service-name>
```

The space after `binPath=` is part of `sc.exe` syntax. Stop and start only when your rights and the service state allow it. Restore the exact original `BINARY_PATH_NAME`, including any arguments and embedded quotes, after the test:

```powershell
sc.exe config <service-name> binPath= "<original binary path and arguments>"
sc.exe qc <service-name>
```

The restore line is a template. If the original command line contains spaces or quoted arguments, adapt the shell quoting so the stored path matches the saved value.

[Microsoft service rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights) · [AccessChk syntax](https://learn.microsoft.com/en-us/sysinternals/downloads/accesschk) · [`sc.exe config` syntax](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config)
