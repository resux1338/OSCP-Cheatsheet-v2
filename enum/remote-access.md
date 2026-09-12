# Remote login checks

[← Recon quick reference](../01-recon.md)

Use a discovered credential with the service that is actually open. Keep track of whether the account is local or domain-scoped. A successful login check does not by itself prove command execution.

## SSH

```bash
ssh <user>@<target-ip>
ssh -i <key-file> <user>@<target-ip>
```

Check key permissions, username, and the server's accepted authentication methods if a known credential fails.

## RDP

```bash
nxc rdp <target-ip> -u <user> -p '<password>'
xfreerdp /v:<target-ip> /u:<user> /p:'<password>' /cert:ignore +clipboard /dynamic-resolution
```

If authentication succeeds but the screen stays black, check VPN reachability and MTU before discarding the credential.

## WinRM

```bash
nxc winrm <target-ip> -u <user> -p '<password>'
evil-winrm -i <target-ip> -u <user> -p '<password>'
evil-winrm -i <target-ip> -u <user> -H <nt-hash>
```

An NT hash is useful only for a matching NTLM-capable service. A NetNTLMv2 response is different material; see [hash notes](../passwords/hash-notes.md).
