# Service triage

[← Recon quick reference](../01-recon.md)

Map each open port to a focused check; retain names, versions, and credential used.

For a repeatable product and version check, use the [fingerprinting workflow](../web/fingerprinting.md).

| Port | Topic | First check |
| --- | --- | --- |
| 21 | [FTP](ftp.md) | Anonymous access and readable files |
| 22, 23, 79 | [SSH, Telnet, Finger](other-services.md) | Host key, banner, or user information |
| 25, 465, 587 | [SMTP](mail.md#smtp-25-465-587) | EHLO capabilities and recipient policy |
| 53 | [DNS](dns.md) | Records and zone transfer |
| 69/UDP, 873 | [TFTP and rsync](other-services.md) | Known file or listed rsync module |
| 80, 443, 8080 | [Web](../web/web-enumeration.md) | Hostname, headers, paths, and source |
| 110, 995, 143, 993 | [POP3 and IMAP](mail.md) | Authenticated mailbox listing |
| 111, 2049 | [NFS](nfs.md) | RPC services, exports, and read-only mount |
| 135, 139, 445 | [SMB and RPC](smb.md) | Null/guest share access and signing |
| 161/UDP | [SNMP](snmp.md) | Community and targeted OIDs |
| 389, 636 | [LDAP](../ad/ldap-and-sessions.md) | Naming context and accessible objects |
| 1433, 3306, 5432, 6379 | [Databases and Redis](databases-and-redis.md) | Login, current role, and accessible data |
| 3389, 5985, 5986 | [Windows remote access](remote-access.md) | RDP/WinRM login and account rights |

Windows reachability: `Test-NetConnection -ComputerName <target-ip> -Port 445`.

Lossy VPN/empty host: rescan slower. Check local tool help for flags.
