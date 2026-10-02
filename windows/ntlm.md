# NT hashes and NetNTLMv2

[← Windows quick reference](../04-windows-privesc.md) · [Hash and login checks](../passwords/hash-notes.md)

NT hash: offline crack or Pass the Hash on an NTLM service. NetNTLMv2: crack first; it is not passable.

Use [Windows credential access](credential-access.md) for local SAM, LSA, LSASS, and cached material. For induced network authentication without local admin rights, see [Net-NTLM capture with `ntlm_theft`](ntlm-capture.md).

```bash
hashcat -m 1000 nt.txt /usr/share/wordlists/rockyou.txt
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
```

Record the material type, account scope, and source before choosing a reuse or cracking method.
