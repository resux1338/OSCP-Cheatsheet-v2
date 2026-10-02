# Scripts

[← Repository index](../README.md)

Two helpers are published with this cheatsheet:

| Helper | Purpose | Related notes |
| --- | --- | --- |
| [Find-ExecutableReferences.ps1](Find-ExecutableReferences.ps1) | Finds visible services, scheduled tasks, and processes that reference an executable filename or path. | [DLL hijacking checks](../windows/dll-hijacking.md) |
| [vba_chunks.py](vba_chunks.py) | Splits a UTF-16LE Base64 PowerShell command into VBA string assignments. | [Office VBA delivery](../foothold/client-side-phishing.md#office-vba-document) |

## Find executable references

Run the PowerShell helper from the directory containing the downloaded file:

```powershell
.\Find-ExecutableReferences.ps1 'custom.exe'
.\Find-ExecutableReferences.ps1 'C:\Path\To\custom.exe'
```

It reads services, tasks, and process metadata. It does not execute the named file or change a service or task. Access restrictions can hide results; an empty result does not rule out a reference.

## VBA command chunks

Requires Python 3 and its standard library. From the repository root:

```bash
python3 scripts/vba_chunks.py
python3 scripts/vba_chunks.py '<UTF-16LE-BASE64-COMMAND>'
```

Omit the argument to paste the encoded command when prompted, or pipe it on standard input. The helper validates the encoding and prints `cmd = cmd & "..."` assignments for the VBA example in the linked delivery notes.

Additional tools remain local while awaiting OffSec review.
