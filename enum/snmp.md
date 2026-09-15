# SNMP

[← Service index](service-triage.md)

Confirm UDP/161 + community before large walks. v1/v2c community is plaintext; v3 uses user/security settings.

```bash
onesixtyone -c <community-file> <target-ip>
snmpget -v2c -c public <target-ip> 1.3.6.1.2.1.1.1.0
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.1
```

Targeted OIDs: processes, software, Windows users, TCP ports:

```bash
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.25.4.2.1.2
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.25.6.3.1.2
snmpwalk -v2c -c public <target-ip> 1.3.6.1.4.1.77.1.2.25
snmpwalk -v2c -c public <target-ip> 1.3.6.1.2.1.6.13.1.3
```

Net-SNMP extended commands:

```bash
snmpwalk -v2c -c public <target-ip> NET-SNMP-EXTEND-MIB::nsExtendObjects
```

Unknown MIB name: use numeric OID/check local MIBs. Timeout: filtering, wrong community, or wrong version.

Reference: [Net-SNMP `snmpwalk`](https://www.net-snmp.org/docs/man/snmpwalk.html).
