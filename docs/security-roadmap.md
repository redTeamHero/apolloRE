# ApolloRE v3 defensive assessment foundation

The existing external reconnaissance modes remain available. The default is now passive (which still performs HTTP probing), and the default rate hint is 5. Explicit authorization remains required.

## Local source assessment

Install reviewed, pinned versions of Semgrep, Gitleaks, Trivy and Checkov using their official installation guides. Then run:

```bash
bash security-local.sh /path/to/owned/source /path/to/private/security-results
```

The output directory must be outside the source tree. Each run receives a unique directory with restricted permissions and a status table. Missing tools and nonzero exits require review; neither means the source is clean. Semgrep may retrieve rules and Trivy may retrieve vulnerability databases. Reports may contain sensitive source snippets even when secrets are redacted. Do not publish them.

## Application assessment

Use dedicated staging accounts, synthetic data, separate organizations and explicit application scope. Configure ZAP browser authentication and passive analysis in the ZAP desktop app; review the scope and verify logged-in and logged-out behavior before saving a private automation plan. Keep credentials and browser state outside this repository. Do not automatically inherit credentials across discovered hosts. Use application-owned Playwright regression tests to assert tenant isolation, role restrictions, logout, session expiry and API authorization. Run those tests in the application's CI environment.

## Future work

- Explicit external asset allowlists and exclusions, per-tool request budgets and isolated run IDs.
- Version pinning and functional dependency checks.
- ZAP passive report import, application regression result import and unified finding normalization.
- SBOM, cloud posture and AI regression report integration.
- Reviewed staging-only active assessments remain separate from reconnaissance.
- DefectDojo ingestion and remediation tracking.

This change does not implement authenticated crawling or active scanning automation, nor does it modify existing CVE checks.
