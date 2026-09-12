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

For an SVG upload case, see the example in the [foothold quick reference](../02-foothold.md#client-side--auth-flow). Check whether the browser executes it in the actual display context.
