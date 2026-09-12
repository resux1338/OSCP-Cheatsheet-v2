# Hash and login checks

[← Password quick reference](../07-password-attacks.md)

Identify the material before picking a cracking mode. An NT hash can be used for Pass the Hash against an NTLM-capable service. NetNTLMv2 is challenge-response material for offline cracking; it is not a passable NT hash.

```bash
hashid '<hash>'
nth '<hash>'
hashcat -m <mode> hashes.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m <mode> hashes.txt
```

Common Hashcat modes here are `1000` for NTLM, `5600` for NetNTLMv2, `13100` for a Kerberoast TGS, and `18200` for AS-REP material. Verify them with the installed Hashcat before a long run.

## Online logins

Check lockouts before testing a password against many accounts. A form with a per-request CSRF token needs a fresh token and session for each attempt; a stale token can make every password look like a hit. Confirm success using the application's actual redirect, session, or response body rather than one generic status code.

Hydra module syntax varies by version. Check `hydra -U <module>` and adapt field names and failure strings to the application.
