# ApolloRE v2

ApolloRE is a modular Bash orchestrator for **authorized** domain reconnaissance and security assessment. Version 2 replaces the original monolithic workflow with selectable modules, scoped output, rate controls, resumable runs, and local configuration support.

## Safety and scope

Only run ApolloRE against systems you own or have explicit permission to assess. ApolloRE writes a `scope.txt` for every run and modules constrain host-based processing to the supplied root domain and its subdomains.

## Features

- Modular pipelines: `passive`, `web`, and `full`
- Custom module selection with `--modules`
- `--resume` support
- Configurable `--rate-limit`
- Local config/API-key loading with a strict allow-list
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

## Installation

ApolloRE's installer targets Debian-family systems such as Kali, Debian, and Ubuntu. It does not run a full OS upgrade.

```bash
chmod +x installer.sh apolloRE.sh
./installer.sh --core
```

Install optional screenshot/browser tooling too:

```bash
./installer.sh --all
```

Check dependencies without changing the machine:

```bash
./installer.sh --check
```

The current ProjectDiscovery toolchain requires a recent Go release. The installer checks the installed version before attempting Go-based installs.

## Configuration and API keys

Create a private config directory and copy the template:

```bash
mkdir -p ~/.config/apollore
cp config/apollo.env.example ~/.config/apollore/config.env
chmod 600 ~/.config/apollore/config.env
```

ApolloRE reads `~/.config/apollore/config.env` by default. You can select another file with:

```bash
./apolloRE.sh -d example.com --config /absolute/path/apollo.env
```

Supported configuration keys are:

```text
APOLLO_OUTPUT_BASE
APOLLO_RATE_LIMIT
APOLLO_USER_AGENT
NUCLEI_SEVERITIES
SUBFINDER_PROVIDER_CONFIG
SHODAN_API_KEY
WPSCAN_API_TOKEN
GITHUB_TOKEN
```

The config parser does **not** source or execute the file. It accepts only the keys above and treats values literally. Real config files and `.env` files are ignored by Git so API keys are not accidentally committed.

For Subfinder, prefer its provider configuration file and set `SUBFINDER_PROVIDER_CONFIG` to that file's absolute path. `SHODAN_API_KEY`, `WPSCAN_API_TOKEN`, and `GITHUB_TOKEN` are exported for modules that consume those services without printing the secret values to the ApolloRE log.

Environment variables can also be used instead of storing secrets in the config file.

## Usage

```bash
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

Core:

- subfinder
- httpx
- dnsutils (`dig`)
- naabu
- katana
- nuclei

Optional:

- gowitness or aquatone
- Chromium/Chrome for gowitness
- subjs

## Design

`apolloRE.sh` is the orchestrator. Shared functions live under `lib/`, while each reconnaissance stage implements a `run_<module>` function under `modules/`. This keeps tool-specific logic out of the main runner and makes future modules easier to add.
