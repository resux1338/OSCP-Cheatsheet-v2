# 05 · Active Directory

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Start with the domain name, DC address, and credential you control. Keep the account, right, target object, and reachable service together for each path.

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| First domain picture | Can the account list users, groups, shares, hosts, and policy? | [LDAP and sessions](ad/ldap-and-sessions.md) · [BloodHound](ad/bloodhound.md) |
| Roastable account | Is pre-auth disabled or is a user-backed SPN present? Check lockout before online tests. | [Authentication](ad/authentication.md) |
| Useful object right | Identify the principal, exact ACL right, target, and original state. | [Object rights](ad/object-rights.md) · [SPNs and ACLs](ad/spn-acl-shares.md) |
| Share or SYSVOL lead | Can you read credentials or write content a privileged process actually loads? | [Shares and SPNs](ad/spn-acl-shares.md) |
| Session or admin edge | Does the account have local admin rights where a useful session or service exists? | [Sessions](ad/ldap-and-sessions.md#hosts-and-sessions) · [Lateral movement](ad/lateral-movement.md) |
| GPO edge | Check the exact GPO right, linked scope, and affected host or user. | [GPOs](ad/gpo-edges.md) |
| AD CS | Is an enrollment service present, and can this account enroll in a relevant template? | [AD CS](ad/adcs.md) |
| Local admin or SYSTEM | Can you read local secrets or a DC database through a confirmed right? | [Credential access](ad/credential-access.md) |
| Ticket material | Match the key or ticket to its account, SPN, service, and domain. | [Tickets](ad/tickets.md) |
| Kerberos fails | Check FQDN, DNS, clock skew, SPN, and the ticket cache. | [Kerberos checks](ad/kerberos-troubleshooting.md) |
| Login but no execution | Check local admin rights and whether the matching remote service is open. | [Lateral movement](ad/lateral-movement.md) |
| Advanced object path | Check prerequisite rights and DC support before changing an object. | [Advanced object paths](ad/object-rights.md#sealed-ldap-object-restore--newer-primitives) |

After each new credential or host, repeat the first domain picture with that account's access. A BloodHound path is a lead until its rights and target are confirmed.
