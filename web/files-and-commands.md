# File paths, uploads, and command input

[← Foothold quick reference](../02-foothold.md)

## Traversal and file inclusion

[LFI and path traversal](lfi.md) · [RFI](rfi.md)

## File upload

Find saved path/handler; test `.phtml`, `.php5`, `.pHp`, double extensions. Image magic bytes: prefix with `GIF89a;`. Apache writable `.htaccess`: `AddType application/x-httpd-php .jpg`. Request saved file with a harmless marker; upload success ≠ execution.

## Command injection

Compare a benign command with baseline:

```text
; id
| id
&& id
$(id)
; sleep 5
```

Blind: repeat `sleep 5` against a stable baseline or use a callback. Space filter: try `${IFS}` only in a shell context.
