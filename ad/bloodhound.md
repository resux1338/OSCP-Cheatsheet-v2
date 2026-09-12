# BloodHound collection and path checks

[← Active Directory quick reference](../05-active-directory.md)

Collect enough data to answer a path question, then read the edges. Broad collection can be noisy. Mark only principals you actually control as owned.

```cmd
SharpHound.exe --Domain <domain.tld> --CollectionMethods Default --OutputDirectory C:\Users\<user>\Desktop
```

```bash
bloodhound-ce-python -u <username> -p '<password>' -d <domain.tld> -ns <dc-ip> -c Default --zip
```

NetExec can also collect with a known account: `nxc ldap <dc-ip> -u <user> -p '<password>' --bloodhound -c all --dns-server <dc-ip>`. Check which BloodHound format your installed collector produces.

Use a collector that matches BloodHound CE or Legacy. Upload the resulting ZIP to the matching platform. Collection failures can leave edges missing; an empty path is not proof that none exists.

## Queries to adapt

In BloodHound's Cypher view, replace `<DOMAIN>` with the domain suffix used in object names. Built-in saved queries are a useful starting point.

```cypher
MATCH p=(n:User)-[:MemberOf*1..]->(m:Group)
WHERE m.name = "DOMAIN ADMINS@<DOMAIN>"
RETURN p
```

```cypher
MATCH p=(m:User)-[:MemberOf*1..]->(n:Group)
WHERE n.name = "DOMAIN ADMINS@<DOMAIN>"
MATCH q=(m)<-[:HasSession]-(o:Computer)
RETURN p, q
```

Re-collect after gaining a new principal if its access changes what the collector can see. For GPO paths, read [GPO edges](gpo-edges.md) before interpreting a `GPLink` as a right.
