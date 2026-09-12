# Network scanning

[← Recon quick reference](../01-recon.md)

## TCP and UDP scans

Create `nmap/` before using these output paths. Raise the scan rate only if the connection is reliable.

```bash
# Fast full TCP port discovery
mkdir -p nmap
nmap -p- -T3 -Pn -oN nmap/allports.txt "$IP"
# Then deep scan only the open ports
ports=$(awk '$2=="open" {split($1,a,"/"); print a[1]}' nmap/allports.txt | paste -sd,)
nmap -p$ports -sCV -Pn -oN nmap/deep.txt $IP
# Selected UDP services when TCP leaves a gap
sudo nmap -sU --top-ports 100 -oN nmap/udp.txt "$IP"
# Check selected services manually before choosing a vulnerability test.
```
- `-sCV` = default scripts + version. `-Pn` skips host discovery.
- **Tuning gotchas:** `-A` already includes `-sC` and `-sV`, so use one approach. An aggressive discovery rate can miss ports on a lossy VPN. If a host looks empty, re-run the sweep at a lower rate before assuming it has no services.
- **AutoRecon** / nmapAutomator fan out per-service checks. Review the configured commands and read the output yourself.
- Always note the **OS hint, hostname, domain name** (add to `/etc/hosts`).

## Hostnames and virtual hosts
```bash
echo "$IP corp.example dc01.corp.example target" | sudo tee -a /etc/hosts
```
Use the hostname from DNS, a redirect, or a TLS certificate. Virtual hosts and SNI can serve a different site than the bare IP.
