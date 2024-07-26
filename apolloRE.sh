#!/bin/bash

# Add .local/bin to PATH
export PATH=$PATH:/home/user/.local/bin

# Log file
log_file="recon.log"
exec > >(tee -a "$log_file") 2>&1

# Function to display messages with a timestamp
log_with_timestamp() {
    local level=$1
    local message=$2
    local color_code=$3
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $level: \e[${color_code}m$message\e[0m"
}

display_message() {
    log_with_timestamp "INFO" "$1" "32"
}

display_error() {
    log_with_timestamp "ERROR" "$1" "31"
}

display_warning() {
    log_with_timestamp "WARNING" "$1" "33"
}

# Function to check if a command was successful and continue
check_command_success() {
    if [ $? -ne 0 ]; then
        display_warning "$1 failed. Skipping..."
    fi
}

# Function to display usage information
usage() {
    echo "Usage: $0 -d <root_domain> [-v]"
    echo "  -d <root_domain> : Specify the root domain"
    echo "  -v               : Enable verbose logging"
    exit 1
}

# Function to check if required commands are installed
check_dependencies() {
    local dependencies=("subfinder" "httpx-toolkit" "naabu" "aquatone" "shodan" "sqlmap" "nuclei" "wpscan" "jfscan" "curl" "perl" "python3")
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            display_error "$cmd is not installed. Please install it to continue."
            exit 1
        fi
    done
}

# Function to check disk space
check_disk_space() {
    local required_space=10000000  # 10MB in kilobytes
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        display_error "Not enough disk space. At least 10MB is required."
        exit 1
    fi
}

# Function to backup proxychains configuration
backup_proxychains() {
    local backup_file="/etc/proxychains4.conf.bak"
    if [ ! -f "$backup_file" ]; then
        sudo cp /etc/proxychains4.conf "$backup_file"
    fi
}

# Function to validate domain format
validate_domain() {
    if ! [[ "$root" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        display_error "Invalid domain format."
        usage
    fi
}

# Function to run cleanup tasks
cleanup() {
    display_message "Performing cleanup tasks..."
    # Example cleanup tasks
    cd ..
    cd nipe
    perl nipe.pl stop
    perl nipe.pl status
    rm -f /path/to/temp/files/*.tmp
    display_message "Cleanup complete."
}

extract_ip_addresses() {
    awk -F: '{print $1}' ports.txt | sort -u > onlyip.txt
    check_command_success "Extracting IP addresses to onlyip.txt"
}

# Parse command-line arguments
verbose=false
while getopts ":d:v" opt; do
    case ${opt} in
        d )
            root=$OPTARG
            ;;
        v )
            verbose=true
            ;;
        \? )
            usage
            ;;
    esac
done

# Check if the root domain is provided
if [ -z "$root" ]; then
    display_error "No domain provided."
    usage
fi

# Validate domain format
validate_domain

# Check for required dependencies
check_dependencies

# Check disk space
check_disk_space

# Backup existing proxychains configuration
backup_proxychains

# Create root domain directory and navigate into it
mkdir -p "$root/results"
cd "$root" || exit
> ports.txt
cd ..
cp proxies.txt /home/user/fwd/$root
cd $root
display_message "[+] Hiding in Tor"

# Start TOR channel
cd ../nipe
sudo perl nipe.pl start
check_command_success "Nipe start"
sudo perl nipe.pl status
check_command_success "Nipe status"
cd ..

display_message "[+] TOR Gateway Started Finding Subdomains for $root"

display_message "Validating Proxies"
python3 /home/user/scripts/check.py

display_message "Rotating Alive Proxies"
python3 /home/user/scripts/rotate.py

display_message "Checking for s3 buckets!"
s3scanner --bucket $root --enumerate -verbose > s3scan.txt

# Start subdomain recon
cd "$root" || exit

# Find subdomains
display_message "[+] Finding Alive Subdomains for $root"
subfinder -d "$root" -t 100 -silent -o subs.txt
check_command_success "Subfinder"

# Check if subdomains are alive
if [ -s subs.txt ]; then
    httpx-toolkit -silent -no-color -l "subs.txt" -o "alive.txt"
    check_command_success "httpx-toolkit"
    sed -e 's/^https:\/\/\|^http:\/\///' alive.txt > jfscan.txt
    check_command_success "Processing alive.txt to create jfscan.txt"
else
    display_error "subs.txt is empty. Skipping httpx-toolkit..."
fi

display_message "[+] Finding open ports for $root"

# Ensure jfscan is installed and accessible
/home/user/.local/bin/jfscan --targets /home/user/fwd/$root/alive.txt --yummy-ports -oi -q --nmap -o ports.txt
check_command_success "jfscan"
extract_ip_addresses
# Check if alive.txt is not empty
if [ ! -s alive.txt ]; then
    display_warning "alive.txt is empty. Skipping subsequent steps..."
    exit 1
fi

display_message "[+] Checking JavaScript misconfiguration for $root"

# List JavaScript files
if [ -s alive.txt ]; then
    subjs -i "alive.txt" > js.txt
    check_command_success "subjs"
else
    display_warning "Error with subjs"
fi

display_message "Finding hidden parameters"
xnLinkFinder -i js.txt -v -sf $root

display_message "Looking for secrets in js.txt"

# Run the command for each URL
/home/user/fwd/s/SecretFinder.py -i js.txt -o results.html

# Start Social Hunter
display_message "[+] Running Social Hunter on $root"
cd ..
output_file="socialhunter_output.txt"
> "$output_file"

./socialhunter -f /home/user/fwd/$root/alive.txt >> "$output_file"
mv socialhunter_output.txt /home/user/fwd/$root
check_command_success "socialhunter"
cd $root
display_message "[+] Finished running Social Hunter on $root"

# Run wpscan for each domain

sleep 3
if [ -s alive.txt ]; then
    proxychains wpscan --url "$root" -v -e vp vt cb dbe --wp-content-dir DIR --ignore-main-redirect --force --user-agent example@domain.com --api-token YOUR_API_TOKEN >> "$output_file"
    check_command_success "wpscan for $root"
else
    display_warning "alive.txt is empty. Wpscan skipped..."
fi

display_message "[+] Finished Running wpscan on $root"

display_message "[+] Running a Shodan search on $root"

if [ -s alive.txt ]; then
    shodan init YOUR_API_KEY
    shodan search ssl.cert.subject.CN:"$root" 200 --fields ip_str | httpx | tee ips.txt
    check_command_success "Shodan search"
else
    display_warning "alive.txt is empty. Skipping Shodan search..."
fi

display_message "[+] Nuclei scan start for $root"

# Run Nuclei scan for alive domains
if [ -s alive.txt ]; then
    nuclei -rl 150 -c 25 -l "alive.txt" -v -H example@domain.com -severity low,medium,high,critical -as -o "vulns.txt"
    check_command_success "Nuclei domain scan"
else
    display_warning "alive.txt is empty. Skipping Nuclei domain scan..."
fi

display_message "Nuclei scan complete"

# Check if alive.txt exists and is not empty
if [ ! -s alive.txt ]; then
    display_error "File alive.txt not found or is empty!"
    exit 1
fi

display_message "[+] Capturing Web Screenshots $root"

# Take screenshots of alive domains
if [ -s alive.txt ]; then
    cat alive.txt | aquatone -silent -threads 3
    check_command_success "aquatone"
else
    display_warning "alive.txt is empty. Skipping aquatone..."
fi

if [ -s js.txt ]; then
    cat js.txt | aquatone -silent -threads 3
    check_command_success "aquatone"
else
    display_warning "js.txt is empty. Skipping aquatone..."
fi

display_message "[+] Finished Capturing Web Screenshots $root"

# Move results to the results directory
move_results() {
    mv s3scan.txt onlyip.txt alive.txt parameters.txt output.txt vulns.txt ports.txt socialhunter_output.txt wpscan_output.txt js.txt /home/user/fwd/$root/results
}
move_results

# Clean up
cleanup

display_message "[+] Recon Finished. Check results in $root folder. Happy hunting!"
