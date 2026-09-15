# BloodHound collection and path checks

[← Active Directory quick reference](../05-active-directory.md)

Collect for the path question; mark only controlled principals as owned.

```cmd
SharpHound.exe --Domain <domain.tld> --CollectionMethods Default --OutputDirectory C:\Users\<user>\Desktop
```

```bash
bloodhound-ce-python -u <username> -p '<password>' -d <domain.tld> -ns <dc-ip> -c Default --zip
```

NetExec collection (check CE/Legacy output format):

```bash
nxc ldap <dc-ip> -u <user> -p '<password>' --bloodhound -c all --dns-server <dc-ip>
```

Match collector to CE/Legacy. Collection errors can leave missing edges.

## Queries to adapt

Cypher: replace `<DOMAIN>` with the suffix used in object names.

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

Re-collect after gaining a principal. `GPLink` handling: [GPO edges](gpo-edges.md).
