# XSS checks

[← Foothold quick reference](../02-foothold.md)

Find input that returns in a browser-rendered page. Start by checking where the value lands: HTML text, an attribute, a script block, or a DOM sink. The payload has to fit that context.

```text
< > ' " { } ;
```

Try one character at a time and compare the response source with what the browser renders. HTML encoding may display `<` safely as `&lt;`; URL encoding changes how the request carries a value. A reflected character alone does not prove script execution.

- Stored XSS is saved and shown to later visitors.
- Reflected XSS comes back in the response to a crafted request.
- DOM-based XSS executes through a browser-side source and sink; it can also be stored or reflected.

For an SVG upload, test whether the browser renders it as active SVG in the actual display context:

```xml
<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>
```

An accepted upload or a direct file response is not proof that another user's browser will execute it.
