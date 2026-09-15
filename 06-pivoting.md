# 06 · Pivoting & Tunneling

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Check foothold → target reachability; then choose port forward, SOCKS, or subnet route.

| Need | Quick fit check | Details |
| --- | --- | --- |
| One internal TCP service | Can the foothold reach that host and port? Check which end must listen. | [SSH and Socat](pivoting/ssh-socat.md) |
| Several TCP services | Can you run an SSH client or Chisel on the foothold? Test one known port through SOCKS. | [SSH and Socat](pivoting/ssh-socat.md) · [Chisel](pivoting/chisel-ligolo.md) |
| Whole subnet | Can you run a Ligolo agent and route to the subnet without a conflicting route? | [Ligolo](pivoting/chisel-ligolo.md#ligolo-ng) |
| Windows-only foothold | Verify reachability with `Test-NetConnection` and choose a port relay or tunnel. | [Windows pivots](pivoting/windows-and-proxy.md) |
| Callback through a pivot | Check where the listener lives and whether the return port is forwarded. | [Ligolo listener](pivoting/chisel-ligolo.md) · [SSH forwards](pivoting/ssh-socat.md) |
| Scan over SOCKS is empty | Check proxy address, DNS, and a known port; use `nmap -sT -Pn`. | [Proxy checks](pivoting/windows-and-proxy.md) |

Once a new host is reachable, return to [Recon](01-recon.md) through the working route.
