# NT hashes and NetNTLMv2

[← Windows quick reference](../04-windows-privesc.md) · [Hash and login checks](../passwords/hash-notes.md)

NT hash: offline crack or Pass the Hash on a compatible NTLM service. A NetNTLMv2 response is suitable for offline cracking; [relay](../ad/ntlm-relay.md) instead requires a fresh live exchange.

Use [Windows credential access](credential-access.md) for local SAM, LSA, LSASS, and cached material. For induced network authentication without local admin rights, see [Net-NTLM capture with `ntlm_theft`](ntlm-capture.md).

```bash
hashcat -m 1000 nt.txt /usr/share/wordlists/rockyou.txt
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
```

Record the material type, account scope, and source before choosing a reuse or cracking method.

| Material | Meaning / next action |
| --- | --- |
| NT hash | Account key; match local/domain scope and service authentication policy |
| NetNTLMv2 response | Challenge-bound response; crack it offline, not Pass the Hash |
| DCC/DCC2 cached domain verifier | Offline password-verification material; not a reusable NT key |
| AES Kerberos key | Account key of a specific encryption type; use supported Kerberos authentication |
| TGT / service ticket | Time-limited ticket for a specific principal/realm/service; inspect the cache in [ticket notes](../ad/tickets.md) |

Cached domain verifiers and LSA secrets are separate outputs from offline SECURITY/SYSTEM analysis. [Impacket secretsdump implementation](https://github.com/fortra/impacket/blob/master/examples/secretsdump.py).
