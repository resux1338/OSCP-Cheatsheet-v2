# DNS records and zone transfers

[← Service index](service-triage.md)

Use the discovered DNS server and domain. Record hostnames before testing virtual hosts, Kerberos, mail, or TLS names.

```bash
dig @<dns-ip> <domain.tld> SOA
dig @<dns-ip> <domain.tld> NS
dig @<dns-ip> <domain.tld> MX
dig @<dns-ip> <domain.tld> TXT
dig @<dns-ip> _ldap._tcp.dc._msdcs.<domain.tld> SRV
dig @<dns-ip> -x <target-ip>
```

Try a zone transfer against an in-scope authoritative server. A refused transfer is normal; use the records you can query individually.

```bash
dig @<dns-ip> <domain.tld> AXFR
dnsrecon -d <domain.tld> -n <dns-ip> -t axfr
```

On Windows, `nslookup -q=TXT <domain.tld> <dns-ip>` checks the same record type.
