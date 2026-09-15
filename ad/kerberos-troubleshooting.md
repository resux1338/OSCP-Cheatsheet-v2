# Kerberos troubleshooting

[← Active Directory quick reference](../05-active-directory.md)

Use domain FQDN + service FQDN; keep cache tied to its account.

```bash
getent hosts <dc-fqdn>
date -u
klist
echo "$KRB5CCNAME"
```

| Error or symptom | Check |
| --- | --- |
| `KRB_AP_ERR_SKEW` | Compare local and DC time; sync before retrying. |
| `KDC_ERR_WRONG_REALM` | Check the exact domain FQDN and Kerberos realm. |
| No KDC reached | Check DNS, `/etc/hosts`, route, and the DC address. |
| Ticket exists, service fails | Check the service SPN, target FQDN, ticket account, and clock. |
| LDAP bind requires stronger auth | Try a Kerberos-authenticated or sealed LDAP path; see [object rights](object-rights.md). |

Get matching TGT, set `KRB5CCNAME`, then use the tool's cache flags (often `-k -no-pass`).
