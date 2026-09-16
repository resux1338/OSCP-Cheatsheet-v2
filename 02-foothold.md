# 02 · Foothold: Shells, Web & Exploits

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Pick the row matching the input; compare against a normal request.

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| SQL input | Change one quote or condition and compare errors, rows, or timing. | [Manual SQLi](web/manual-sqli.md) |
| File path or include | Try a known readable file; check whether the app returns file content or evaluates it. | [LFI and traversal](web/lfi.md) |
| Remote URL used as a file | Serve a marker file; confirm a server fetch and whether the returned PHP is interpreted. | [RFI](web/rfi.md) |
| File upload | Find the saved path and test whether the server executes that file type. | [Uploads](web/files-and-commands.md#file-upload) |
| Shell-backed input | Compare a harmless command or short delay with a baseline. | [Command injection](web/files-and-commands.md#command-injection) |
| Template input | Try one arithmetic expression and a second value in the same syntax. | [SSTI](web/ssti.md) |
| Server fetches a URL | Submit a unique callback URL and check your listener. | [SSRF](web/ssrf.md) |
| XML parser | Check whether a controlled entity changes the parsed result. | [XXE](web/xxe.md) |
| Serialized value | Identify the format and the server-side parser before choosing a payload. | [Insecure deserialization](web/insecure-deserialization.md) |
| API or auth boundary | Change one object ID, role, or parameter; compare access as another user. | [Auth and NoSQL](web/auth-and-template.md) · [GraphQL](web/graphql.md) |
| JWT | Decode header and payload; only a server-accepted change proves a weakness. | [JWT](web/auth-and-template.md#jwt) |
| Browser-rendered input | Find the output context and check whether the browser executes it. | [XSS](web/xss.md) |
| Known app or path filter | Check version, plugins, default access, and path normalization. | [Application paths](web/application-paths.md) |
| Public PoC | Match the exact version and read the code before running or compiling it. | [Public exploits](foothold/public-exploits.md) |
| User opens delivered content | Confirm a real delivery path, client action, and reachable callback. | [Client-side attacks and phishing](web/client-side-phishing.md) |

After code execution: `id`/`whoami` → [shell](foothold/shells.md) · [payload](foothold/shells.md#msfvenom-payloads) · [transfer](foothold/file-transfer.md).
