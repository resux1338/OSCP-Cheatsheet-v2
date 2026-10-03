# Service permissions

[← Windows services](services.md)

Need `SERVICE_CHANGE_CONFIG` on service object + usable start trigger. `SERVICE_START` and `SERVICE_STOP` are separate rights.

```powershell
whoami /groups
sc.exe qc <service-name>
accesschk.exe -accepteula -c -w -v "Authenticated Users" *
accesschk.exe -c -v <your-user-or-group> <service-name>
```

Check AccessChk against your token; save `sc.exe qc` output (`BINARY_PATH_NAME`, account, start mode) and `sc.exe query` state. Configuration permission does not grant start/stop permission.

Change configuration only after confirming a usable trigger and a restoration path:

```powershell
sc.exe config <service-name> binPath= "C:\Path\To\replacement.exe"
sc.exe query <service-name>
# Only if running and SERVICE_STOP is confirmed; wait for STOPPED:
sc.exe stop <service-name>
# Only with SERVICE_START or another already-confirmed trigger:
sc.exe start <service-name>
```

Keep the space after `binPath=`. Restore the exact original command line, including arguments. The native example below requires a command line without embedded quotes; for a quoted executable path or quoted arguments, use the structured, backed-up [CIM workflow](../ad/privileged-groups.md#server-operators-exact-service-rights-benign-execution-proof) after confirming its provider permissions and service prerequisites. PowerShell versions differ in how they pass embedded quotes to native programs.

```powershell
sc.exe config <service-name> binPath= "<original binary path and arguments>"
sc.exe qc <service-name>
```

Check stored path after restore; adapt quoting to the exact original. Restore the original running/stopped state as well. A non-service executable can produce its side effect and then fail the SCM dispatcher contract; inspect benign proof output rather than equate every startup error with no execution. See the [identity-proof example](../ad/privileged-groups.md#server-operators-exact-service-rights-benign-execution-proof).

[Microsoft service rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights) · [AccessChk syntax](https://learn.microsoft.com/en-us/sysinternals/downloads/accesschk) · [`sc.exe config` syntax](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config)
