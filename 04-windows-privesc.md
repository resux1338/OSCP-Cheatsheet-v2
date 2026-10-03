# 04 · Windows Privilege Escalation

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Token/build first; then exact right, writable path, and trigger.

Start with the [Windows low-hanging-fruit enumeration](windows/enumeration.md) page.

```powershell
whoami /all
systeminfo
```

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Token privilege | Is the privilege in this process token, and does the technique have its required service? | [Token rights](windows/token-groups.md) · [Potato](windows/potato.md) |
| Privileged group | Check group scope, active token, exact host/object right, and trigger. | [Local token rights](windows/token-groups.md) · [AD/DC groups](ad/privileged-groups.md) |
| Service binary | Identify the service account, executable path, your file rights, and a restart trigger. | [Binary hijacking](windows/service-binary-hijacking.md) |
| Service configuration | Can your account change `binPath`, and can the service be restarted? | [Service permissions](windows/service-permissions.md) |
| Unquoted service path | Is the path unquoted, space-containing, and a candidate prefix writable? | [Unquoted paths](windows/unquoted-service-paths.md) |
| DLL load | Find the actual missing or writable DLL path and a trigger. | [DLL hijacking](windows/dll-hijacking.md) |
| Task or autorun | Check the actual consumer token, action/dependencies, exact ACL, and trigger. | [Tasks and autoruns](windows/scheduled-tasks-and-autoruns.md) |
| Installer policy | Confirm both machine and current-user policy values. | [Installer policy](windows/services.md#installer-policy) |
| Credential or saved logon | Check stored credentials, targeted config files, history, and allowed logon method. | [Credential checks](windows/credentials.md) |
| Local hash material | Confirm extraction rights; distinguish an NT hash from a challenge-response before trying reuse. | [Credential access](windows/credential-access.md) · [NT hashes](windows/ntlm.md) |
| Tool blocked or missing | Check the file, runtime, and Defender status before changing your approach. | [Tool troubleshooting](windows/enumeration.md#tool-troubleshooting) |

Verify a finding with the host's own ACLs and service state before replacing anything.
