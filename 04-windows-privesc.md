# 04 · Windows Privilege Escalation

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Token/build first; then exact right, writable path, and trigger.

Start with the [Windows low-hanging-fruit enumeration](windows/windows-host-enum.md) page.

```powershell
whoami /all
systeminfo
```

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Token privilege | Is the privilege in this process token, and does the technique have its required service? | [Token rights](windows/token-groups.md) · [Potato](windows/potato.md) |
| Privileged group | Check the group, token state, and the operation that group can perform here. | [Groups and rights](windows/token-groups.md) |
| Service binary | Identify the service account, executable path, your file rights, and a restart trigger. | [Binary hijacking](windows/service-binary-hijacking.md) |
| Service configuration | Can your account change `binPath`, and can the service be restarted? | [Service permissions](windows/service-permissions.md) |
| Unquoted service path | Is the path unquoted, space-containing, and a candidate prefix writable? | [Unquoted paths](windows/unquoted-service-paths.md) |
| DLL load | Find the actual missing or writable DLL path and a trigger. | [DLL hijacking](windows/dll-hijacking.md) |
| Task or installer | Check the run-as account, writable action, trigger, or both installer policy values. | [Tasks and installer](windows/services.md) |
| Credential or saved logon | Check stored credentials, targeted config files, history, and allowed logon method. | [Credential checks](windows/credentials.md) |
| Local hash material | Distinguish an NT hash from a challenge-response before trying reuse. | [NT hashes](windows/ntlm.md) |
| Tool blocked or missing | Check the file, runtime, and Defender status before changing your approach. | [Host baseline](windows/host-enumeration.md) |

[Host enumeration](windows/host-enumeration.md) collects the wider baseline. Verify a finding with the host's own ACLs and service state before replacing anything.
