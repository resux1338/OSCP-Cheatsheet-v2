# SNMP

[← Service index](service-triage.md)

Check UDP 161 and the community string before walking large trees. SNMPv1/v2c community strings act like cleartext passwords; SNMPv3 needs its own user and security settings.

```bash
onesixtyone -c <community-file> <target-ip>
snmpget -v2c -c public <target-ip> 1.3.6.1.2.1.1.1.0
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.1
```

Walk the subtree that answers your question. These examples cover running programs, installed software, Windows user accounts, and local TCP ports:

```bash
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.25.4.2.1.2
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.25.6.3.1.2
snmpwalk -v2c -c public <target-ip> 1.3.6.1.4.1.77.1.2.25
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.6.13.1.3
```

On a Net-SNMP host, extended command output can expose local paths or process results:

```bash
snmpwalk -v2c -c public <target-ip> NET-SNMP-EXTEND-MIB::nsExtendObjects
```

If the symbolic MIB name does not resolve, check the installed MIB files; it does not mean the remote tree is empty. Record the OID with any useful result. A timeout can mean filtered UDP, a wrong community, or an unsupported SNMP version.

Reference: [Net-SNMP `snmpwalk`](https://www.net-snmp.org/docs/man/snmpwalk.html).
