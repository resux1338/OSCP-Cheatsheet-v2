# Scheduled tasks and autoruns

[← Windows quick reference](../04-windows-privesc.md) · [Host enumeration](enumeration.md) · [Services and installer policy](services.md)

Need a more-privileged consumer, control over something it actually executes or reads, and a usable trigger. A task name, writable script, or autorun entry alone does not establish escalation. Run these checks on the Windows host in your current shell; record `whoami /all` before testing.

## Identify the exact task and action

```powershell
Get-ScheduledTask | Select-Object TaskPath,TaskName,State

$TaskPath = '\Acme\'
$TaskName = 'Maintenance'
$FullTaskName = $TaskPath + $TaskName
$Task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
$Task.Principal | Format-List UserId,GroupId,RunLevel,LogonType
$Task.Actions | Format-List Execute,Arguments,WorkingDirectory
$Task.Triggers | Format-List *
$Task.Settings | Format-List *
$Task | Get-ScheduledTaskInfo | Format-List LastRunTime,LastTaskResult,NextRunTime
$TaskXml = Export-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
$TaskXml
```

Replace both task variables with an observed task. `TaskPath` includes leading and trailing backslashes; use the full path with `schtasks.exe`. Exported XML exposes fields that abbreviated object output can hide. [Microsoft task export](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/export-scheduledtask?view=windowsserver2025-ps), [run-time information](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/get-scheduledtaskinfo?view=windowsserver2025-ps).

When the ScheduledTasks module is unavailable, use the native commands:

```cmd
schtasks.exe /query /fo LIST /v
schtasks.exe /query /tn "\Acme\Maintenance" /fo LIST /v
schtasks.exe /query /tn "\Acme\Maintenance" /xml
```

An access-denied result means this token could not query that task; it does not mean the task or its referenced file is absent. If broad enumeration fails, query the known task directly. `/xml` requires its complete path. [Microsoft schtasks query](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-query).

| Field | Establish before choosing a path |
| --- | --- |
| Principal and run level | Actual account/SID and resulting token. An administrator principal can run with a filtered token; `HighestAvailable` does not turn an ordinary account into an administrator. |
| Logon type | `InteractiveToken` needs an existing interactive session. `S4U` runs without a stored password and cannot access network resources or encrypted files. Service-account tasks use their named service identity. |
| All actions | Exact executable, arguments, scripts/configs it consumes, and action order. Do not confuse `cmd.exe` or `powershell.exe` with the script named in its arguments. |
| Working directory | Resolve relative files against the task's actual working directory. Your reverse shell's directory and environment are insufficient evidence. |
| Triggers and settings | Schedule, repetition, logon/event conditions, enabled state, demand-start setting, overlapping-instance policy, and other conditions that may prevent execution. |

Run level and task access rights are different checks. Inspect the principal even when the task name suggests SYSTEM. [Microsoft task security contexts](https://learn.microsoft.com/en-us/windows/win32/taskschd/security-contexts-for-running-tasks), [task logon types](https://learn.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_logon_type), [execution action fields and environment handling](https://learn.microsoft.com/en-us/windows/win32/taskschd/execaction).

## Separate the writable file from the registered task

Inspect the executable/script and its parent directories. For an interpreter action, include imported modules, configuration files, and paths derived from arguments.

```powershell
icacls 'C:\Acme\Jobs\maintenance.cmd'
icacls 'C:\Acme\Jobs'
icacls 'C:\Acme'
Get-Acl -LiteralPath 'C:\Acme\Jobs\maintenance.cmd' | Format-List Owner,AccessToString
```

Match allow/deny entries and inheritance to the current token. Permission to write an existing file differs from permission to create a file in its directory or delete/replace a child. A directory ACL does not prove that an existing executable can be overwritten.

For the registered task's security descriptor, the local COM interface works without the ScheduledTasks module:

```powershell
$Scheduler = New-Object -ComObject 'Schedule.Service'
$Scheduler.Connect()
$RegisteredTask = $Scheduler.GetFolder($TaskPath).GetTask($TaskName)
$RegisteredTask.GetSecurityDescriptor(7)  # Owner (1), group (2), DACL (4); no SACL request
```

`Connect()` with no server or credentials uses the local host and current token. Compare the returned SDDL trustees with your token; reading it is not permission to change or run the task. If denied, retain the exact query error and continue checking any known action file. [Microsoft TaskService.Connect](https://learn.microsoft.com/en-us/windows/win32/taskschd/taskservice-connect), [GetSecurityDescriptor](https://learn.microsoft.com/en-us/windows/win32/taskschd/registeredtask-getsecuritydescriptor).

| Confirmed control | What it permits | Still needed |
| --- | --- | --- |
| Action script/file write | Change bytes consumed on a later run without changing task registration | More-privileged consumer and reachable existing trigger |
| Parent-directory control | Possibly create a missing dependency or replace a child, depending on exact rights | Actual lookup/load behavior, file-specific constraints, and trigger |
| Task-definition modification | Update an allowed action through Task Scheduler | Effective task rights, accepted registration context, and a trigger |
| Task execute right | Request an immediate run of the existing definition | Something controlled that this definition consumes |

Windows distinguishes reading, updating, deleting, and running registered tasks. Modify definitions through Task Scheduler's API/cmdlets, not by directly editing files under `C:\Windows\System32\Tasks`. Export XML and capture the task DACL before a definition change; XML does not contain the stored password or replace a DACL backup. Re-registering an exported task can require credentials you do not have. A writable action file is often the simpler confirmed route. [Microsoft task registration and access rules](https://learn.microsoft.com/en-us/windows/win32/taskschd/security-contexts-for-running-tasks).

## Benign proof: an existing writable command script

Example lead: the observed task executes `cmd.exe /c C:\Acme\Jobs\maintenance.cmd` as SYSTEM, and your token can write that existing script. Adapt the paths below to this exact finding. This example prepends identity output to one known `.cmd` script and keeps its original commands afterward. It does not alter the task definition.

Before staging, establish a single run window with no overlapping instance or competing script update. Start from a Ready task; wait for a running/queued task rather than terminating it. Choose an output directory where the task account can create a file and you can read/remove it. The command-script example requires an ASCII-compatible script without a BOM and paths without command-expansion characters such as `%` or `!`; use an encoding-aware approach for other formats. In the COM interface, Ready is state `3` and Running is `4`. [Microsoft task states](https://learn.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_state).

Capture the file, metadata, task configuration, and state first:

```powershell
$ScriptPath = 'C:\Acme\Jobs\maintenance.cmd'
$ProofDirectory = 'C:\Acme\Jobs'  # Confirm both accounts' required rights here.
$ProofPath = Join-Path $ProofDirectory ('task-proof-' + [guid]::NewGuid() + '.txt')
$BackupDirectory = Join-Path $env:TEMP ('task-backup-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $BackupDirectory -ErrorAction Stop | Out-Null

$OriginalTaskXml = $RegisteredTask.Xml
$OriginalTaskSddl = $RegisteredTask.GetSecurityDescriptor(7)
$OriginalTaskState = [int]$RegisteredTask.State
if ($OriginalTaskState -ne 3) { throw 'Task must be Ready; resolve the run window first.' }
[IO.File]::WriteAllText((Join-Path $BackupDirectory 'task.xml'), $OriginalTaskXml, [Text.Encoding]::Unicode)
[IO.File]::WriteAllText((Join-Path $BackupDirectory 'task.sddl'), $OriginalTaskSddl)

$OriginalFile = Get-Item -LiteralPath $ScriptPath -ErrorAction Stop
$OriginalMetadata = [pscustomobject]@{
    Attributes = $OriginalFile.Attributes
    CreationTimeUtc = $OriginalFile.CreationTimeUtc
    LastWriteTimeUtc = $OriginalFile.LastWriteTimeUtc
    LastAccessTimeUtc = $OriginalFile.LastAccessTimeUtc
}
$OriginalFileSddl = (Get-Acl -LiteralPath $ScriptPath -ErrorAction Stop).Sddl
$OriginalHash = (Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256).Hash
$OriginalBytes = [IO.File]::ReadAllBytes($ScriptPath)
[IO.File]::WriteAllBytes((Join-Path $BackupDirectory 'maintenance.cmd.original'), $OriginalBytes)
$OriginalMetadata | Export-Clixml -LiteralPath (Join-Path $BackupDirectory 'file-metadata.xml')
[IO.File]::WriteAllText((Join-Path $BackupDirectory 'file.sddl'), $OriginalFileSddl)
[IO.File]::WriteAllText((Join-Path $BackupDirectory 'file.sha256'), $OriginalHash)
```

Inspect the original script and preserve any configuration it consumes before changing that configuration. This proof changes only the script bytes. Confirm you can restore timestamps/attributes as well as contents; do not change ownership or ACLs just to make the example work.

Stage the proof without converting the original bytes through a text writer:

```powershell
if ($OriginalMetadata.Attributes -band [IO.FileAttributes]::ReadOnly) { throw 'Read-only script; choose another confirmed route.' }
if ($OriginalBytes -contains 0) { throw 'Possible UTF-16/binary content; do not use this command-script example.' }
if ($OriginalBytes.Length -ge 3 -and $OriginalBytes[0] -eq 239 -and $OriginalBytes[1] -eq 187 -and $OriginalBytes[2] -eq 191) {
    throw 'UTF-8 BOM found; use an encoding-aware proof.'
}
if (Test-Path -LiteralPath $ProofPath) { throw 'Proof output already exists.' }
$Prefix = '@"%SystemRoot%\System32\whoami.exe" /all > "' + $ProofPath + '" 2>&1' + "`r`n"
$Prefix += '@"%SystemRoot%\System32\hostname.exe" >> "' + $ProofPath + '" 2>&1' + "`r`n"
$PrefixBytes = [Text.Encoding]::ASCII.GetBytes($Prefix)
[IO.File]::WriteAllBytes($ScriptPath, [byte[]]($PrefixBytes + $OriginalBytes))
```

Record the staging time. If your token has task execute rights and demand start is allowed, request one run:

```powershell
schtasks.exe /run /tn $FullTaskName
```

Otherwise, observe the already-confirmed scheduled/logon/event trigger. Do not change the schedule or enable a disabled task to compensate for missing rights. `schtasks /run` uses the task's registered account and action and leaves its schedule unchanged; its acknowledgment is not proof of completed execution. [Microsoft schtasks run](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-run).

After the relevant run completes, read the newly created output and correlate its timestamp with that run:

```powershell
Get-Item -LiteralPath $ProofPath | Select-Object FullName,CreationTime,LastWriteTime
Get-Content -LiteralPath $ProofPath
$RegisteredTask | Select-Object State,LastRunTime,LastTaskResult
```

Expect the task account and token, such as `NT AUTHORITY\SYSTEM`, plus the correct hostname. Compare with your original shell's identity. Output from an ordinary account confirms execution as that account; it does not establish administrator/SYSTEM access. The unique proof filename helps distinguish this run from stale output.

Restore after the action has exited and before another trigger can consume the modified script. Keep the backup if any check fails:

```powershell
if ([int]$RegisteredTask.State -ne 3) { throw 'Wait for the task and any child action to finish before restoring.' }
[IO.File]::WriteAllBytes($ScriptPath, $OriginalBytes)
if ((Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256).Hash -ne $OriginalHash) { throw 'Script bytes were not restored.' }
if ((Get-Acl -LiteralPath $ScriptPath).Sddl -ne $OriginalFileSddl) { throw 'File ACL/owner changed; reconcile with the saved descriptor.' }
[IO.File]::SetAttributes($ScriptPath, $OriginalMetadata.Attributes)
[IO.File]::SetCreationTimeUtc($ScriptPath, $OriginalMetadata.CreationTimeUtc)
[IO.File]::SetLastWriteTimeUtc($ScriptPath, $OriginalMetadata.LastWriteTimeUtc)
[IO.File]::SetLastAccessTimeUtc($ScriptPath, $OriginalMetadata.LastAccessTimeUtc)
if ($RegisteredTask.Xml -ne $OriginalTaskXml) { throw 'Task definition changed; investigate before cleanup.' }
if ($RegisteredTask.GetSecurityDescriptor(7) -ne $OriginalTaskSddl) { throw 'Task security changed; investigate before cleanup.' }
if ([int]$RegisteredTask.State -ne $OriginalTaskState) { throw 'Task did not return to its original Ready state.' }
Get-Item -LiteralPath $ScriptPath | Format-List Attributes,CreationTimeUtc,LastWriteTimeUtc,LastAccessTimeUtc
Remove-Item -LiteralPath $ProofPath -ErrorAction Stop
```

Compare the displayed metadata with the saved values and keep the identity evidence in your notes. Run history and last-run timestamps will legitimately differ. The byte-oriented restore avoids text encoding/newline changes; metadata restoration can fail when the token lacks attribute-write rights. If you reconnect, recover the saved bytes and metadata from the backup directory instead of relying on lost session variables. Remove that exact backup directory after restoration is verified. [Microsoft WriteAllBytes](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.writeallbytes?view=netframework-4.8.1), [timestamp restoration](https://learn.microsoft.com/en-us/dotnet/api/system.io.file.setlastwritetimeutc?view=netframework-4.8.1).

## Interpret missing output and task results

Re-query the exact task after its last-run time changes. Display its result as a 32-bit hexadecimal value when needed: `'0x{0:X8}' -f ([int64]$RegisteredTask.LastTaskResult -band 4294967295L)`. `0` normally means the action reported success; it does not prove the desired identity or that every command in a script succeeded. A task can also detach a child process, so Ready alone is insufficient for deciding a file is no longer in use.

| Observation | Check next |
| --- | --- |
| No new last-run time | Trigger, enabled state, demand-start permission, logon session, conditions, and overlapping-instance policy |
| `0x00041301` | Task is still running; inspect its action rather than starting more instances |
| `0x00041303` | Task has not yet run; no current execution result to interpret |
| `0x80070002` or `0x80070003` | Executable/dependency path, arguments, working directory, and account access |
| `0x80070005` | Exact operation denied: querying/running the task, starting the action, or accessing its files |
| Fresh run, no proof | Wrong consumed file, encoding/quoting failure, output-directory ACL, or action terminated before the proof |

Other results may be an application exit code rather than a scheduler error. Correlate task name, action start/finish, time, and output. If readable, inspect the existing operational log; an unavailable/disabled log is a visibility gap, not an execution result. [Microsoft scheduler constants](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-error-and-success-constants), [file/path/access error meanings](https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-).

```cmd
wevtutil.exe qe Microsoft-Windows-TaskScheduler/Operational /c:20 /rd:true /f:text
```

This reads the latest events without enabling or clearing the log. [Microsoft wevtutil syntax](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil).

## Autoruns: establish who consumes the entry

Inspect current-user and machine-wide Run/RunOnce values. On a 64-bit host, query both machine registry views; the view selected by your PowerShell process is not necessarily the view used by the consumer.

```cmd
reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce"
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /reg:64
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /reg:64
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /reg:32
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /reg:32
```

Use the relevant view on a 32-bit OS. HKCU refers to your current user's loaded hive; it does not enumerate another user's autoruns. Machine SOFTWARE keys can be redirected, while the ordinary HKCU SOFTWARE branch is shared on modern Windows. Match ACL inspection and any saved value to the observed hive/view. [Microsoft registry-view rules](https://learn.microsoft.com/en-us/windows/win32/winprog64/shared-registry-keys), [reg query view options](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/reg-query).

```powershell
Get-Acl 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' | Format-List Owner,AccessToString
Get-Acl 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' | Format-List Owner,AccessToString
$UserStartup = [Environment]::GetFolderPath('Startup')
$CommonStartup = [Environment]::GetFolderPath('CommonStartup')
Get-ChildItem -LiteralPath $UserStartup,$CommonStartup -Force
icacls $UserStartup
icacls $CommonStartup
```

Default Startup locations are `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` and `%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup`; resolve the configured folders before relying on those defaults. Inspect both a shortcut and its target/script, arguments, and working directory. [Microsoft known Startup folders](https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid).

| Entry | Required consumer/trigger check |
| --- | --- |
| Current-user Run/Startup | Usually executes for that same user's logon; a writable entry is ordinary user execution unless a stronger consumer is demonstrated |
| Machine Run/Common Startup | Logon trigger and actual session token; a machine-wide location does not itself imply SYSTEM or bypass UAC |
| Another user's writable script/shortcut | That user's reachable logon and actual execution privileges; your own logon is not their trigger |
| HKLM RunOnce | Administrator logon after reboot, applicable value semantics, and actual resulting token |

Run values repeat at logon. RunOnce values are normally removed before execution, and Windows may delay startup processing. Preserve value name, type, data, whether it existed, and exact hive/view before a proof; restore only your introduced value/change. Preserve original shortcut/script bytes and metadata as above. Account for a consumed original RunOnce entry instead of blindly recreating it. Verify the resulting identity before calling the path escalation. [Microsoft Run/RunOnce behavior](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys).

For a wider read-only inventory, a trusted local Sysinternals copy can include logon entries and tasks:

```powershell
.\autorunsc.exe -accepteula -a lt -c
```

Review an interesting entry against its exact registry/file ACL, target, consumer, and trigger. Use `-a '*' -c` only when the wider inventory is useful. Signature filtering can hide a signed launcher that consumes a writable script, so establish the whole action chain. [Microsoft Autorunsc options](https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns).

Syntax and behavior references were checked against Microsoft documentation on 2 October 2026. The worked Windows proof still needs execution and restoration validation in an isolated lab; source verification is not a successful host test.
