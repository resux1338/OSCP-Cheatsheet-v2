# 01 · Recon & Enumeration

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Full TCP scan → service checks. Record names, ports, and working credentials.

```bash
nmap -Pn -p- -T3 "$IP"
```

[Scan tuning and UDP](enum/network-scanning.md) · [Port-to-service index](enum/service-triage.md)

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Scan looks empty | `ip route get "$IP"`; retry at a lower rate and check selected UDP ports. | [Network scanning](enum/network-scanning.md) |
| Unknown service | Run `nmap -sC -sV` against its open port; check TLS and the banner manually. | [Service triage](enum/service-triage.md) |
| Hostname or virtual host | Compare the IP response with the hostname from a redirect, certificate, or DNS record. | [Web enumeration](web/web-enumeration.md) · [DNS](enum/dns.md) |
| Anonymous files | Try one anonymous or guest login; list readable shares, exports, or directories. | [SMB](enum/smb.md) · [FTP](enum/ftp.md) · [NFS](enum/nfs.md) |
| Information in a service | Check SNMP output, mail capabilities, and unauthenticated RPC for names or paths. | [SNMP](enum/snmp.md) · [Mail](enum/mail.md) · [Other services](enum/other-services.md) |
| Database or cache | Test a discovered account, then inspect its role and accessible data. | [Databases and Redis](enum/databases-and-redis.md) |
| Web app | Read source and JavaScript, map paths, and compare virtual hosts before testing input. | [Web enumeration](web/web-enumeration.md) · [Foothold](02-foothold.md) |
| Remote login | Test a known account against the matching service and account scope. | [RDP and WinRM](enum/remote-access.md) |
| Domain controller | Resolve the full domain name and check LDAP, SMB, and Kerberos. | [AD](05-active-directory.md) |

Repeat service checks with each new credential.
