# Hash and login checks

[← Password quick reference](../07-password-attacks.md)

NT hash → crack or Pass the Hash on NTLM. NetNTLMv2 → crack; not passable.

```bash
hashid '<hash>'
nth '<hash>'
hashcat -m <mode> hashes.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m <mode> hashes.txt
```

Hashcat: `1000` NTLM; `5600` NetNTLMv2; `13100` TGS; `18200` AS-REP. Verify local modes.

## Online logins

Online: check lockout; baseline success/failure; refresh per-request CSRF token/session.

Hydra: `hydra -U <module>`; set actual fields/failure string.
