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

Credential options: `--creds-file`, `--password-file`, or password prompt. Direct `--password` appears in history/process list. Raw NXC logs can contain credentials.

Resume/rerun:

```bash
./scripts/kickoff --resume kickoff-results/20260912-120000
./scripts/kickoff --resume kickoff-results/20260912-120000 --rerun nxc --creds-file ./new-creds.conf
```

`--rerun nmap|nxc|whatweb|web|extras`; use `--rerun nxc` after changing a password. Skip stages with `--skip-nxc`, `--skip-whatweb`, `--skip-ad-followup`, `--skip-web-followup`.

Reports:

```bash
kickoff --report-only kickoff-results/20260912-120000
```

Open `report.html`; per-host `summary.md` contains raw NXC output/log paths and may contain credentials. `hosts.suggested` contains the discovered hosts-file line.

Web: headers by default; `--web-pages` also fetches `/`, `/robots.txt`, `/sitemap.xml`; `--web-max-names N` changes hostname cap. `--extras` adds DNS, RPC/NFS, SNMP checks where ports match.

Proxy: `--proxychains --proxychains-config <file>` wraps TCP tools. Use IPs when proxy DNS is unavailable. UDP scanning is rejected in proxy mode; full TCP scan may be slow.
