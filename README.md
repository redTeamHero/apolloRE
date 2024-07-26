

## Domain Reconnaissance Script

This Bash script automates the process of reconnaissance and security assessment for a given domain. It performs a variety of checks and scans to gather information and identify potential security vulnerabilities. Below is a detailed breakdown of the script's functionality, usage instructions, and prerequisites.

### Features

1. **Log Management**: Captures and logs all output to `recon.log`, including error messages and information, with timestamps for better tracking.
2. **Dependency Checks**: Ensures all required tools are installed before running the main tasks.
3. **Disk Space Validation**: Verifies there is sufficient disk space available before proceeding.
4. **Backup Configuration**: Creates a backup of the `proxychains` configuration to avoid potential issues.
5. **Domain Validation**: Checks the format of the provided domain to ensure it is valid.
6. **Reconnaissance Tasks**:
   - **Subdomain Enumeration**: Identifies subdomains related to the main domain.
   - **Port Scanning**: Scans for open ports on the identified subdomains.
   - **JavaScript Analysis**: Examines JavaScript files for misconfigurations and secrets.
   - **Social Engineering**: Uses Social Hunter to gather additional information.
   - **Security Scans**: Executes scans using tools like `wpscan`, `shodan`, and `nuclei` to identify vulnerabilities.
   - **Web Screenshot Capture**: Captures screenshots of web pages for visual analysis.
7. **Cleanup**: Performs cleanup operations such as stopping services and removing temporary files.

### Usage

To use this script, follow the steps below:

1. **Basic Execution**:
   ```bash
   ./script.sh -d example.com
   ```
   - `-d <root_domain>`: Specify the root domain you want to analyze.
   - `-v` (optional): Enable verbose logging to get more detailed output.

2. **Verbose Mode**:
   ```bash
   ./script.sh -d example.com -v
   ```
   - The `-v` flag enables verbose logging, providing additional details about the execution.

### Dependencies

Ensure the following tools and commands are installed:

- `subfinder`
- `httpx-toolkit`
- `naabu`
- `aquatone`
- `shodan`
- `sqlmap`
- `nuclei`
- `wpscan`
- `jfscan`
- `curl`
- `perl`
- `python3`

### Functions

- **`log_with_timestamp`**: Adds timestamps and color-coded levels (INFO, ERROR, WARNING) to log messages.
- **`check_command_success`**: Checks the success of the last command and logs a warning if it failed.
- **`usage`**: Displays the usage information and exits if arguments are missing or incorrect.
- **`check_dependencies`**: Verifies that all required tools are installed.
- **`check_disk_space`**: Ensures there is at least 10MB of free disk space.
- **`backup_proxychains`**: Creates a backup of the `proxychains` configuration file.
- **`validate_domain`**: Validates the format of the provided domain.
- **`cleanup`**: Performs cleanup tasks, including stopping services and removing temporary files.
- **`extract_ip_addresses`**: Extracts IP addresses from the `ports.txt` file and saves them to `onlyip.txt`.
- **`move_results`**: Moves all result files to the results directory.

### Important Notes
- **Paths and Configurations**: Adjust file paths and configurations as needed based on your environment and setup.
- **Permissions**: Some commands require elevated permissions. Ensure you have the necessary privileges or adjust commands accordingly.

### Example

Here’s how to run the script to perform a reconnaissance scan on `example.com`:

```bash
./script.sh -d example.com -v
```

- This command runs the script on `example.com` with verbose output enabled.

---

