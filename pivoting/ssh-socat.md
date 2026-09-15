# SSH and Socat forwards

[← Pivoting quick reference](../06-pivoting.md)

SSH local forward listens on the SSH-client host.

```bash
# Kali opens a local port to a service reachable from the SSH server
ssh -N -L 8000:127.0.0.1:8000 <user>@<target>

# Run on the foothold: Kali listens on 127.0.0.1:2345 and forwards to the internal service
ssh -N -R 127.0.0.1:2345:<internal-ip>:5432 <user>@<kali-ip>
```

```bash
# A single TCP relay on a foothold
socat -ddd TCP-LISTEN:2345,fork TCP:<internal-ip>:5432
```

SOCKS: Proxychains + Nmap `-sT -Pn`; no SYN/UDP/ping through SOCKS.

```bash
ssh -N -D 1080 <user>@<pivot>
proxychains nmap -sT -Pn -p 139,445,3389 <internal-ip>
```

Routed subnet: `sshuttle -r <user>@<pivot> <internal-subnet>/24`; avoid route overlap.

Set `socks5 127.0.0.1 1080` in `/etc/proxychains4.conf` (or use actual reachable SOCKS address).

Check `ss -lntp`; bind `0.0.0.0` only for remote access.
