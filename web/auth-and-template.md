# Web auth, NoSQL, and JWT

[← Foothold quick reference](../02-foothold.md)

## Access control and API input

Change one ID; compare anonymous and two users' read/write results. [GraphQL checks](graphql.md).

### IDOR and mass assignment

With two in-scope accounts, capture one user's request and change only an object ID to the other's. Compare both read and write responses **and** the stored result; a `200` alone is not proof of unauthorized access. Repeat unauthenticated where the endpoint should require a session. For mass assignment, add a sensitive field such as `role` or `ownerId` to a normal update and verify whether the server actually persisted it. Stop if you cannot show a cross-user or privilege boundary was crossed.

## OAuth, OIDC, and SAML flows

Keep each login attempt tied to its own browser session. For OAuth/OIDC, record the authorization request, `redirect_uri`, `state` (and `nonce` where present), then compare the callback with the original request. Test whether missing or mismatched correlation is rejected and whether a changed `redirect_uri` is accepted. An open redirect is relevant to token/code exposure only if an authorization artifact can actually reach the attacker-controlled destination; do not claim theft from a redirect alone.

For SAML, inspect the response's signature, issuer, destination/recipient, audience, timestamps, and `InResponseTo` against the request and service provider. If `RelayState` contains a URL, test its allowlist; a changed `RelayState` by itself does not prove authentication bypass. Prefer a second controlled account or service-provider endpoint to demonstrate a real boundary failure. If you cannot inspect or replay a complete flow, record the observation and move on.

References: [OAuth 2.0 Security BCP](https://datatracker.ietf.org/doc/html/rfc9700) · [OWASP SAML Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SAML_Security_Cheat_Sheet.html).

## NoSQL operators

If input is Mongo-backed, compare literal values with operators:

```text
{"user":{"$ne":null},"pass":{"$ne":null}}
user[$ne]=x&pass[$ne]=x
user[$regex]=^admin
```

## Server-side templates

[SSTI checks and payloads](ssti.md).

## JWT

Decode header/payload; test whether the server accepts a modified token (`alg:none`, weak HMAC secret, or public-key/HMAC confusion).

```bash
hashcat -m 16500 jwt.txt rockyou.txt
```

Check the installed Hashcat mode. For parser clues, see [deserialization](insecure-deserialization.md).
