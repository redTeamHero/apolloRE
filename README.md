# ApolloRE v2

ApolloRE is a modular Bash orchestrator for **authorized** domain reconnaissance, attack-surface mapping, vulnerability triage, and continuous asset monitoring.

## Safety and scope

Only run ApolloRE against systems you own or have explicit permission to assess. ApolloRE writes a `scope.txt` for every run and constrains host-based processing to the supplied root domain and its subdomains.

Cloud and takeover modules are intentionally non-destructive. The CVE module separates **correlation** from **detection** so a version/technology match is not reported as proof of vulnerability.

## Features

- Modular `passive`, `web`, and `full` pipelines
- Custom module selection with `--modules`
- `--resume` support
- Configurable rate limiting
- Local config/API-key loading with a strict allow-list
- Passive Shodan enrichment
- Historical URL collection via gau/waybackurls
- Cloud-storage and takeover candidate extraction
- CVE correlation using NIST NVD metadata
- Restricted CVE safe checks using signed Nuclei templates
- `--cve CVE-YYYY-NNNN` targeted CVE mode
- Interesting-target prioritization
- Normalized `assets.jsonl` inventory
- Automatic baseline and added/removed change detection
- Structured Markdown and JSONL output

## Modules

| Module | Purpose | Primary tool/source |
| --- | --- | --- |
| `subdomains` | Enumerate and scope subdomains | subfinder |
| `dns` | Collect DNS records | dig |
| `http` | Probe live HTTP(S) services and fingerprint them | httpx |
| `shodan` | Enrich scoped assets | Shodan |
| `ports` | Inventory exposed ports | naabu |
| `crawl` | Crawl scoped web applications | katana |
| `history` | Collect scoped historical URLs | gau / waybackurls |
| `javascript` | Build a JavaScript URL inventory | built-in + optional subjs |
| `cloud` | Extract cloud-storage endpoint candidates | built-in |
| `takeover` | Flag provider-linked CNAMEs for manual review | built-in |
| `cve` | Correlate technologies to CVEs and run restricted checks | NVD + Nuclei |
| `nuclei` | General template-based authorized checks | nuclei |
| `screenshots` | Capture visual web inventory | gowitness/aquatone |
| `prioritize` | Score interesting hosts/URLs | built-in |
| `normalize` | Merge outputs into normalized JSONL | jq |
| `diff` | Compare inventory with the previous baseline | jq + comm |
| `report` | Generate run summary | built-in |

## Installation

```bash
chmod +x installer.sh apolloRE.sh
./installer.sh --core
```

Optional browser/screenshot tooling:

```bash
./installer.sh --all
```

Dependency check only:

```bash
./installer.sh --check
```

## Configuration

```bash
mkdir -p ~/.config/apollore
cp config/apollo.env.example ~/.config/apollore/config.env
chmod 600 ~/.config/apollore/config.env
```

Supported keys include:

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

The config parser does not `source` or execute the file. Values are treated literally and only allow-listed keys are accepted.

`NVD_API_KEY` is optional. Without a key ApolloRE uses the public NVD API rate and intentionally spaces correlation requests. `CVE_MAX_TECH_QUERIES` limits the number of detected technology strings queried per run to reduce noise and API usage.

## Usage

Full authorized scan:

```bash
./apolloRE.sh -d example.com --mode full
```

Target one CVE:

```bash
./apolloRE.sh -d example.com --cve CVE-2024-12345
```

Run only discovery plus CVE processing:

```bash
./apolloRE.sh -d example.com \
  --modules subdomains,http,cve,normalize,report
```

Standard pipelines:

```text
passive: subdomains -> dns -> http -> shodan -> history -> cloud -> takeover -> prioritize -> normalize -> diff -> report
web:     subdomains -> http -> crawl -> history -> javascript -> cloud -> screenshots -> prioritize -> normalize -> diff -> report
full:    subdomains -> dns -> http -> shodan -> ports -> crawl -> history -> javascript -> cloud -> takeover -> cve -> nuclei -> screenshots -> prioritize -> normalize -> diff -> report
```

## CVE workflow

ApolloRE deliberately separates CVE results into two states.

### 1. Correlated

The HTTP fingerprint data is reduced to a limited set of technology strings. ApolloRE queries the NIST NVD CVE API for metadata related to those strings and writes candidate records to:

```text
findings/cve_candidates.jsonl
```

Example conceptually:

```json
{
  "type": "cve_candidate",
  "cve": "CVE-2024-12345",
  "status": "correlated",
  "correlation": "technology:ExampleServer:4.2",
  "source": "nvd",
  "severity": "HIGH"
}
```

A correlation is **not a vulnerability verdict**. Product banners may be inaccurate, vendors may backport patches, and keyword correlation can produce irrelevant CVEs.

When `--cve CVE-...` is supplied, ApolloRE queries NVD directly for that CVE rather than performing broad technology correlation.

### 2. Detected

If Nuclei and live URLs are available, the CVE module performs a restricted verification pass and writes matches to:

```text
findings/cve_detected.jsonl
```

The safe-check profile:

- selects templates tagged `cve`
- uses the configured severity list
- requires signed templates
- excludes `fuzz` and `dos` tags
- only enables HTTP, DNS, SSL, and TCP protocols
- does **not** enable code templates
- does **not** enable headless templates
- does **not** enable fuzz templates
- respects ApolloRE's rate limit

A Nuclei match is labeled **detected**, not automatically **validated**. Manual confirmation within the program's rules is still recommended before filing a report.

## Normalized inventory

Every standard run produces:

```text
assets.jsonl
```

The normalized inventory includes hosts, live URLs, services, crawled/historical URLs, JavaScript, cloud/takeover candidates, general Nuclei findings, CVE correlations, and CVE detections.

CVE examples:

```json
{"type":"cve_candidate","value":"CVE-2024-12345","source":"nvd","status":"correlated","severity":"HIGH"}
{"type":"cve_detection","value":"https://portal.example.com","source":"nuclei-cve","status":"detected","severity":"high","template":"CVE-2024-12345"}
```

## Change detection

The first completed run creates:

```text
baseline/assets.jsonl
```

Later runs produce:

```text
changes.md
changes.added.jsonl
changes.removed.jsonl
```

Because CVE candidates/detections are normalized too, recurring runs can surface a newly correlated or newly detected CVE as a change event.

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
│   ├── technologies.txt
│   ├── urls.txt
│   ├── historical_urls.txt
│   └── javascript.txt
├── network/
│   └── ports.txt
├── findings/
│   ├── cve_candidates.jsonl
│   ├── cve_detected.jsonl
│   ├── nuclei.jsonl
│   ├── cloud_candidates.txt
│   ├── takeover_candidates.txt
│   └── prioritized_targets.txt
├── screenshots/
└── logs/
    └── apollore.log
```

## Monitoring example

```bash
./apolloRE.sh -d example.com --mode passive
cat results/example.com/changes.md
```

For CVE-focused monitoring on an authorized target:

```bash
./apolloRE.sh -d example.com --mode full
jq -r 'select(.type=="cve_detection") | [.template,.value,.severity] | @tsv' \
  results/example.com/changes.added.jsonl
```

## Design

`apolloRE.sh` is the orchestrator. Shared functions live in `lib/`; each stage implements a `run_<module>` function under `modules/`. The `cve` module keeps correlation, restricted automated detection, and later human validation conceptually separate instead of silently turning a full recon run into an exploitation pipeline.
