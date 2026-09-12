# Application entry points and path filters

[← Foothold quick reference](../02-foothold.md)

## Path normalization

Test path variants only when a proxy, server, or application filter appears to disagree about how it parses the URL. Compare the response with the canonical path and a known missing path.

| Clue | Check |
| --- | --- |
| Tomcat or Spring path filter | Try a `..;/` or `/;/` segment and see whether routing and authorization differ. |
| Nginx `alias` mapping | Compare `/x../` with `/x/` only when the configured alias and location boundaries fit. |
| Filter strips `../` | Compare `%2e%2e%2f`, `..%2f`, `....//`, and double encoding one at a time. |
| Proxy trusts forwarded headers | Check whether `X-Forwarded-For`, `X-Original-URL`, or `X-Rewrite-URL` changes an admin-only response. |

## Known application entry points

| App | Check after identifying it |
| --- | --- |
| WordPress | Plugin versions, readable `wp-config.php`, and whether an admin account has an enabled theme editor. |
| Tomcat | `/manager/html`, credentials actually accepted, and whether WAR deployment is enabled for that account. |
| Jenkins | Whether the account can reach `/script` and run a harmless Groovy expression. |
| Exposed Git | Whether `.git/` is readable and contains source or credentials. |

A default credential or version match is a lead until the target accepts it.
