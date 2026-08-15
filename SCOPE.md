# ApolloRE Scope Controls

ApolloRE supports explicit allow and exclusion policies for authorized scans.

## Supported entries

```text
example.com          exact DNS host
*.example.com        DNS subdomains beneath example.com
203.0.113.10         exact IPv4 address
198.51.100.0/28      IPv4 CIDR
```

Blank lines and `#` comments are ignored. Exclusions always override allowed scope.

## Default behavior

Without `--scope-file`, the supplied root domain and its subdomains are allowed:

```text
example.com
*.example.com
```

```bash
./apolloRE.sh -d example.com --mode full
```

## Mixed scope example

```text
# scope.txt
example.com
*.example.com
api.partner.example
*.partner.example
203.0.113.10
198.51.100.0/28
```

```bash
./apolloRE.sh -d example.com --scope-file scope.txt --mode full
```

Exact DNS hosts are direct targets. Wildcard DNS entries provide additional discovery roots. Exact IPv4 addresses can participate in direct HTTP and port probing. IPv4 CIDRs are passed to the network/port stage rather than being expanded by ApolloRE into a large local list.

## Exclusions

```text
# exclude.txt
dev.example.com
*.internal.example.com
203.0.113.12
198.51.100.8/30
```

```bash
./apolloRE.sh -d example.com \
  --scope-file scope.txt \
  --exclude-file exclude.txt \
  --mode full
```

A target must match the allow-list and must not match an exclusion. For IPs, exact-IP and CIDR membership are evaluated numerically.

## Matching rules

- `example.com` matches only the exact host.
- `*.example.com` matches `api.example.com`, not the apex.
- `203.0.113.10` matches only that IPv4 address.
- `198.51.100.0/28` matches IPv4 addresses inside that network.
- An exact IP exclusion removes that address even when an allowed CIDR contains it.
- An excluded CIDR removes every address inside that range.
- IPv6/CIDR6 is not currently implemented.

Every run writes its resolved policy to:

```text
results/<root>/scope.txt
results/<root>/scope.exclude.txt
```

Use scope files that mirror the program's authorization. A technically valid CIDR is not authorization to test it.
