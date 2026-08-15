# ApolloRE v2

ApolloRE is a modular Bash orchestrator for **authorized** domain reconnaissance and security assessment. Version 2 replaces the original monolithic workflow with selectable modules, scoped output, rate controls, and resumable runs.

## Safety and scope

Only run ApolloRE against systems you own or have explicit permission to assess. ApolloRE writes a `scope.txt` for every run and modules constrain host-based processing to the supplied root domain and its subdomains.

## Features

- Modular pipelines: `passive`, `web`, and `full`
- Custom module selection with `--modules`
- `--resume` support
- Configurable `--rate-limit`
- No `/home/user` hard-coded paths
- Structured result directories
- HTTP metadata in JSONL when supported by httpx
- Markdown summary report
- Graceful skipping of optional/missing tools

## Modules

| Module | Purpose | Primary tool |
| --- | --- | --- |
| `subdomains` | Enumerate and scope subdomains | subfinder |
| `dns` | Collect DNS records | dig |
| `http` | Probe live HTTP(S) services and fingerprint them | httpx/httpx-toolkit |
| `ports` | Inventory exposed ports | naabu |
| `crawl` | Crawl scoped web applications | katana |
| `javascript` | Build a JavaScript URL inventory | built-in + optional subjs |
| `nuclei` | Template-based authorized checks | nuclei |
| `screenshots` | Capture visual web inventory | gowitness/aquatone |
| `report` | Generate run summary | built-in |

## Usage

```bash
chmod +x apolloRE.sh
./apolloRE.sh -d example.com --mode passive
./apolloRE.sh -d example.com --mode web --rate-limit 25
./apolloRE.sh -d example.com --mode full --resume
./apolloRE.sh -d example.com --modules subdomains,http,dns,report
```

Run `./apolloRE.sh --help` for all options.

## Output

```text
results/example.com/
├── scope.txt
├── report.md
├── assets/
│   ├── subdomains.txt
│   ├── alive.txt
│   └── dns.txt
├── web/
│   ├── http.jsonl
│   ├── urls.txt
│   └── javascript.txt
├── network/
│   └── ports.txt
├── findings/
│   └── nuclei.jsonl
├── screenshots/
└── logs/
    └── apollore.log
```

## Recommended dependencies

Core tools are installed independently so ApolloRE can skip modules whose dependencies are unavailable:

- subfinder
- httpx or httpx-toolkit
- dnsutils (`dig`)
- naabu
- katana
- nuclei
- gowitness or aquatone
- optional: subjs

The existing `installer.sh` is retained for compatibility and will be modernized separately.

## Design

`apolloRE.sh` is now the orchestrator. Shared functions live under `lib/`, while each reconnaissance stage implements a `run_<module>` function under `modules/`. This makes it easier to add tools without turning the main runner back into a large sequential script.
