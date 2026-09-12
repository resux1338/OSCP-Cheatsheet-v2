# Kerberos troubleshooting

[← Active Directory quick reference](../05-active-directory.md)

Use the domain's full DNS name and the target service's FQDN. Keep the ticket cache tied to the account that obtained it.

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

For a command that supports Kerberos cache authentication, get a TGT with the matching account and set `KRB5CCNAME` to its cache file. Check the installed tool's options before adding `-k -no-pass`.
