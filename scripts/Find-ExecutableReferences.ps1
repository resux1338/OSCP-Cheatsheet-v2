<#
.SYNOPSIS
Finds visible services, scheduled tasks, and processes that reference an executable.

.DESCRIPTION
Read-only enumeration for a filename or full path. Service enumeration tries CIM,
then sc.exe, then the service registry. Scheduled-task enumeration tries
Get-ScheduledTask, then schtasks.exe and readable task files.

This script does not replace files, start or stop services, run tasks, or execute
the target executable. Empty results are not proof that no privileged trigger exists.

.PARAMETER Target
Executable filename or path to search for.

.EXAMPLE
.\Find-ExecutableReferences.ps1 'custom.exe'

.EXAMPLE
.\Find-ExecutableReferences.ps1 'C:\Path\To\custom.exe'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Target
)

function New-TargetPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Values
    )

    $escapedValues = @(
        $Values |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique |
            ForEach-Object { [regex]::Escape($_) }
    )

    return '(?:' + ($escapedValues -join '|') + ')'
}

function Get-ScField {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [string]$Field
    )

    $fieldPattern = '^\s*' + [regex]::Escape($Field) + '\s*:\s*(.+)$'
    foreach ($line in $Lines) {
        if ($line -match $fieldPattern) {
            return $Matches[1].Trim()
        }
    }

    return $null
}

function Get-ServiceMatchesFromSc {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $scPath = Join-Path $env:SystemRoot 'System32\sc.exe'
    $queryOutput = @(& $scPath query state= all bufsize= 100000 2>&1)
    $queryExitCode = $LASTEXITCODE

    if ($queryExitCode -ne 0) {
        throw "sc.exe query failed with exit code $queryExitCode."
    }

    $serviceNames = @(
        $queryOutput |
            ForEach-Object {
                if ($_ -match '^\s*SERVICE_NAME:\s*(.+)$') {
                    $Matches[1].Trim()
                }
            }
    )

    if ($serviceNames.Count -eq 0) {
        throw 'sc.exe returned no parseable SERVICE_NAME fields. Output may be localized.'
    }

    foreach ($serviceName in $serviceNames) {
        $qcOutput = @(& $scPath qc $serviceName 2>&1)
        $qcExitCode = $LASTEXITCODE
        if ($qcExitCode -ne 0) {
            continue
        }

        $qcText = $qcOutput -join "`n"
        if ($qcText -notmatch $Pattern) {
            continue
        }

        $stateOutput = @(& $scPath query $serviceName 2>&1)

        [pscustomobject]@{
            Source    = 'sc.exe'
            Name      = $serviceName
            StartName = Get-ScField -Lines $qcOutput -Field 'SERVICE_START_NAME'
            State     = Get-ScField -Lines $stateOutput -Field 'STATE'
            StartMode = Get-ScField -Lines $qcOutput -Field 'START_TYPE'
            PathName  = Get-ScField -Lines $qcOutput -Field 'BINARY_PATH_NAME'
        }
    }
}

function Get-ServiceMatchesFromRegistry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $servicesKey = 'HKLM:\SYSTEM\CurrentControlSet\Services'
    $serviceKeys = @(Get-ChildItem -Path $servicesKey -ErrorAction Stop)

    foreach ($serviceKey in $serviceKeys) {
        $properties = Get-ItemProperty -LiteralPath $serviceKey.PSPath -ErrorAction SilentlyContinue
        if ($null -eq $properties) {
            continue
        }

        $imagePathProperty = $properties.PSObject.Properties['ImagePath']
        if ($null -eq $imagePathProperty -or [string]::IsNullOrWhiteSpace([string]$imagePathProperty.Value)) {
            continue
        }

        if ([string]$imagePathProperty.Value -notmatch $Pattern) {
            continue
        }

        $objectNameProperty = $properties.PSObject.Properties['ObjectName']
        $startProperty = $properties.PSObject.Properties['Start']
        $startName = '(not recorded)'
        $startMode = '(not recorded)'
        if ($objectNameProperty) {
            $startName = [string]$objectNameProperty.Value
        }
        if ($startProperty) {
            $startMode = [string]$startProperty.Value
        }

        [pscustomobject]@{
            Source    = 'Registry'
            Name      = $serviceKey.PSChildName
            StartName = $startName
            State     = '(not available from registry)'
            StartMode = $startMode
            PathName  = [string]$imagePathProperty.Value
        }
    }
}

function Get-TaskMatchesFromCmdlet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $tasks = @(Get-ScheduledTask -ErrorAction Stop)
    foreach ($task in $tasks) {
        $actionText = @(
            $task.Actions |
                ForEach-Object {
                    ('{0} {1} {2}' -f $_.Execute, $_.Arguments, $_.WorkingDirectory).Trim()
                }
        ) -join ' | '

        if ($actionText -notmatch $Pattern) {
            continue
        }

        [pscustomobject]@{
            Source   = 'Get-ScheduledTask'
            TaskName = $task.TaskName
            TaskPath = $task.TaskPath
            RunAs    = $task.Principal.UserId
            State    = $task.State
            Action   = $actionText
        }
    }
}

function Get-TaskMatchesFromSchtasks {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $schtasksPath = Join-Path $env:SystemRoot 'System32\schtasks.exe'
    $queryOutput = @(& $schtasksPath /query /fo LIST /v 2>&1)
    $queryExitCode = $LASTEXITCODE

    if ($queryExitCode -ne 0) {
        throw "schtasks.exe query failed with exit code $queryExitCode."
    }

    $queryText = $queryOutput -join "`r`n"
    $blocks = [regex]::Split($queryText, '(?:\r?\n){2,}')

    foreach ($block in $blocks) {
        if ($block -match $Pattern) {
            [pscustomobject]@{
                Source   = 'schtasks.exe'
                TaskName = '(matched task block)'
                TaskPath = '(see Action)'
                RunAs    = '(see Action)'
                State    = '(see Action)'
                Action   = $block.Trim()
            }
        }
    }
}

function Get-TaskMatchesFromFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $taskRoot = Join-Path $env:SystemRoot 'System32\Tasks'
    if (-not (Test-Path -LiteralPath $taskRoot)) {
        return
    }

    $taskFiles = @(Get-ChildItem -LiteralPath $taskRoot -Recurse -Force -File -ErrorAction SilentlyContinue)
    foreach ($taskFile in $taskFiles) {
        $match = Select-String -LiteralPath $taskFile.FullName -Pattern $Pattern -List -ErrorAction SilentlyContinue
        if ($null -eq $match) {
            continue
        }

        [pscustomobject]@{
            Source   = 'Task file'
            TaskName = $taskFile.Name
            TaskPath = $taskFile.FullName.Substring($taskRoot.Length)
            RunAs    = '(inspect readable task XML)'
            State    = '(not available from task file)'
            Action   = $match.Line.Trim()
        }
    }
}

$resolvedPath = $null
try {
    $resolvedPath = (Resolve-Path -LiteralPath $Target -ErrorAction Stop).Path
}
catch {
    # A bare filename or a path that does not exist can still appear in a launcher definition.
}

$leafName = [System.IO.Path]::GetFileName($Target)
if ([string]::IsNullOrWhiteSpace($leafName)) {
    throw 'Target must be an executable filename or path, not a directory.'
}

$targetDirectory = [System.IO.Path]::GetDirectoryName($Target)
$filenameOnly = [string]::IsNullOrWhiteSpace($targetDirectory)
if ($filenameOnly) {
    $searchValues = @($leafName)
}
else {
    $searchValues = @($Target)
    if (-not [string]::IsNullOrWhiteSpace($resolvedPath)) {
        $searchValues += $resolvedPath
    }
}
$targetPattern = New-TargetPattern -Values $searchValues
$processName = [System.IO.Path]::GetFileNameWithoutExtension($leafName)

Write-Host "[*] Target: $Target"
if ($resolvedPath) {
    Write-Host "[*] Resolved path: $resolvedPath"
}
else {
    Write-Warning 'The target did not resolve to a local file. Searching launcher definitions by the supplied text and filename.'
}

if ($filenameOnly) {
    Write-Warning 'Filename-only matching can return unrelated executables with the same name. Re-run with the full path when possible.'
}

Write-Host "`n=== File and directory permissions ==="
if ($resolvedPath) {
    $icaclsPath = Join-Path $env:SystemRoot 'System32\icacls.exe'
    & $icaclsPath $resolvedPath
    & $icaclsPath (Split-Path -Parent $resolvedPath)
}
else {
    Write-Host 'Skipped: target file was not found at the supplied path.'
}

Write-Host "`n=== Services ==="
$serviceResults = @()
$serviceMethod = 'CIM'
try {
    $serviceResults = @(
        Get-CimInstance -ClassName Win32_Service -ErrorAction Stop |
            Where-Object { $_.PathName -and $_.PathName -match $targetPattern } |
            ForEach-Object {
                [pscustomobject]@{
                    Source    = 'CIM'
                    Name      = $_.Name
                    StartName = $_.StartName
                    State     = $_.State
                    StartMode = $_.StartMode
                    PathName  = $_.PathName
                }
            }
    )
}
catch {
    Write-Warning "CIM service enumeration failed: $($_.Exception.Message)"
    $serviceMethod = 'sc.exe'
    try {
        $serviceResults = @(Get-ServiceMatchesFromSc -Pattern $targetPattern)
    }
    catch {
        Write-Warning "sc.exe service enumeration could not be parsed: $($_.Exception.Message)"
        Write-Warning 'Falling back to readable service registry keys. State is unavailable and StartMode is the numeric registry value.'
        $serviceMethod = 'Registry'
        try {
            $serviceResults = @(Get-ServiceMatchesFromRegistry -Pattern $targetPattern)
        }
        catch {
            Write-Warning "Registry service enumeration failed: $($_.Exception.Message)"
            $serviceMethod = 'None'
        }
    }
}

Write-Host "[*] Service source used: $serviceMethod"
if ($serviceResults.Count -gt 0) {
    $serviceResults | Format-List Source, Name, StartName, State, StartMode, PathName
}
else {
    Write-Host 'No matching service was visible through the available source.'
}

Write-Host "`n=== Scheduled tasks ==="
$taskResults = @()
$taskMethod = 'Get-ScheduledTask'
try {
    $taskResults = @(Get-TaskMatchesFromCmdlet -Pattern $targetPattern)
}
catch {
    Write-Warning "Get-ScheduledTask failed: $($_.Exception.Message)"
    $taskMethod = 'schtasks.exe + readable task files'

    try {
        $taskResults += @(Get-TaskMatchesFromSchtasks -Pattern $targetPattern)
    }
    catch {
        Write-Warning "schtasks.exe enumeration failed: $($_.Exception.Message)"
    }

    try {
        $taskResults += @(Get-TaskMatchesFromFiles -Pattern $targetPattern)
    }
    catch {
        Write-Warning "Readable task-file enumeration failed: $($_.Exception.Message)"
    }
}

Write-Host "[*] Task source used: $taskMethod"
if ($taskResults.Count -gt 0) {
    $taskResults | Format-List Source, TaskName, TaskPath, RunAs, State, Action
}
else {
    Write-Host 'No matching scheduled task was visible through the available source.'
}

Write-Host "`n=== Running processes ==="
$processResults = @(
    Get-Process -ErrorAction SilentlyContinue |
        ForEach-Object {
            $processPath = $null
            try {
                $processPath = $_.Path
            }
            catch {
                # Some process paths are hidden from a low-privilege token.
            }

            if (($processPath -and $processPath -match $targetPattern) -or
                ($filenameOnly -and -not [string]::IsNullOrWhiteSpace($processName) -and $_.ProcessName -eq $processName)) {
                [pscustomobject]@{
                    Id          = $_.Id
                    ProcessName = $_.ProcessName
                    Path        = $processPath
                }
            }
        }
)

if ($processResults.Count -gt 0) {
    $processResults | Format-Table -AutoSize
}
else {
    Write-Host 'No matching running process was visible.'
}

Write-Host "`n[!] Empty results do not prove that no privileged trigger exists. Access controls, hidden process paths, localized sc.exe output, and unreadable task files can cause false negatives."
