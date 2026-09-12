# Server-side request forgery (SSRF)

[← Foothold quick reference](../02-foothold.md)

Look for a feature that fetches a URL on the server's behalf: image import, link preview, webhook test, PDF generation, or a file converter. First find out whether the **server** makes the request. A URL merely reflected in the page is not evidence of SSRF.

## Confirm the fetch

On your machine, listen for a request. Use an address the target can reach:

```bash
python3 -m http.server 8000
```

In another terminal, submit a unique path through the suspected URL parameter:

```bash
curl -G 'http://<target>/fetch' \
  --data-urlencode 'url=http://<kali-ip>:8000/ssrf-check-01'
```

Check the listener log for that path and compare it with a baseline request. Some features fetch later or return no fetched body; a callback can confirm a blind fetch. No callback does not settle the question if the target cannot reach your listener.

## Check what it can reach

After confirming the fetch, try a known HTTP service on the target's loopback address and compare the status, body, and timing with an unused port:

```bash
curl -G 'http://<target>/fetch' \
  --data-urlencode 'url=http://127.0.0.1:8080/'
```

Here `127.0.0.1` means the **target server**, not your machine. Test one port or URL change at a time. If a host filter blocks the obvious form, check how the application parses the URL; for example, the host in `http://allowed.example@127.0.0.1:8080/` is `127.0.0.1`. Short loopback forms such as `127.1`, redirects, and DNS resolution are parser-dependent, so verify the resulting request with a callback or visible response.

Record the requested URL, what the server fetched, and whether the response was returned to you. Internal pages and metadata services are possible targets, but reachability alone does not show access to their contents.

[OWASP SSRF testing](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/07-Injection/19-Server-Side_Request_Forgery/)
