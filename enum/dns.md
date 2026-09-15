# DNS records and zone transfers

[← Service index](service-triage.md)

Query the discovered DNS server/domain; retain names for vhosts, Kerberos, mail, TLS.

```bash
dig @<dns-ip> <domain.tld> SOA
dig @<dns-ip> <domain.tld> NS
dig @<dns-ip> <domain.tld> MX
dig @<dns-ip> <domain.tld> TXT
dig @<dns-ip> _ldap._tcp.dc._msdcs.<domain.tld> SRV
dig @<dns-ip> -x <target-ip>
```

Zone transfer against authoritative server; if refused, query record types directly.

```bash
dig @<dns-ip> <domain.tld> AXFR
dnsrecon -d <domain.tld> -n <dns-ip> -t axfr
```

Windows TXT: `nslookup -q=TXT <domain.tld> <dns-ip>`.
