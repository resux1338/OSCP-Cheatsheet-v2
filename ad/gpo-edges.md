# Reading GPO edges

[← Active Directory quick reference](../05-active-directory.md)

`GPLink` = GPO applies there. Need edit rights on GPO/SYSVOL + effective scope.

| Edge | Check next |
| --- | --- |
| `GenericWrite` or `GenericAll` on a GPO | Can the principal edit both the AD object and its SYSVOL directory? |
| `WriteDACL` or `WriteOwner` on a GPO | Can the principal obtain the needed edit right without losing the original ACL or owner? |
| `GPLink` to an OU or domain | Is the target computer in scope after link state, inheritance, and filtering? |
| `WriteGPLink` on an OU or domain | Is there also a GPO the principal controls and can link? |

Save GUID, `gPCFileSysPath`, version, extensions, link order, original files. Confirm user vs computer policy target.

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

Test affected account/trigger; restore saved GPO state.

## References

- [Get-GPO](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpo)
- [Get-GPInheritance](https://learn.microsoft.com/en-us/powershell/module/grouppolicy/get-gpinheritance)
