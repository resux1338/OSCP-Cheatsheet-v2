# GraphQL checks

[← Foothold quick reference](../02-foothold.md)

Check whether the application exposes a GraphQL endpoint. Introspection may list types and fields, but those fields still need separate authorization checks.

## Schema check
```bash
curl -s http://$IP/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{types{name fields{name}}}}"}'
```

Check `/graphiql` and `/v1/graphql` only if the app suggests those paths. Compare a selected object query as two users to test access control; a visible schema alone is not a data leak.
