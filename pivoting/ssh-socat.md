# SSH and Socat forwards

[← Pivoting quick reference](../06-pivoting.md)

Use one forward for one service. Verify which host owns the listening socket; it is the host running the SSH client for a local forward.

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

For several internal services, use SOCKS and Proxychains. Nmap must use TCP connect through a SOCKS proxy; SYN scans, UDP, and host-discovery pings do not pass through it.

```bash
ssh -N -D 1080 <user>@<pivot>
proxychains nmap -sT -Pn -p 139,445,3389 <internal-ip>
```

If SSH access and Python are available and you need a routed subnet, `sshuttle -r <user>@<pivot> <internal-subnet>/24` is another option. Check that the chosen subnet does not overlap an existing route.

Set `socks5 127.0.0.1 1080` in Kali's `/etc/proxychains4.conf` for that local SOCKS listener. If the SOCKS listener is on the foothold instead, use its reachable address in the configuration.

Confirm listeners with `ss -lntp` and remove stale tunnels before reusing a port. Bind to `0.0.0.0` only when another host must reach the listener.
