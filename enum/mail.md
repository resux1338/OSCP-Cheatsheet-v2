# SMTP, IMAP, and POP3

[← Service index](service-triage.md)

Record mail hostname and username format. SMTP = sending; IMAP/POP3 = mailbox read.

## SMTP: 25, 465, 587

```bash
nmap -p25,587 --script smtp-commands <target-ip>
smtp-user-enum -M VRFY -U <users-file> -t <target-ip>
openssl s_client -starttls smtp -connect <target-ip>:587 -crlf -quiet
openssl s_client -connect <target-ip>:465 -crlf -quiet
```

SMTP: check whether STARTTLS is advertised on 25/587; 465 commonly uses implicit TLS. `EHLO` lists extensions. A `530` at `RCPT TO` means this transaction needs authentication at that point, but recipient checks may also be possible before authentication.

```text
EHLO <domain.tld>
VRFY <user>
QUIT
```

Known credentials; stop before `DATA`:

```bash
swaks --server <target-ip> --auth LOGIN \
  --auth-user '<user@domain.tld>' --auth-password \
  --protect-prompt --auth-hide-password \
  --from '<user@domain.tld>' --to '<test@domain.tld>' --quit-after RCPT
```

`<-` denotes server reply; recipient policy may be generic. `250` at `RCPT TO` is not proof of a real inbox or delivery. See [client-side/phishing delivery](../web/client-side-phishing.md) for an authenticated send and stop conditions.

## IMAP: 143, 993

IMAPS 993:

```bash
openssl s_client -connect <target-ip>:993 -crlf -quiet
```

IMAP commands (`SEARCH` returns message numbers):

```text
a1 CAPABILITY
a2 LOGIN "<user>" "<password>"
a3 LIST "" "*"
a4 SELECT INBOX
a5 SEARCH ALL
a6 FETCH 1 BODY.PEEK[]
a7 LOGOUT
```

IMAP STARTTLS 143: `openssl s_client -starttls imap -connect <target-ip>:143 -crlf -quiet`.

## POP3: 110, 995

POP3S 995:

```bash
openssl s_client -connect <target-ip>:995 -crlf -quiet
```

```text
USER <user>
PASS <password>
STAT
LIST
RETR 1
QUIT
```

Use `RETR`; avoid state-changing `DELE`. POP3 STARTTLS 110: `openssl s_client -starttls pop3 -connect <target-ip>:110 -crlf -quiet`.

References: [IMAP](https://datatracker.ietf.org/doc/html/rfc3501) · [POP3](https://datatracker.ietf.org/doc/html/rfc1939) · [OpenSSL STARTTLS options](https://docs.openssl.org/3.0/man1/openssl-s_client/).
