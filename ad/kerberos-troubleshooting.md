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
| LDAP bind requires stronger auth | Establish signing/SASL requirements and tool support; LDAPS has separate TLS/channel-binding checks. |
| `KDC_ERR_ETYPE_NOSUPP` | Account-supported encryption, available key type, DC defaults/patch state; NT and AES keys are different material. |
| `KDC_ERR_BADOPTION` during S4U | [Delegation direction](delegation.md), allowed SPN, evidence ticket, and target-user restrictions. |
| `KDC_ERR_PADATA_TYPE_NOSUPP` with a certificate | DC PKINIT support/certificate configuration; Schannel is a separately qualified [AD CS path](adcs.md#pkinit-and-schannel-failures). |
| Certificate SID/identity mismatch | Requested/issued identity, strong mapping, template/CA configuration, and the exact target object. |

Get matching TGT, set `KRB5CCNAME`, then use the tool's cache flags (often `-k -no-pass`).
