# Windows host enumeration

[← index](../README.md) · [Windows privilege escalation](../04-windows-privesc.md)

Catch the low-hanging fruit before choosing a privilege-escalation path. Record the current identity, token, host build, architecture, local listeners, privileged processes, writable target, and trigger.

## First pass

```powershell
whoami
whoami /all
hostname
systeminfo
ipconfig /all
route print
netstat -ano
```

An Administrators-group SID in the token does not necessarily mean the current process is elevated. Record the integrity level and whether important privileges are enabled.

```powershell
$PSVersionTable
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption,Version,BuildNumber,OSArchitecture,LastBootUpTime
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20
Get-MpComputerStatus
```

Missing cmdlets are normal on older hosts. Fall back to `systeminfo`, `wmic`, or the matching `cmd.exe` command rather than assuming the information is unavailable.

## Users, groups, and sessions

```cmd
net user
net localgroup
net localgroup Administrators
qwinsta
query user
cmdkey /list
```

```powershell
Get-LocalUser
Get-LocalGroup
Get-LocalGroupMember -Group '<LOCAL-ADMIN-GROUP>'
Get-CimInstance Win32_LoggedOnUser
```

Use the localized administrator-group name when the host is not English. Check each unusual group or token privilege in [privileged groups and token rights](token-groups.md).

## Processes, software, and local services

```powershell
Get-Process
tasklist /svc
Get-NetTCPConnection -State Listen | Sort-Object LocalPort
Get-CimInstance Win32_Service |
    Select-Object Name,State,StartMode,StartName,PathName
```

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object DisplayName |
    Select-Object DisplayName,DisplayVersion,Publisher,InstallLocation
```

Compare a local-only listener with its owning process and account. Forward only the service you intend to inspect; see [pivoting and tunneling](../06-pivoting.md).

## Services and file permissions

An unusual service is only a lead. Record its account, exact executable and arguments, file ACL, service ACL, current state, and a legitimate start or restart trigger.

```powershell
Get-CimInstance Win32_Service |
    Where-Object { $_.PathName -and $_.PathName -notmatch '^"?C:\\Windows\\' } |
    Select-Object Name,State,StartName,PathName

sc.exe qc <SERVICE>
sc.exe sdshow <SERVICE>
icacls '<EXECUTABLE-OR-DIRECTORY-PATH>'
Get-Acl '<EXECUTABLE-OR-DIRECTORY-PATH>' | Format-List
```

An unquoted path needs spaces and a writable candidate prefix. A writable binary still needs a more-privileged service account and a trigger. Follow the matching [service binary](service-binary-hijacking.md), [service permission](service-permissions.md), or [unquoted path](unquoted-service-paths.md) checks.

## Scheduled tasks, autoruns, and installer policy

```powershell
schtasks /query /fo LIST /v
Get-ScheduledTask | Select-Object TaskPath,TaskName,State,Principal,Actions
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run*',
                 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run*' -ErrorAction SilentlyContinue
```

For an interesting task or autorun, inspect the referenced file and parent-directory ACLs. Record the run-as account and trigger.

```cmd
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```

Both installer-policy values must be enabled before this is a valid lead. See [services and scheduled tasks](services.md).

## Targeted credential checks

Start with known application locations and user-controlled history instead of searching the entire drive.

```powershell
(Get-PSReadLineOption).HistorySavePath
Get-History
cmdkey /list

reg query 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v DefaultUserName
reg query 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v DefaultPassword

$SearchRoots = @($env:USERPROFILE, 'C:\inetpub\wwwroot', '<APPLICATION-PATH>')
Get-ChildItem -Path $SearchRoots -Include *.txt,*.ini,*.xml,*.config,*.ps1,*.bat,*.cmd `
    -File -Recurse -ErrorAction SilentlyContinue |
    Select-String -Pattern 'pass(word)?|secret|token|connectionstring|api.?key'

Get-ChildItem 'C:\Windows\Panther','C:\Windows\System32\Sysprep' `
    -Include *unattend*.xml,*sysprep*.xml -File -Recurse -ErrorAction SilentlyContinue
```

Treat a found value as a candidate until it authenticates to a specific account and service. Continue with [Windows credential checks](credentials.md).

## PowerUp: enumeration only

Use a trusted local copy and inspect its version. Dot-source it, then run only audit and discovery functions.

```powershell
. .\PowerUp.ps1
Invoke-PrivescAudit
# Alias for the same audit in the PowerSploit version:
Invoke-AllChecks

Get-ProcessTokenPrivilege -Special
Get-UnquotedService
Get-ModifiableServiceFile
Get-ModifiableService
Find-PathDLLHijack
Get-RegistryAlwaysInstallElevated
Get-RegistryAutoLogon
Get-ModifiableRegistryAutoRun
Get-ModifiableScheduledTaskFile
Get-UnattendedInstallFile
Get-WebConfig
Get-ApplicationHost
Get-SiteListPassword
Get-CachedGPPPassword
```

`Invoke-AllChecks` reports findings and may print the name of a suggested abuse function; it does not execute that function. Do not run PowerUp's modifying functions from this enumeration sheet. Verify each result with `sc.exe`, `icacls`, `Get-Acl`, registry queries, and task details.

## Wider automated sweep

Automated output is a lead list, not proof. Use current copies, save the output, and manually confirm the exact right and trigger.

```powershell
.\winPEASany.exe
. .\PrivescCheck.ps1; Invoke-PrivescCheck
.\Seatbelt.exe -group=all
```

Map the exact Windows build only after the misconfiguration checks. Kernel or local CVE matching is a later step because patch detection and exploit applicability can be wrong.

## Triage the findings

| Signal | Confirm next | Deeper notes |
| --- | --- | --- |
| Interesting token privilege | Present and enabled in this process; required service or resource exists | [Token rights](token-groups.md) · [Potato checks](potato.md) |
| Writable service executable | Service account, exact ACL, and restart trigger | [Service binary hijacking](service-binary-hijacking.md) |
| Modifiable service configuration | Exact service right and start/stop ability | [Service permissions](service-permissions.md) |
| Unquoted service path | Candidate prefix exists and is writable | [Unquoted paths](unquoted-service-paths.md) |
| Writable task, autorun, or DLL path | Privileged consumer and reproducible trigger | [Tasks](services.md) · [DLL checks](dll-hijacking.md) |
| Saved credential or config secret | Account scope and accepted logon method | [Credential checks](credentials.md) |
| Local-only service | Owning process, version, authentication, and forwarding route | [Pivoting](../06-pivoting.md) |

## References

- [OffSec: Understanding Penetration Testing Tools](https://www.offsec.com/blog/understanding-penetration-testing-tools/)
- [FuzzySecurity: Windows Privilege Escalation Fundamentals](https://fuzzysecurity.com/tutorials/16.html)
- [0xNeel: OSCP privilege-escalation enumeration checklist](https://0xneel.medium.com/privilege-escalation-enumeration-checklist-2d995e9ddfe7)
- [FalconSpy: OSCP methodology](https://falconspy.medium.com/oscp-developing-a-methodology-32f4ab471fd6)
- [PowerSploit PowerUp reference](https://powersploit.readthedocs.io/en/stable/Privesc/README/)
- [PowerUp source](https://github.com/PowerShellMafia/PowerSploit/blob/master/Privesc/PowerUp.ps1)
- [PEASS-ng winPEAS](https://github.com/peass-ng/PEASS-ng/tree/master/winPEAS)

## Where is the flag?

Check the user desktops first. If the expected flag is missing, search `C:\`; a full recursive search can take time and will return only paths visible to the current token.

```powershell
Get-ChildItem 'C:\Users\*\Desktop\local.txt','C:\Users\*\Desktop\proof.txt' `
    -Force -ErrorAction SilentlyContinue | Select-Object FullName

Get-ChildItem -Path C:\ -Include local.txt,proof.txt -File -Recurse -Force `
    -ErrorAction SilentlyContinue | Select-Object FullName
```

```cmd
where /r C:\ local.txt 2>nul
where /r C:\ proof.txt 2>nul
type "<FLAG-PATH>"
```

`local.txt` normally belongs to the user-level context; `proof.txt` normally requires the elevated context. Record the hostname and full path with the value.
