# Technology and version fingerprinting

[← Recon quick reference](../01-recon.md) · [Web enumeration](web-enumeration.md)

Identify the service first, then fingerprint the **application**, its framework, and any fronting web server separately. Record the hostname, port, scheme, and redirect chain with every observation; the IP's default site may be a different application.

## Identify the service

```bash
nmap -Pn -sV -p <port> <target-ip>
```

A port number is only a hint. Check the detected protocol and banner before using application-specific probes; services can run on unusual ports. For non-HTTP services, continue with [service triage](../enum/service-triage.md). [Nmap service and version detection](https://nmap.org/book/man-version-detection.html)

## Collect web clues

```bash
URL='http://<target>:<port>/'
whatweb -v "$URL"
curl -sS -D headers.txt -o page.html "$URL"
curl -sS -L -D redirects.txt -o /dev/null "$URL"
curl -sS -D - -o /dev/null "${URL}missing-page-12345"
```

For a virtual host, use its name in the URL and route it to the target IP. For HTTPS, this also sends the correct SNI name:

```bash
curl --resolve <host>:443:<ip> -k -sS -D - -o page.html https://<host>/
```

Check the page source and browser DevTools for linked scripts, stylesheets, cookies, **local storage**, redirects, and network requests. Save the actual responses, not only scanner labels. [OWASP web-server fingerprinting](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/01-Information_Gathering/02-Fingerprint_Web_Server/) · [OWASP framework fingerprinting](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/01-Information_Gathering/08-Fingerprint_Web_Application_Framework/) · [WhatWeb](https://github.com/urbanadventurer/WhatWeb#readme)

| Clue | What to check | Limit |
| --- | --- | --- |
| `Server`, `X-Powered-By`, error pages | Web server or framework family | A proxy may supply or rewrite these. |
| Cookie and local-storage names | Framework or CMS client | Names can be customized; stored values can be stale. |
| HTML generator tags and asset paths | CMS, theme, starter kit, or library | A theme/library version is not necessarily the CMS version. |
| Admin/login redirects and route behavior | Application family and configured state | Generic routes rarely prove a release. |
| Static files, manifests, source maps | Version strings or bytes to compare with tagged releases | One file may be identical across many releases. |
| Bundle/cache-buster tokens | Possible version-derived identifier | Find the generating code and all inputs before decoding it. |

## Narrow the version

1. Identify the product from at least two independent clues, such as an admin path and a framework-specific asset.
2. Look for an explicit version in the application's own output. If it is absent, inspect versioned assets and how their URLs are generated.
3. Compare a fetched **static** file with the same file from candidate release tags. List every release that matches; a shared asset gives a range, not an exact version.
4. For a hash or cache-buster, read the product's source for that release family, collect its other inputs, then hash candidate versions. Recheck with a fresh page load so browser storage and bundle URLs come from the same deployment.
5. Record the conclusion and evidence: `product`, `version or range`, `paths/values`, and `confidence`. Verify an apparent exact version with a second signal before selecting version-specific tests.

## Worked example: Umbraco 10

These observations came from one lab site:

```text
/umbraco                              backoffice route
ls.umbVersion                         1e39f354c707a49ed7f69f3926d55eb08f384c01
/sb/umbraco-backoffice-init-css.css.v2c03326042b3360461829471ffe4c8c38a8cc7b9
```

`ls.umbVersion` is a browser **local-storage key**, not an HTTP cookie. Umbraco's client stores its `application.cacheBuster` there. The `/sb/` asset is a Smidge bundle; Umbraco shipped Smidge in versions 9–13. [Client code](https://github.com/umbraco/Umbraco-CMS/blob/release-10.3.2/src/Umbraco.Web.UI.Client/src/app.js#L45-L59) · [Umbraco bundling documentation](https://docs.umbraco.com/umbraco-cms/13.latest/fundamentals/design/stylesheets-javascript) · [Umbraco 14 upgrade note](https://docs.umbraco.com/umbraco-cloud/optimize-and-maintain-your-site/manage-product-upgrades/product-upgrades/major-upgrades)

In Umbraco 10, the stored value is SHA-1 of `<version>.<runtime level>.<Smidge cache buster>`. The URL's `v` is a prefix; leave it off the input. [Server-variable construction](https://github.com/umbraco/Umbraco-CMS/blob/release-10.3.2/src/Umbraco.Web.BackOffice/Controllers/BackOfficeServerVariables.cs#L651-L667) · [Hash implementation](https://github.com/umbraco/Umbraco-CMS/blob/release-10.3.2/src/Umbraco.Core/Extensions/StringExtensions.cs#L602-L623)

```bash
printf '%s' '10.3.2.Run.2c03326042b3360461829471ffe4c8c38a8cc7b9' | sha1sum
# 1e39f354c707a49ed7f69f3926d55eb08f384c01  -
```

That exact match strongly indicates **Umbraco 10.3.2** when both values are current and from the same site. To search candidate releases yourself:

```python
from hashlib import sha1

stored = "1e39f354c707a49ed7f69f3926d55eb08f384c01"
bundle = "2c03326042b3360461829471ffe4c8c38a8cc7b9"

for major in range(9, 14):
    for minor in range(30):
        for patch in range(50):
            version = f"{major}.{minor}.{patch}"
            if sha1(f"{version}.Run.{bundle}".encode()).hexdigest() == stored:
                print(version)  # 10.3.2
```

If there is no match, check whether the browser value is old, the bundle token belongs to another deployment, the runtime level differs, or the site uses a customized build. With backoffice access, the authenticated server variables include `application.version`; the anonymous set omits it. [Umbraco 10 server variables](https://github.com/umbraco/Umbraco-CMS/blob/release-10.3.2/src/Umbraco.Web.BackOffice/Controllers/BackOfficeServerVariables.cs#L224-L229)
