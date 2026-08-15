# ApolloRE

ApolloRE is a modular reconnaissance, attack-surface mapping, vulnerability-triage, and continuous monitoring orchestrator for **authorized security testing and bug bounty reconnaissance**.

It takes a defined scope through a repeatable workflow:

```text
Scope -> Discovery -> Service mapping -> Web mapping -> Enrichment -> CVE triage -> Prioritization -> Normalize -> Diff -> Report
```

> Only assess systems you own or have explicit authorization to test. Follow the program's scope, rate limits, and prohibited-testing rules.

## What ApolloRE does

- DNS/subdomain discovery
- Explicit scope allow/exclude enforcement
- DNS names, wildcard domains, exact IPv4 addresses, and IPv4 CIDRs
- HTTP probing and technology fingerprinting
- Port inventory
- Shodan enrichment
- Crawling and historical URL discovery
- JavaScript inventory
- Cloud-storage and takeover candidate extraction
- NIST NVD CVE correlation
- Targeted CVE checks
- `safe` and broader `expanded` signed-template CVE profiles
- General Nuclei triage
- Screenshots
- Target prioritization
- Normalized JSONL asset inventory
- Baseline/change monitoring between runs
- Local API/config support
- Rate limiting and resumable stages

## Installation

```bash
git clone https://github.com/redTeamHero/apolloRE.git
cd apolloRE
chmod +x installer.sh apolloRE.sh
./installer.sh --core
```

Install optional tooling:

```bash
./installer.sh --all
```

Check dependencies:

```bash
./installer.sh --check
```

## Quick start

```bash
./apolloRE.sh -d example.com --mode full
```

Lower the request rate:

```bash
./apolloRE.sh -d example.com --mode full --rate-limit 20
```

Resume completed stages:

```bash
./apolloRE.sh -d example.com --mode full --resume
```

Run selected modules:

```bash
./apolloRE.sh -d example.com --modules subdomains,http,history,prioritize,normalize,diff,report
```

## Defining scope

Use `--scope-file` when a program provides explicit authorized assets. One entry goes on each line; `#` comments are allowed.

Supported entries:

```text
example.com
*.example.com
api.partner.example
*.partner.example
203.0.113.10
198.51.100.0/28
```

Example:

```bash
./apolloRE.sh -d example.com --scope-file scope.txt --mode full
```

`-d` is the primary run label/discovery root. Additional wildcard DNS entries become discovery roots. Exact DNS/IP entries become direct targets. CIDRs are passed to the network/port inventory rather than being expanded into a giant local target file.

### Exclusions

Exclusions override allowed scope:

```text
# exclude.txt
dev.example.com
*.internal.example.com
203.0.113.12
198.51.100.8/30
```

```bash
./apolloRE.sh -d example.com --scope-file scope.txt --exclude-file exclude.txt --mode full
```

ApolloRE records the effective policy under:

```text
results/example.com/scope.txt
results/example.com/scope.exclude.txt
```

See `SCOPE.md` for detailed matching behavior.

## Scan modes

**Passive**

```bash
./apolloRE.sh -d example.com --mode passive
```

```text
subdomains -> dns -> http -> shodan -> history -> cloud -> takeover -> prioritize -> normalize -> diff -> report
```

**Web**

```bash
./apolloRE.sh -d example.com --mode web
```

```text
subdomains -> http -> crawl -> history -> javascript -> cloud -> screenshots -> prioritize -> normalize -> diff -> report
```

**Full**

```bash
./apolloRE.sh -d example.com --mode full
```

```text
subdomains -> dns -> http -> shodan -> ports -> crawl -> history -> javascript -> cloud -> takeover -> cve -> nuclei -> screenshots -> prioritize -> normalize -> diff -> report
```

## Scope-oriented examples

Bug bounty program:

```bash
./apolloRE.sh -d example.com \
  --scope-file program-scope.txt \
  --exclude-file out-of-scope.txt \
  --rate-limit 20 \
  --mode full
```

Network inventory with IP/CIDR scope:

```text
# network-scope.txt
203.0.113.10
198.51.100.0/28
```

```bash
./apolloRE.sh -d example.com \
  --scope-file network-scope.txt \
  --modules ports,normalize,diff,report
```

Mixed DNS + network scope:

```text
example.com
*.example.com
203.0.113.10
198.51.100.0/28
```

```bash
./apolloRE.sh -d example.com --scope-file mixed-scope.txt --mode full
```

## CVE workflow

ApolloRE separates **correlation** from **detection**. Technology fingerprints are correlated with NIST NVD metadata and written to:

```text
findings/cve_candidates.jsonl
```

A candidate is not proof of vulnerability. Banners may be inaccurate and patched products can retain older-looking version strings.

Restricted verification matches are written to:

```text
findings/cve_detected.jsonl
```

Target a specific CVE:

```bash
./apolloRE.sh -d example.com --cve CVE-2024-12345
```

Default profile:

```bash
./apolloRE.sh -d example.com --cve CVE-2024-12345 --cve-profile safe
```

Broader signed-template coverage:

```bash
./apolloRE.sh -d example.com --cve CVE-2024-12345 --cve-profile expanded
```

`expanded` broadens protocol coverage while continuing to exclude fuzz/DoS, unsigned templates, and automatic arbitrary-code execution. Automated matches should be manually validated within program rules before reporting.

## Configuration/API keys

```bash
mkdir -p ~/.config/apollore
cp config/apollo.env.example ~/.config/apollore/config.env
chmod 600 ~/.config/apollore/config.env
```

Supported settings include:

```text
APOLLO_OUTPUT_BASE
APOLLO_RATE_LIMIT
APOLLO_USER_AGENT
NUCLEI_SEVERITIES
CVE_MAX_TECH_QUERIES
SUBFINDER_PROVIDER_CONFIG
SHODAN_API_KEY
NVD_API_KEY
WPSCAN_API_TOKEN
GITHUB_TOKEN
```

Use a custom config:

```bash
./apolloRE.sh -d example.com --config ./my-apollo.env --mode full
```

The config parser only accepts allow-listed keys and does not execute the file with `source`.

## Continuous monitoring

Repeated runs against the same scope/output location create a baseline and report changes:

```bash
./apolloRE.sh -d example.com --scope-file scope.txt --mode passive
cat results/example.com/changes.md
```

Outputs include:

```text
assets.jsonl
baseline/assets.jsonl
changes.added.jsonl
changes.removed.jsonl
changes.md
```

A removal means an item was not observed on the latest run; it does not necessarily mean the real-world asset was decommissioned.

## Modules

| Module | Purpose |
| --- | --- |
| `subdomains` | Discover DNS assets and apply scope |
| `dns` | Collect DNS records |
| `http` | Probe HTTP(S) and fingerprint technologies |
| `shodan` | Passive Shodan enrichment |
| `ports` | Inventory ports on scoped DNS/IP/CIDR targets |
| `crawl` | Crawl scoped live web apps |
| `history` | Collect scoped historical URLs |
| `javascript` | Inventory JavaScript resources |
| `cloud` | Extract cloud-storage candidates |
| `takeover` | Flag provider-linked CNAME candidates |
| `cve` | NVD correlation + restricted CVE verification |
| `nuclei` | General template-based triage |
| `screenshots` | Capture web screenshots |
| `prioritize` | Rank interesting assets |
| `normalize` | Produce normalized JSONL records |
| `diff` | Compare against the previous baseline |
| `report` | Generate the summary report |

## Results layout

```text
results/example.com/
├── scope.txt
├── scope.exclude.txt
├── assets.jsonl
├── report.md
├── changes.md
├── changes.added.jsonl
├── changes.removed.jsonl
├── baseline/assets.jsonl
├── assets/
│   ├── subdomains.txt
│   ├── http_targets.txt
│   ├── alive.txt
│   ├── dns.txt
│   └── shodan.txt
├── web/
│   ├── http.jsonl
│   ├── urls.txt
│   ├── historical_urls.txt
│   └── javascript.txt
├── network/
│   ├── port_targets.txt
│   └── ports.txt
├── findings/
│   ├── cve_candidates.jsonl
│   ├── cve_detected.jsonl
│   ├── nuclei.jsonl
│   ├── cloud_candidates.txt
│   ├── takeover_candidates.txt
│   └── prioritized_targets.txt
├── screenshots/
└── logs/apollore.log
```

## Command reference

```text
-d, --domain DOMAIN       Primary/root domain and run label
-m, --mode MODE           passive | web | full
    --modules LIST        Comma-separated modules
    --scope-file FILE     Authorized allow-list
    --exclude-file FILE   Explicit exclusions
    --cve CVE-ID          Target one CVE
    --cve-profile PROFILE safe | expanded
    --rate-limit N        Request-rate hint
    --config FILE         Config/API-key file
    --resume              Skip completed stages
-o, --output DIR          Results base directory
-v, --verbose             Verbose logging
-h, --help                Help
```

## Interpreting findings

- CVE correlation = candidate, not proof.
- CVE/Nuclei detection = evidence requiring validation.
- Cloud/takeover output = candidate for manual review.
- Passive/historical sources may be stale or incomplete.
- Change detection reports observation differences, not guaranteed infrastructure lifecycle events.
- Keep every scan within the authorization and rate limits of the target program.

## Architecture

`apolloRE.sh` is the orchestrator. `lib/` contains shared scope/config/logging logic, while `modules/` contains individual stages. This lets ApolloRE grow without turning the main runner into one large sequential script.
