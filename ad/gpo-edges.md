# Reading GPO edges

[← Active Directory quick reference](../05-active-directory.md)

BloodHound's `GPLink` edge says where a GPO applies. It does not grant a right to edit that GPO. Check control of the GPO, its SYSVOL files, and its effective scope before planning a change.

| Edge | Check next |
| --- | --- |
| `GenericWrite` or `GenericAll` on a GPO | Can the principal edit both the AD object and its SYSVOL directory? |
| `WriteDACL` or `WriteOwner` on a GPO | Can the principal obtain the needed edit right without losing the original ACL or owner? |
| `GPLink` to an OU or domain | Is the target computer in scope after link state, inheritance, and filtering? |
| `WriteGPLink` on an OU or domain | Is there also a GPO the principal controls and can link? |

Record the GPO GUID, `gPCFileSysPath`, `versionNumber`, machine extensions, link order, and original files before changing anything. A computer-side task and a user-side task run under different accounts; confirm which object receives the policy.

## Inspect and back up

```powershell
Import-Module GroupPolicy
Get-GPO -Guid '<gpo-guid>' -Domain '<domain.tld>' -Server '<dc-fqdn>' |
    Format-List DisplayName,Id,GpoStatus,Owner,ComputerVersion,UserVersion,WmiFilter
```

```powershell
Get-GPOReport -Guid '<gpo-guid>' -ReportType Xml -Path '.\gpo-before.xml' -Domain '<domain.tld>' -Server '<dc-fqdn>'
New-Item -ItemType Directory -Path '.\gpo-backup' -Force | Out-Null
Backup-GPO -Guid '<gpo-guid>' -Path '.\gpo-backup' -Domain '<domain.tld>' -Server '<dc-fqdn>'
```

```powershell
Get-GPInheritance -Target '<OU-or-domain-DN>' -Domain '<domain.tld>' -Server '<dc-fqdn>' |
    Format-List GpoInheritanceBlocked,GpoLinks,InheritedGpoLinks
```

Check the affected account and trigger on a test policy before changing a live GPO. Restore the saved state after the test.

## References

- [Get-GPO](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpo)
- [Get-GPInheritance](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpinheritance)
