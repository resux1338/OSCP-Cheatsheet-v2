# XSS checks

[← Foothold quick reference](../02-foothold.md)

Locate reflection: HTML text, attribute, script, or DOM sink.

```text
< > ' " { } ;
```

Compare raw response and rendered DOM; `&lt;` is text, not execution.

- Stored XSS is saved and shown to later visitors.
- Reflected XSS comes back in the response to a crafted request.
- DOM-based XSS executes through a browser-side source and sink; it can also be stored or reflected.

For SVG upload in a browser-rendered context:

```xml
<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>
```

Verify execution in the actual display context.
