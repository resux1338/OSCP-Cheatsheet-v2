# Scripts

Read-only enumeration helpers. [Find-ExecutableReferences.ps1](Find-ExecutableReferences.ps1) searches visible services, tasks, and processes for an executable name or path.

## LFI enumeration

[`lfi-enum`](lfi-enum) tries a short file list at depths 0–6 and saves every curl response. Put `FUZZ` where the file path belongs; inspect `results.tsv` and the `.body` files. [LFI notes](../web/lfi.md).

```bash
./scripts/lfi-enum -u 'http://<target>/index.php?page=FUZZ'
./scripts/lfi-enum -u 'http://<target>/index.php?page=FUZZ' -w ./paths.txt -d 8 -b ./cookies.txt
```

## Kickoff recon

[`kickoff`](kickoff): full TCP connect scan → version/safe scripts → service-specific NXC, WhatWeb, and web checks. Output streams to screen and dated `kickoff-results/` directory.

```bash
./scripts/kickoff 10.10.10.5
./scripts/kickoff dc01.lab.local -f targets.txt --username alice --domain lab.local --password 'example-password'
./scripts/kickoff targets.txt --creds-file ./creds.conf --udp-top-ports 100
./scripts/kickoff targets.txt --password-file ./logins.txt --domain lab.local
./scripts/kickoff 10.10.10.5 --proxychains --proxychains-config ./proxychains.conf
./scripts/kickoff 10.10.10.5 --domain lab.local --udp-top-ports 100 --extras
./scripts/kickoff 10.10.10.5 --web-pages
```

Targets: IPs/hostnames separated by whitespace or commas; `#` comments. Credentials file:

```text
username=alice
domain=lab.local
password=example-password
```

`--creds-file` supplies one key/value credential set. `--password-file` tries multiple logins, one per line; blank lines and `#` comments are ignored. The first colon is the separator, so additional colons remain part of the password:

```text
bob:Password1!
alice:a-password:with-colons
```

Use `--domain` with a password list when needed. Direct `--password` appears in history/process listings. Raw NXC logs can contain credentials.

Resume/rerun:

```bash
./scripts/kickoff --resume kickoff-results/20260912-120000
./scripts/kickoff --resume kickoff-results/20260912-120000 --rerun nxc --creds-file ./new-creds.conf
./scripts/kickoff --resume kickoff-results/20260912-120000 172.16.20.10
```

`--rerun nmap|nxc|whatweb|web|extras`; use `--rerun nxc` after changing a password. Skip stages with `--skip-nxc`, `--skip-whatweb`, `--skip-ad-followup`, `--skip-web-followup`.

Supplying one host with `--resume` scans that host and adds it to the run. Register a known host without trying to reach it, then add scan results later when a pivot is available:

```bash
./scripts/kickoff --resume kickoff-results/20260912-120000 --add-host 172.16.20.12
./scripts/kickoff --resume kickoff-results/20260912-120000 172.16.20.12 --proxychains
```

Reports:

```bash
./scripts/kickoff --report-only kickoff-results/20260912-120000
./scripts/kickoff --serve
```

Open the printed `http://127.0.0.1:8765/` URL. The scan manager lists every run under `kickoff-results/`, starts new scans, resumes runs, and shows live scan activity, including `kickoff` scans started in another terminal under the same results root. Use `--serve -o another-results-dir` to manage another results root.

Open a run to add hosts one at a time and mark machines pwned. Optional machine name, subnet, and pivot/source fields retain hosts learned from internal networks even when they cannot be scanned. If a lab reboot moves an entire network, use **Lab subnet changed?** with equal-sized CIDRs such as `192.168.141.0/24` and `192.168.107.0/24`. This preserves host numbers while updating scan targets, inventory hosts, subnet/pivot metadata, and saved scan folders. Resume the run afterward to refresh results from the new addresses.

Server detail panels below the searchable table start collapsed; use each server heading or the expand/collapse-all buttons. Each panel has **Server** and **Notes** tabs. Notes entered in the browser are stored per host in `inventory.json` and included safely in the generated report. A directly opened `report.html` remains a view-only snapshot. Per-host `summary.md` contains raw NXC output/log paths and may contain credentials. `hosts.suggested` contains the discovered hosts-file line.

Web: headers by default; `--web-pages` also fetches `/`, `/robots.txt`, `/sitemap.xml`; `--web-max-names N` changes hostname cap. `--extras` adds DNS, RPC/NFS, SNMP checks where ports match.

Proxy: `--proxychains --proxychains-config <file>` wraps TCP tools. Use IPs when proxy DNS is unavailable. UDP scanning is rejected in proxy mode; full TCP scan may be slow.
