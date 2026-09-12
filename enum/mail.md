# SMTP, IMAP, and POP3

[← Service index](service-triage.md)

SMTP tells you how mail is accepted; IMAP and POP3 let a valid account read a mailbox. Keep the hostname and user format the server expects.

## SMTP: 25, 465, 587

```bash
nmap -p25,587 --script smtp-commands <target-ip>
smtp-user-enum -M VRFY -U <users-file> -t <target-ip>
openssl s_client -starttls smtp -connect <target-ip>:587 -crlf -quiet
openssl s_client -connect <target-ip>:465 -crlf -quiet
```

Use the STARTTLS form on 25/587 when offered and the implicit TLS form on 465. At the SMTP prompt, `EHLO <domain.tld>` shows advertised extensions. `VRFY <user>` may be disabled or return a generic response. A `530` at `RCPT TO` means authentication is required; it does not establish whether the mailbox exists.

With known credentials, stop after the recipient check so no message is sent:

```bash
swaks --server <target-ip> --auth LOGIN \
  --auth-user '<user@domain.tld>' --auth-password '<password>' \
  --from '<user@domain.tld>' --to '<test@domain.tld>' --quit-after RCPT
```

In the transcript, `<-` is the server's reply. Policies may still hide valid recipients.

## IMAP: 143, 993

Use TLS before sending credentials. For implicit TLS on 993:

```bash
openssl s_client -connect <target-ip>:993 -crlf -quiet
```

Then issue tagged IMAP commands, using message numbers returned by `SEARCH`:

```text
a1 CAPABILITY
a2 LOGIN "<user>" "<password>"
a3 LIST "" "*"
a4 SELECT INBOX
a5 SEARCH ALL
a6 FETCH 1 BODY.PEEK[]
a7 LOGOUT
```

For STARTTLS on 143, connect with `openssl s_client -starttls imap -connect <target-ip>:143 -crlf -quiet` instead.

## POP3: 110, 995

For implicit TLS on 995:

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

`RETR` reads a numbered message; `DELE` changes mailbox state, so leave it out of enumeration. For STARTTLS on 110, use `openssl s_client -starttls pop3 -connect <target-ip>:110 -crlf -quiet`.

References: [IMAP](https://datatracker.ietf.org/doc/html/rfc3501) · [POP3](https://datatracker.ietf.org/doc/html/rfc1939) · [OpenSSL STARTTLS options](https://docs.openssl.org/3.0/man1/openssl-s_client/).
