# Remote login checks

[← Recon quick reference](../01-recon.md)

Match local/domain credential to open service; login success ≠ command execution.

## SSH

```bash
ssh <user>@<target-ip>
ssh -i <key-file> <user>@<target-ip>
```

SSH failure: check key mode, username, and accepted auth methods.

## RDP

```bash
nxc rdp <target-ip> -u <user> -p '<password>'
xfreerdp /v:<target-ip> /u:<user> /p:'<password>' /cert:ignore +clipboard /dynamic-resolution
```

RDP auth + black screen: check VPN route/MTU.

## WinRM

```bash
nxc winrm <target-ip> -u <user> -p '<password>'
evil-winrm -i <target-ip> -u <user> -p '<password>'
evil-winrm -i <target-ip> -u <user> -H <nt-hash>
```

NT hash needs NTLM service; NetNTLMv2 differs: [hash notes](../passwords/hash-notes.md).
