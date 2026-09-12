# XML external entity checks

[← Foothold quick reference](../02-foothold.md)

Use this only when an application parses XML you control. Compare a normal document and an entity reference, then confirm the response came from the server-side parser.

## Entity check
```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
```

If no file content appears, a listener can help distinguish a blind external fetch from a parser that ignored the entity. The parser may block external entities entirely.
