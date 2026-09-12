# Windows host baseline

[← Windows quick reference](../04-windows-privesc.md)

Record the current identity, token, integrity level, software, processes, and network before choosing a privilege path. Membership in Administrators does not mean the current process is elevated.

```powershell
whoami /all
whoami /groups
whoami /priv
systeminfo
ipconfig /all
route print
netstat -ano
```

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | Select-Object DisplayName
Get-Process
Get-LocalUser
net localgroup
```

Check targeted application directories and history before searching the entire disk:

```powershell
Get-ChildItem -Path '<APPLICATION-PATH>' -Include *.txt,*.ini -File -Recurse -ErrorAction SilentlyContinue
(Get-PSReadLineOption).HistorySavePath
Get-History
```

An enumeration script is a lead generator. Verify the file ACL, service context, task trigger, or credential against the host before using it.

For a wider local sweep, use the tool you have staged, then verify its findings manually:

```powershell
.\winPEASany.exe
.\PrivescCheck.ps1; Invoke-PrivescCheck
.\Seatbelt.exe -group=all
. .\PowerUp.ps1
Invoke-AllChecks
```

If the host build suggests a local issue, compare the exact patch level with a trusted advisory before using an exploit. `wesng.py` can sort candidates from saved `systeminfo` output.

If a transferred tool fails to run, confirm that the file arrived intact and check the local protection status before blaming the exploit path:

```powershell
Get-MpComputerStatus
```
