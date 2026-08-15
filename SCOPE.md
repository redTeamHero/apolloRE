# ApolloRE Scope Controls

ApolloRE can now enforce an explicit DNS scope for every scan.

## Default behavior

Without a scope file, ApolloRE allows the supplied root domain and all of its subdomains:

```bash
./apolloRE.sh -d example.com --mode full
```

Resolved scope:

```text
example.com
*.example.com
```

## Allow-list

Create a file such as `scope.txt`:

```text
example.com
*.example.com
api.partner.example
*.partner.example
```

Run:

```bash
./apolloRE.sh -d example.com --scope-file scope.txt --mode full
```

Exact hosts are added directly to the discovery set. Wildcard entries such as `*.partner.example` are also treated as enumeration roots for Subfinder, historical URL sources, and Shodan enrichment.

## Exclusions

Create an optional deny-list:

```text
dev.example.com
*.internal.example.com
```

Run:

```bash
./apolloRE.sh -d example.com \
  --scope-file scope.txt \
  --exclude-file exclude.txt \
  --mode full
```

Exclusions always win over the allow-list.

## Matching rules

- `example.com` matches only that exact hostname.
- `*.example.com` matches subdomains such as `api.example.com`, but not the apex `example.com`.
- Blank lines and comments beginning with `#` are ignored.
- `http://`, `https://`, paths, ports, and a trailing dot are normalized away when reading scope files.
- Scope files currently accept DNS names and wildcard DNS names, not IP/CIDR ranges.

Every run writes the resolved policy into:

```text
results/<root>/scope.txt
results/<root>/scope.exclude.txt
```

Core host and URL-producing modules filter their output through this resolved policy before later scanning, enrichment, CVE checking, screenshots, normalization, or reporting.

Only include assets you own or are explicitly authorized to assess.
