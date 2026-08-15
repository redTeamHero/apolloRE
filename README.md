# ApolloRE v2

ApolloRE is a modular Bash orchestrator for **authorized** domain reconnaissance and security assessment. Version 2 replaces the original monolithic workflow with selectable modules, scoped output, rate controls, resumable runs, local configuration support, passive enrichment, target prioritization, normalized asset inventory, and run-to-run change detection.

## Safety and scope

Only run ApolloRE against systems you own or have explicit permission to assess. ApolloRE writes a `scope.txt` for every run and modules constrain host-based processing to the supplied root domain and its subdomains.

Cloud and takeover modules are intentionally non-destructive: they produce candidate lists from already-collected DNS/URL data and do not claim resources, enumerate private objects, or attempt exploitation.

## Features

- Modular pipelines: `passive`, `web`, and `full`
- Custom module selection with `--modules`
- `--resume` support
- Configurable `--rate-limit`
- Local config/API-key loading with a strict allow-list
- Passive Shodan enrichment
- Historical URL collection via gau/waybackurls
- Cloud-storage candidate extraction
- Passive takeover-candidate identification from CNAME records
- Interesting-target prioritization
- Normalized `assets.jsonl` inventory across recon modules
- Automatic baseline and added/removed change detection
- No `/home/user` hard-coded paths
- Structured result directories
- HTTP metadata in JSONL when supported by httpx
- Markdown run and change reports
- Graceful skipping of optional/missing tools

## Modules

| Module | Purpose | Primary tool |
| --- | --- | --- |
| `subdomains` | Enumerate and scope subdomains | subfinder |
| `dns` | Collect DNS records | dig |
| `http` | Probe live HTTP(S) services and fingerprint them | httpx/httpx-toolkit |
| `shodan` | Enrich scoped assets from Shodan | shodan CLI + API key |
| `ports` | Inventory exposed ports | naabu |
| `crawl` | Crawl scoped web applications | katana |
| `history` | Collect scoped historical URLs | gau / waybackurls |
| `javascript` | Build a JavaScript URL inventory | built-in + optional subjs |
| `cloud` | Extract cloud-storage endpoint candidates | built-in |
| `takeover` | Flag provider-linked CNAMEs for manual review | built-in |
| `nuclei` | Template-based authorized checks | nuclei |
| `screenshots` | Capture visual web inventory | gowitness/aquatone |
| `prioritize` | Score interesting hosts/URLs for analyst review | built-in |
| `normalize` | Merge recon outputs into a normalized JSONL inventory | jq |
| `diff` | Compare inventory with the previous baseline | jq + comm |
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

The installer also installs `gau`, `waybackurls`, and the Shodan CLI for enrichment modules. Current ProjectDiscovery releases require a recent Go version, so the installer validates Go before building those tools.

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

For Subfinder, prefer its provider configuration file and set `SUBFINDER_PROVIDER_CONFIG` to that file's absolute path. `SHODAN_API_KEY` is consumed by the Shodan module without printing the secret value. Environment variables can also be used instead of storing secrets in the config file.

## Usage

```bash
./apolloRE.sh -d example.com --mode passive
./apolloRE.sh -d example.com --mode web --rate-limit 25
./apolloRE.sh -d example.com --mode full --resume
./apolloRE.sh -d example.com --modules subdomains,http,history,normalize,diff,report
```

Standard pipelines include normalization and change tracking automatically:

```text
passive: subdomains -> dns -> http -> shodan -> history -> cloud -> takeover -> prioritize -> normalize -> diff -> report
web:     subdomains -> http -> crawl -> history -> javascript -> cloud -> screenshots -> prioritize -> normalize -> diff -> report
full:    subdomains -> dns -> http -> shodan -> ports -> crawl -> history -> javascript -> cloud -> takeover -> nuclei -> screenshots -> prioritize -> normalize -> diff -> report
```

Run `./apolloRE.sh --help` for all options.

## Normalized inventory

Every standard run produces `assets.jsonl`. Each line is an independent JSON object, making it easy to process with `jq`, Python, SIEM tooling, cron jobs, or another database/import pipeline.

Example records:

```json
{"type":"host","value":"api.example.com","source":"subdomains"}
{"type":"url","value":"https://api.example.com","source":"http","alive":true}
{"type":"service","value":"api.example.com:443","source":"ports","host":"api.example.com","port":443}
{"type":"url","value":"https://example.com/old-api","source":"history","historical":true}
{"type":"javascript","value":"https://example.com/app.js","source":"javascript"}
{"type":"cloud_candidate","value":"example-assets.s3.amazonaws.com","source":"cloud"}
{"type":"finding","value":"https://example.com","source":"nuclei","severity":"medium","template":"example-template"}
```

The normalization step deduplicates records using their type, value, and source while retaining useful fields such as `alive`, `historical`, `host`, `port`, `severity`, and template ID.

## Change detection

The first run for a domain creates:

```text
baseline/assets.jsonl
```

On each later run, ApolloRE compares the newly generated `assets.jsonl` against that baseline and produces:

```text
changes.md
changes.added.jsonl
changes.removed.jsonl
```

`changes.md` summarizes counts by record type and shows example additions/removals. After comparison, the current inventory becomes the new baseline, so the next run reports changes relative to the most recent completed run.

This makes repeated execution useful for detecting events such as:

```text
new host        -> new subdomain discovered
new service     -> host/port combination appeared
new URL         -> crawler or historical source exposed a new endpoint
new JavaScript  -> new script URL appeared
new finding     -> a normalized Nuclei result appeared
removed record  -> previously observed asset is no longer present in collected data
```

Change results mean "different from the previous ApolloRE inventory," not necessarily that the underlying system changed permanently. Recon providers, transient network conditions, rate limits, and `--resume` can affect collected data.

## Output

```text
results/example.com/
├── scope.txt
├── report.md
├── changes.md
├── assets.jsonl
├── changes.added.jsonl
├── changes.removed.jsonl
├── baseline/
│   └── assets.jsonl
├── assets/
│   ├── subdomains.txt
│   ├── alive.txt
│   ├── dns.txt
│   └── shodan.txt
├── web/
│   ├── http.jsonl
│   ├── urls.txt
│   ├── historical_urls.txt
│   └── javascript.txt
├── network/
│   └── ports.txt
├── findings/
│   ├── nuclei.jsonl
│   ├── cloud_candidates.txt
│   ├── takeover_candidates.txt
│   └── prioritized_targets.txt
├── screenshots/
└── logs/
    └── apollore.log
```

`prioritized_targets.txt` contains a score followed by the host or URL. Higher scores indicate strings associated with higher-value surfaces such as administration, authentication, APIs, development/staging systems, or common operational dashboards. It is a triage aid, not a vulnerability verdict.

## Monitoring example

For an authorized domain, a simple recurring execution can reuse the same output base so baseline comparison works across runs:

```bash
./apolloRE.sh -d example.com --mode passive
```

Inspect only additions:

```bash
jq -r '[.type,.value,.source] | @tsv' results/example.com/changes.added.jsonl
```

Inspect the human-readable delta:

```bash
cat results/example.com/changes.md
```

## Recommended dependencies

Core:

- subfinder
- httpx
- dnsutils (`dig`)
- naabu
- katana
- nuclei
- gau
- waybackurls
- shodan CLI (for Shodan enrichment)
- jq

Optional:

- gowitness or aquatone
- Chromium/Chrome for gowitness
- subjs

## Design

`apolloRE.sh` is the orchestrator. Shared functions live under `lib/`, while each reconnaissance stage implements a `run_<module>` function under `modules/`. External reconnaissance and passive enrichment remain separated from local analysis stages. `normalize` converts module-specific output into a common event-like schema, and `diff` compares that schema against the previous run's baseline for monitoring workflows.
