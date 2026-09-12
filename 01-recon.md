# 01 · Recon & Enumeration

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

> More: [service triage](enum/service-triage.md) · [web enumeration](web/web-enumeration.md)

---

## ENUMERATION

### Nmap (run all targets first thing)
```bash
# Fast full TCP port discovery
nmap -p- --min-rate 5000 -T4 -Pn -oN nmap/allports.txt $IP
# Then deep scan only the open ports
ports=$(awk '$2=="open" {split($1,a,"/"); print a[1]}' nmap/allports.txt | paste -sd,)
nmap -p$ports -sCV -Pn -oN nmap/deep.txt $IP
# UDP top ports (slow - kick off and forget; SNMP/DNS/TFTP/IKE matter)
sudo nmap -sU --top-ports 100 -oN nmap/udp.txt $IP
# Check selected services manually before choosing a vulnerability test.
```
- `-sCV` = default scripts + version. `-Pn` skips host discovery. `--min-rate` keeps it moving.
- **Tuning gotchas:** `-A` already includes `-sC` and `-sV`, so use one approach. An aggressive discovery rate can miss ports on a lossy VPN. If a host looks empty, re-run the sweep at a lower rate before assuming it has no services.
- **AutoRecon** / nmapAutomator fan out per-service checks. Review the configured commands and read the output yourself.
- Always note the **OS hint, hostname, domain name** (add to `/etc/hosts`).

### /etc/hosts: do this for EVERY web/AD box
```bash
echo "$IP corp.example dc01.corp.example target" | sudo tee -a /etc/hosts
```
vhosts/SNI matter; many web apps 302 to a hostname.

### Port → what to check (Ctrl+F the number)

**21 FTP**
```bash
ftp $IP            # try anonymous:anonymous
nmap --script ftp-anon -p21 $IP
# binary mode for non-text; "ls -la" for hidden
```
**22 SSH**: version → searchsploit; key reuse; weak creds (`hydra`); user enumeration on old OpenSSH.
**23 Telnet**: banner, creds.
**25/587 SMTP**
```bash
nmap --script smtp-commands,smtp-enum-users -p25 $IP
# user enum: VRFY <user> / EXPN / RCPT TO
smtp-user-enum -M VRFY -U users.txt -t $IP
# swaks = send mail / deliver client-side payloads (config.Library-ms, attachments):
swaks --to user@example.com --from sender@example.com --server $IP --body "hi" --attach @payload.txt
```
**53 DNS**
```bash
dig axfr corp.example @$IP          # zone transfer
dig any corp.example @$IP
dnsrecon -d corp.example -n $IP -t axfr
```
**79 Finger**: `finger @$IP`; user enum on old boxes.
**88 Kerberos**: it's a DC. → AD section (AS-REP roast, kerberoast).
**110/995 POP3 / 143/993 IMAP**: read mail for creds.
**111 RPCbind / NFS**
```bash
showmount -e $IP                  # list exports
rpcinfo -p $IP
mkdir /mnt/nfs; sudo mount -t nfs $IP:/export /mnt/nfs -o nolock
# no_root_squash export -> privesc later (see Linux PE)
```
**135 / 139 / 445 SMB**
```bash
nxc smb $IP -u '' -p '' --shares                 # null session
nxc smb $IP -u 'guest' -p '' --shares
enum4linux-ng -A $IP
smbclient -L //$IP/ -U '' -N                      # list shares with an empty user
smbclient //$IP/share -U '' -N                    # connect with an empty user
smbmap -H $IP -u null                             # perms per share
nxc smb $IP -u user -p pass --rid-brute           # user enumeration
# Check the exact SMB version and selected issue manually.
```
**161 UDP SNMP**
```bash
snmpwalk -v2c -c public $IP
snmpwalk -v2c -c public $IP NET-SNMP-EXTEND-MIB::nsExtendObjects   # run cmds output
onesixtyone -c community.txt $IP                  # brute community string
# look for: process args (creds!), installed software, user accounts
```
**389/636 LDAP**
```bash
ldapsearch -x -H ldap://$IP -s base namingcontexts
ldapsearch -x -H ldap://$IP -b "DC=corp,DC=example"
nxc ldap $IP -u user -p pass --asreproast hashes.txt
windapsearch / ldapdomaindump for AD
```
**1433 MSSQL**
```bash
impacket-mssqlclient user:pass@$IP -windows-auth
# inspect the SQL role and use a manual T-SQL command only when authorized
# linked servers: EXEC sp_linkedservers ; double-hop via openquery
```
**3306 MySQL**: `mysql -h $IP -u root -p`; UDF privesc; read files (`load_file`, `secure_file_priv`).
**3389 RDP**
```bash
xfreerdp /u:user /p:pass /v:$IP /cert:ignore +clipboard /dynamic-resolution
nxc rdp $IP -u user -p pass
```
> **RDP black screen after authentication?** An MTU/PMTU problem is one possibility. Check the VPN interface and test a smaller MTU before treating it as a credential failure.
**5432 Postgres**: `psql -h $IP -U postgres`; `COPY ... FROM PROGRAM` RCE; read backups.
**5985/5986 WinRM**
```bash
nxc winrm $IP -u user -p pass            # "(Pwn3d!)" = you can evil-winrm
evil-winrm -i $IP -u user -p pass
evil-winrm -i $IP -u user -H <NThash>    # pass-the-hash
```
**6379 Redis**: `redis-cli -h $IP`; webshell write via `config set dir`; SSH key write.

### Web enumeration (80/443/8080/8000/8443…)
```bash
whatweb http://$IP ; curl -sI http://$IP            # tech, headers, server
# directory/file brute
feroxbuster -u http://$IP -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -x php,txt,html,bak,zip
gobuster dir -u http://$IP -w /usr/share/wordlists/dirb/common.txt -x php,txt,html -t 50
ffuf -u http://$IP/FUZZ -w wordlist -e .php,.txt,.bak -mc all -fc 404
# vhost / subdomain fuzz (needs hostname in /etc/hosts)
ffuf -u http://$IP -H "Host: FUZZ.corp.example" -w subdomains.txt -fs <baseline-size>
# CMS
nikto -h http://$IP
wpscan --url http://$IP --enumerate u,vp,vt --api-token <opt>
droopescan scan drupal -u http://$IP
joomscan -u http://$IP
# always: view-source, /robots.txt, /sitemap.xml, comments, JS files (endpoints/creds),
# default creds, /server-status, .git/ (git-dumper), backup files (.bak ~ .swp .old)
```
- **Param fuzzing:** `ffuf -u "http://$IP/page.php?FUZZ=test" -w params.txt -fs <size>` then test each for LFI/SQLi.

---
