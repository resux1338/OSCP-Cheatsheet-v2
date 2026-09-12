# Offline cracking and wordlists

[← Passwords quick reference](../07-password-attacks.md)

## Identify the hash
```bash
hashid '<hash>' ; hash-identifier ; nth '<hash>'      # name-that-hash
# NT hash from a known/cracked password (for PtH / ticketer / -k workflows):
python3 -c 'import hashlib;print(hashlib.new("md4","PASSWORD".encode("utf-16le")).hexdigest())'
# (NT hash == "the NTLM hash"; NetNTLMv2 is a crackable challenge-response, NOT passable: see AD file)
```

## hashcat
```bash
hashcat -m <mode> hashes.txt /usr/share/wordlists/rockyou.txt
hashcat -m <mode> hashes.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule
# Common modes:
#  0 MD5 | 100 SHA1 | 1400 SHA256 | 1800 sha512crypt($6$) | 500 md5crypt($1$)
#  3200 bcrypt | 1000 NTLM | 5600 NetNTLMv2 | 13100 Kerberoast TGS | 18200 AS-REP
#  22921 KeePass | 13400 KeePass(kdbx) | 13000 RAR5 | 17200/13600 ZIP | 1700 SHA512
hashcat -m 1000 nt.txt rockyou.txt          # NTLM
hashcat -m 13100 kerb.txt rockyou.txt       # kerberoast
hashcat --show -m <mode> hashes.txt         # display cracked
```

## john
```bash
john --wordlist=rockyou.txt hashes.txt
john --show hashes.txt
# format conversions (the *2john tools):
ssh2john id_rsa > h ; keepass2john f.kdbx > h ; zip2john f.zip > h
office2john doc.docx > h ; pdf2john f.pdf > h ; gpg2john ...
john --wordlist=rockyou.txt h
```

## Crack /etc/shadow
```bash
unshadow /etc/passwd /etc/shadow > combined
john --wordlist=rockyou.txt combined        # or hashcat -m 1800 for $6$
```

## Wordlist mangling
```bash
# from website
cewl http://$IP -w words.txt -d 3 -m 5
# variations
hashcat --stdout words.txt -r rules/best64.rule | sort -u > big.txt
# username lists from names
./username-anarchy Firstname Lastname
```
