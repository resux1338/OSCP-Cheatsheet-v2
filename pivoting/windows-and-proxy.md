# Windows pivots and proxy checks

[← Pivoting quick reference](../06-pivoting.md)

## Check reachability from the foothold

Test one known target and port before building a tunnel:

```powershell
Test-NetConnection -ComputerName <internal-ip> -Port 445
Test-NetConnection -ComputerName <internal-ip> -Port 3389
```

## Forward one TCP port

When Windows can SSH back to Kali, Plink can make an internal service available on Kali's loopback address. Verify that Kali's SSH server accepts the connection and that the selected local port is free:

```cmd
plink.exe -ssh -l <kali-user> -pw <password> -R 127.0.0.1:3389:<internal-ip>:3389 <kali-ip>
```

`netsh portproxy` is a different path. It listens on the Windows pivot and forwards to an address the pivot can reach. It needs administrative rights and the IP Helper service:

```cmd
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=3389 connectaddress=<internal-ip> connectport=3389
netsh interface portproxy show all
```

Remove the rule when finished with `netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3389`.

## Proxychains checks

Point Proxychains at the SOCKS listener you actually created, then test one known TCP service. Use a TCP connect scan and skip ping discovery:

```bash
proxychains nmap -sT -Pn -p 445 <internal-ip>
```

If the IP works but the hostname does not, check where DNS resolves. Turn off `proxy_dns` only when you have a working alternative for name resolution. A SOCKS proxy does not carry SYN scans or UDP through Nmap.
