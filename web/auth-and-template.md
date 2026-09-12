# Web auth and template checks

[← Foothold quick reference](../02-foothold.md)

These inputs need the right parser and context. A payload for one framework is not a universal web test.

## Access control and API input

Change one identifier at a time, request the same endpoint without authentication, and compare which fields each user can read or change. For GraphQL, introspection can expose type and field names when the server leaves it enabled:

```bash
curl -s http://<target>/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{types{name fields{name}}}}"}'
```

Check the returned fields for authorization separately. A visible schema does not itself grant access to the data.

## NoSQL operators

Mongo-backed JSON and URL parameters may accept operators instead of literal strings. Test whether the application treats them as query operators and whether authentication behavior changes.

```text
{"user":{"$ne":null},"pass":{"$ne":null}}
user[$ne]=x&pass[$ne]=x
user[$regex]=^admin
```

## Server-side templates

For a full first-pass workflow, see [SSTI](ssti.md).

An evaluated arithmetic expression is a useful first check. Compare the raw response with the rendered page; `49` alone can occur in ordinary content.

```text
{{7*7}}
${7*7}
<%= 7*7 %>
```

Fingerprint the actual engine before testing an engine-specific path. Check the output and error messages against the engine's syntax.

## JWT

Decode the header and payload offline, then check the algorithm, signature handling, and key source. A token using `alg:none` or a weak HMAC secret is a finding only if the server accepts a changed token. Do not treat a locally modified token as proof of acceptance.

```bash
hashcat -m 16500 jwt.txt rockyou.txt
```

An `alg:none` header or a weak HMAC key matters only if the server accepts the changed token. If an implementation mixes asymmetric and HMAC keys, check whether it incorrectly accepts its public key as an HMAC secret.

Check the installed Hashcat mode list before relying on the example. For parser clues, see [insecure deserialization](insecure-deserialization.md).
