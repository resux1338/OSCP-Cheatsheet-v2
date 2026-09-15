# Windows host baseline

[← Windows quick reference](../04-windows-privesc.md)

Collect token, integrity level, software, processes, network. Admin group ≠ elevated token.

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

Check app directories and history:

```powershell
Get-ChildItem -Path '<APPLICATION-PATH>' -Include *.txt,*.ini -File -Recurse -ErrorAction SilentlyContinue
(Get-PSReadLineOption).HistorySavePath
Get-History
```

Verify tool hits: ACL, service account, task trigger, or credential.

Wider sweep:

```powershell
.\winPEASany.exe
.\PrivescCheck.ps1; Invoke-PrivescCheck
.\Seatbelt.exe -group=all
. .\PowerUp.ps1
Invoke-AllChecks
```

Kernel/local CVE: match exact patch level. `wesng.py` sorts `systeminfo` leads.

Transferred tool fails? Check checksum and local protection status:

```powershell
Get-MpComputerStatus
```
