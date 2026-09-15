# GraphQL checks

[← Foothold quick reference](../02-foothold.md)

Check the GraphQL endpoint and introspection:

## Schema check
```bash
curl -s http://$IP/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{__schema{types{name fields{name}}}}"}'
```

Query the same object as two users; schema visibility is not data access. Try `/graphiql` or `/v1/graphql` only when suggested by the app.
