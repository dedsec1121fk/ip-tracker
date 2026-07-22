#!/usr/bin/env bash
set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
export CHAKRAVYUH_SCRIPT_DIR="$SCRIPT_DIR"

for ARG in "$@"; do
    if [ "$ARG" = "--help" ] || [ "$ARG" = "-h" ] || [ "$ARG" = "help" ]; then
        cat <<'HELP'
Chakravyuh IP Tracker 3.0

Usage / Χρήση:
  ./chakravyuh.sh
  ./chakravyuh.sh [--language en|gr|el] COMMAND [OPTIONS]

Commands / Εντολές:
  menu                         Interactive menu / Διαδραστικό μενού
  myip                         Check your public IP / Έλεγχος δημόσιας IP
  ip [TARGET]                   Check IP, hostname, or URL / Έλεγχος IP, hostname ή URL
  dns TARGET                    Resolve DNS information / Επίλυση πληροφοριών DNS
  phone NUMBER                 Validate a phone number / Έλεγχος αριθμού τηλεφώνου
  scan TARGET --ports PORTS --authorized
                               Authorized TCP audit / Εξουσιοδοτημένος έλεγχος TCP
  diagnostics [--lan] [--port PORT]
                               Consent diagnostics page / Διαγνωστικά με συναίνεση
  reports                      List saved reports / Προβολή αποθηκευμένων αναφορών
  language en|gr|el            Save interface language / Αποθήκευση γλώσσας
  self-test                    Offline self-test / Offline αυτοέλεγχος

Examples / Παραδείγματα:
  ./chakravyuh.sh myip
  ./chakravyuh.sh --language gr ip 8.8.8.8
  ./chakravyuh.sh dns example.com
  ./chakravyuh.sh phone +306912345678
  ./chakravyuh.sh scan 127.0.0.1 --ports 22,80,443 --authorized
  ./chakravyuh.sh diagnostics --lan --port 8080

Use active scanning only on systems you own or are authorized to test.
Χρησιμοποιείτε ενεργούς ελέγχους μόνο σε συστήματα που σας ανήκουν ή έχετε άδεια να ελέγξετε.
HELP
        exit 0
    fi
done

find_python() {
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "python3"
        return 0
    fi
    if command -v python >/dev/null 2>&1; then
        if python -c 'import sys; raise SystemExit(0 if sys.version_info.major >= 3 else 1)' >/dev/null 2>&1; then
            printf '%s' "python"
            return 0
        fi
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
    printf '%s\n' "Python 3 is missing. Installing it automatically..."
    printf '%s\n' "Το Python 3 λείπει. Γίνεται αυτόματη εγκατάσταση..."
    if command -v pkg >/dev/null 2>&1; then
        pkg install -y python
    elif command -v apt-get >/dev/null 2>&1; then
        run_admin apt-get update
        run_admin apt-get install -y python3
    elif command -v dnf >/dev/null 2>&1; then
        run_admin dnf install -y python3
    elif command -v yum >/dev/null 2>&1; then
        run_admin yum install -y python3
    elif command -v pacman >/dev/null 2>&1; then
        run_admin pacman -Sy --noconfirm python
    elif command -v apk >/dev/null 2>&1; then
        run_admin apk add python3
    elif command -v zypper >/dev/null 2>&1; then
        run_admin zypper --non-interactive install python3
    elif command -v brew >/dev/null 2>&1; then
        brew install python
    else
        printf '%s\n' "No supported package manager was found. Install Python 3 and run this file again."
        printf '%s\n' "Δεν βρέθηκε υποστηριζόμενος διαχειριστής πακέτων. Εγκαταστήστε το Python 3 και εκτελέστε ξανά το αρχείο."
        exit 1
    fi
}

PYTHON_BIN=$(find_python || true)
if [ -z "$PYTHON_BIN" ]; then
    install_python || exit 1
    PYTHON_BIN=$(find_python || true)
fi
if [ -z "$PYTHON_BIN" ]; then
    printf '%s\n' "Python 3 could not be started."
    printf '%s\n' "Δεν ήταν δυνατή η εκκίνηση του Python 3."
    exit 1
fi

export PYTHONUNBUFFERED=1
exec "$PYTHON_BIN" /dev/fd/3 "$@" 3<<'PYTHON'
import argparse
import concurrent.futures
import datetime
import html
import http.server
import ipaddress
import json
import os
import pathlib
import secrets
import socket
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

VERSION = "3.0.0"
APP_NAME = "Chakravyuh IP Tracker"
HOME = pathlib.Path.home()
CONFIG_DIR = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "chakravyuh"
CONFIG_FILE = CONFIG_DIR / "config.json"
REPORT_DIR = pathlib.Path(os.environ.get("CHAKRAVYUH_REPORT_DIR", HOME / "Chakravyuh-Reports"))

TEXT = {
    "en": {
        "choose_language": "Choose language / Επιλέξτε γλώσσα\n[1] English\n[2] Ελληνικά\n> ",
        "title": "Chakravyuh IP Tracker",
        "menu": "\n[1] Check my public IP\n[2] Check an IP, website, or hostname\n[3] Check DNS information\n[4] Validate a phone number\n[5] Authorized TCP port audit\n[6] Start consent diagnostics page\n[7] View saved reports\n[8] Settings\n[0] Exit\n> ",
        "invalid": "Invalid choice.",
        "press_enter": "Press Enter to continue...",
        "target": "Enter an IP, hostname, website, or URL. Leave blank for your own public IP: ",
        "domain": "Enter a domain, hostname, or URL: ",
        "phone": "Enter a phone number. Local numbers use Greece as the default country: ",
        "working": "Working...",
        "network_error": "The online service could not be reached. Check your internet connection and try again.",
        "invalid_target": "The target is invalid or could not be resolved.",
        "public_ip": "Public IP",
        "resolved_ip": "Resolved IP",
        "type": "Type",
        "private": "Private or local address",
        "public": "Public address",
        "country": "Country",
        "region": "Region",
        "city": "City",
        "isp": "ISP",
        "asn": "ASN",
        "timezone": "Time zone",
        "coordinates": "Coordinates",
        "map_prompt": "Open the approximate location in OpenStreetMap? [y/N]: ",
        "saved": "Report saved:",
        "dns_for": "DNS information for",
        "ipv4": "IPv4 addresses",
        "ipv6": "IPv6 addresses",
        "reverse": "Reverse DNS",
        "no_records": "No records were found.",
        "phone_valid": "The number appears valid.",
        "phone_possible": "The number is possible but could not be fully validated.",
        "phone_invalid": "The number is not valid.",
        "normalized": "Normalized number",
        "phone_region": "Country or region",
        "phone_type": "Number type",
        "greek_mobile": "Greek mobile",
        "greek_landline": "Greek landline",
        "international": "International number",
        "unknown": "Unknown",
        "scan_target": "Enter a device IP or hostname that you are authorized to test: ",
        "scan_presets": "Choose ports:\n[1] Common ports\n[2] Website ports\n[3] Remote-access ports\n[4] Custom ports\n> ",
        "custom_ports": "Enter ports such as 22,80,443 or 1-100. Maximum 256 ports: ",
        "authorization": "Type YES to confirm that you own the target or have explicit authorization: ",
        "not_authorized": "The audit was cancelled because authorization was not confirmed.",
        "too_many_ports": "Use no more than 256 valid TCP ports.",
        "scanning": "Scanning",
        "open_ports": "Open TCP ports",
        "none_open": "No open TCP ports were found in the selected set.",
        "diagnostics_mode": "Choose access mode:\n[1] This device only\n[2] Other devices on the same Wi-Fi\n> ",
        "diagnostics_port": "Port [8080]: ",
        "diagnostics_url": "Open this link in the participating browser:",
        "diagnostics_stop": "Press Ctrl+C to stop the diagnostics server.",
        "diagnostics_saved": "A consent diagnostics report was saved.",
        "reports_empty": "No reports have been saved yet.",
        "reports_title": "Saved reports",
        "report_action": "Enter a report number to open it, D to delete one, or Enter to return: ",
        "delete_number": "Enter the report number to delete: ",
        "deleted": "Report deleted.",
        "settings": "\n[1] Change language\n[2] Show storage locations\n[3] Delete all reports\n[4] Run self-test\n[0] Back\n> ",
        "storage": "Configuration: {config}\nReports: {reports}",
        "confirm_delete_all": "Type DELETE to remove all saved reports: ",
        "all_deleted": "All reports were deleted.",
        "language_changed": "Language changed.",
        "goodbye": "Goodbye.",
        "self_test_ok": "All self-tests passed.",
        "self_test_fail": "A self-test failed:",
        "cli_auth": "Non-interactive scanning requires --authorized.",
        "cli_ports": "Use --ports with a comma-separated list or range.",
        "consent_title": "Consent diagnostics",
        "consent_intro": "This page sends only the fields listed below after you actively agree.",
        "consent_fields": "IP address seen by this local server, browser user agent, browser language, platform, screen size, time zone, submission time, and the optional note you enter.",
        "consent_no_sensitive": "It does not request camera, microphone, GPS, files, contacts, passwords, or credentials.",
        "consent_label": "I understand and consent to sending these diagnostics to the person running this local server.",
        "optional_note": "Optional note",
        "submit": "Send diagnostics",
        "thank_you": "Diagnostics sent successfully. You may close this page.",
        "consent_required": "Consent is required.",
        "bad_request": "Invalid request.",
        "url_copied": "The link was copied to the clipboard when clipboard support was available.",
        "offline_private": "Geolocation is unavailable for private, loopback, reserved, or local addresses.",
        "api_notice": "IP geolocation is approximate and may be incomplete.",
    },
    "gr": {
        "choose_language": "Choose language / Επιλέξτε γλώσσα\n[1] English\n[2] Ελληνικά\n> ",
        "title": "Chakravyuh IP Tracker",
        "menu": "\n[1] Έλεγχος της δημόσιας IP μου\n[2] Έλεγχος IP, ιστοσελίδας ή ονόματος υπολογιστή\n[3] Έλεγχος πληροφοριών DNS\n[4] Έλεγχος αριθμού τηλεφώνου\n[5] Εξουσιοδοτημένος έλεγχος θυρών TCP\n[6] Εκκίνηση σελίδας διαγνωστικών με συναίνεση\n[7] Προβολή αποθηκευμένων αναφορών\n[8] Ρυθμίσεις\n[0] Έξοδος\n> ",
        "invalid": "Μη έγκυρη επιλογή.",
        "press_enter": "Πατήστε Enter για συνέχεια...",
        "target": "Δώστε IP, όνομα υπολογιστή, ιστοσελίδα ή URL. Αφήστε κενό για τη δική σας δημόσια IP: ",
        "domain": "Δώστε domain, όνομα υπολογιστή ή URL: ",
        "phone": "Δώστε αριθμό τηλεφώνου. Οι τοπικοί αριθμοί θεωρούνται ελληνικοί: ",
        "working": "Επεξεργασία...",
        "network_error": "Δεν ήταν δυνατή η σύνδεση με την online υπηρεσία. Ελέγξτε τη σύνδεσή σας και δοκιμάστε ξανά.",
        "invalid_target": "Ο προορισμός δεν είναι έγκυρος ή δεν ήταν δυνατή η επίλυσή του.",
        "public_ip": "Δημόσια IP",
        "resolved_ip": "IP που επιλύθηκε",
        "type": "Τύπος",
        "private": "Ιδιωτική ή τοπική διεύθυνση",
        "public": "Δημόσια διεύθυνση",
        "country": "Χώρα",
        "region": "Περιοχή",
        "city": "Πόλη",
        "isp": "Πάροχος",
        "asn": "ASN",
        "timezone": "Ζώνη ώρας",
        "coordinates": "Συντεταγμένες",
        "map_prompt": "Άνοιγμα της κατά προσέγγιση τοποθεσίας στο OpenStreetMap; [ν/Ο]: ",
        "saved": "Η αναφορά αποθηκεύτηκε:",
        "dns_for": "Πληροφορίες DNS για",
        "ipv4": "Διευθύνσεις IPv4",
        "ipv6": "Διευθύνσεις IPv6",
        "reverse": "Αντίστροφο DNS",
        "no_records": "Δεν βρέθηκαν εγγραφές.",
        "phone_valid": "Ο αριθμός φαίνεται έγκυρος.",
        "phone_possible": "Ο αριθμός είναι πιθανός, αλλά δεν ήταν δυνατή η πλήρης επιβεβαίωσή του.",
        "phone_invalid": "Ο αριθμός δεν είναι έγκυρος.",
        "normalized": "Κανονικοποιημένος αριθμός",
        "phone_region": "Χώρα ή περιοχή",
        "phone_type": "Τύπος αριθμού",
        "greek_mobile": "Ελληνικό κινητό",
        "greek_landline": "Ελληνικό σταθερό",
        "international": "Διεθνής αριθμός",
        "unknown": "Άγνωστο",
        "scan_target": "Δώστε IP ή όνομα συσκευής που έχετε άδεια να ελέγξετε: ",
        "scan_presets": "Επιλέξτε θύρες:\n[1] Συνηθισμένες θύρες\n[2] Θύρες ιστοσελίδων\n[3] Θύρες απομακρυσμένης πρόσβασης\n[4] Προσαρμοσμένες θύρες\n> ",
        "custom_ports": "Δώστε θύρες όπως 22,80,443 ή 1-100. Μέγιστο 256 θύρες: ",
        "authorization": "Γράψτε ΝΑΙ για να επιβεβαιώσετε ότι ο προορισμός σας ανήκει ή έχετε ρητή άδεια: ",
        "not_authorized": "Ο έλεγχος ακυρώθηκε επειδή δεν επιβεβαιώθηκε η εξουσιοδότηση.",
        "too_many_ports": "Χρησιμοποιήστε έως 256 έγκυρες θύρες TCP.",
        "scanning": "Έλεγχος",
        "open_ports": "Ανοιχτές θύρες TCP",
        "none_open": "Δεν βρέθηκαν ανοιχτές θύρες TCP στο επιλεγμένο σύνολο.",
        "diagnostics_mode": "Επιλέξτε τρόπο πρόσβασης:\n[1] Μόνο αυτή η συσκευή\n[2] Άλλες συσκευές στο ίδιο Wi-Fi\n> ",
        "diagnostics_port": "Θύρα [8080]: ",
        "diagnostics_url": "Ανοίξτε αυτόν τον σύνδεσμο στον συμμετέχοντα φυλλομετρητή:",
        "diagnostics_stop": "Πατήστε Ctrl+C για διακοπή του διακομιστή διαγνωστικών.",
        "diagnostics_saved": "Αποθηκεύτηκε αναφορά διαγνωστικών με συναίνεση.",
        "reports_empty": "Δεν έχουν αποθηκευτεί ακόμη αναφορές.",
        "reports_title": "Αποθηκευμένες αναφορές",
        "report_action": "Δώστε αριθμό αναφοράς για άνοιγμα, D για διαγραφή ή Enter για επιστροφή: ",
        "delete_number": "Δώστε τον αριθμό της αναφοράς για διαγραφή: ",
        "deleted": "Η αναφορά διαγράφηκε.",
        "settings": "\n[1] Αλλαγή γλώσσας\n[2] Προβολή θέσεων αποθήκευσης\n[3] Διαγραφή όλων των αναφορών\n[4] Εκτέλεση αυτοελέγχου\n[0] Επιστροφή\n> ",
        "storage": "Ρυθμίσεις: {config}\nΑναφορές: {reports}",
        "confirm_delete_all": "Γράψτε ΔΙΑΓΡΑΦΗ για να αφαιρεθούν όλες οι αναφορές: ",
        "all_deleted": "Όλες οι αναφορές διαγράφηκαν.",
        "language_changed": "Η γλώσσα άλλαξε.",
        "goodbye": "Αντίο.",
        "self_test_ok": "Όλοι οι αυτοέλεγχοι ολοκληρώθηκαν επιτυχώς.",
        "self_test_fail": "Απέτυχε ένας αυτοέλεγχος:",
        "cli_auth": "Ο μη διαδραστικός έλεγχος απαιτεί την επιλογή --authorized.",
        "cli_ports": "Χρησιμοποιήστε --ports με λίστα ή εύρος θυρών.",
        "consent_title": "Διαγνωστικά με συναίνεση",
        "consent_intro": "Η σελίδα στέλνει μόνο τα παρακάτω πεδία αφού συμφωνήσετε ενεργά.",
        "consent_fields": "Τη διεύθυνση IP που βλέπει αυτός ο τοπικός διακομιστής, τον φυλλομετρητή, τη γλώσσα, την πλατφόρμα, το μέγεθος οθόνης, τη ζώνη ώρας, την ώρα υποβολής και την προαιρετική σημείωση που θα γράψετε.",
        "consent_no_sensitive": "Δεν ζητά κάμερα, μικρόφωνο, GPS, αρχεία, επαφές, κωδικούς ή διαπιστευτήρια.",
        "consent_label": "Κατανοώ και συναινώ στην αποστολή αυτών των διαγνωστικών στο άτομο που εκτελεί αυτόν τον τοπικό διακομιστή.",
        "optional_note": "Προαιρετική σημείωση",
        "submit": "Αποστολή διαγνωστικών",
        "thank_you": "Τα διαγνωστικά στάλθηκαν επιτυχώς. Μπορείτε να κλείσετε τη σελίδα.",
        "consent_required": "Απαιτείται συναίνεση.",
        "bad_request": "Μη έγκυρο αίτημα.",
        "url_copied": "Ο σύνδεσμος αντιγράφηκε στο πρόχειρο όταν υπήρχε διαθέσιμη υποστήριξη.",
        "offline_private": "Η γεωεντόπιση δεν είναι διαθέσιμη για ιδιωτικές, τοπικές, δεσμευμένες ή loopback διευθύνσεις.",
        "api_notice": "Η γεωεντόπιση IP είναι κατά προσέγγιση και μπορεί να είναι ελλιπής.",
    },
}

LANG = "en"

def t(key):
    return TEXT.get(LANG, TEXT["en"]).get(key, TEXT["en"].get(key, key))

def load_config():
    try:
        data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}

def save_config(data):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    temp = CONFIG_FILE.with_suffix(".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        os.chmod(temp, 0o600)
    except OSError:
        pass
    temp.replace(CONFIG_FILE)

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

def timestamp():
    return datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat(timespec="seconds")

def safe_name(value):
    cleaned = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in str(value))
    return cleaned[:80] or "report"

def save_report(kind, target, data):
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    path = REPORT_DIR / f"{stamp}_{safe_name(kind)}_{safe_name(target)}.json"
    payload = {"application": APP_NAME, "version": VERSION, "type": kind, "target": target, "created_at": timestamp(), "data": data}
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path

def http_json(url, timeout=10):
    request = urllib.request.Request(url, headers={"User-Agent": f"{APP_NAME}/{VERSION}"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        if response.status != 200:
            raise urllib.error.URLError(f"HTTP {response.status}")
        raw = response.read(1024 * 1024)
    return json.loads(raw.decode("utf-8", errors="replace"))

def normalize_host(value):
    value = (value or "").strip()
    if not value:
        return ""
    parsed = urllib.parse.urlparse(value if "://" in value else "//" + value)
    host = parsed.hostname or value.split("/")[0]
    return host.strip().strip("[]").rstrip(".")

def resolve_target(value):
    host = normalize_host(value)
    if not host:
        return "", ""
    try:
        addr = ipaddress.ip_address(host)
        return host, str(addr)
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
    preferred = next((x for x in addresses if ":" not in x), addresses[0] if addresses else "")
    return host, preferred

def own_public_ip():
    request = urllib.request.Request("https://api.ipify.org?format=json", headers={"User-Agent": f"{APP_NAME}/{VERSION}"})
    with urllib.request.urlopen(request, timeout=10) as response:
        data = json.loads(response.read(65536).decode("utf-8"))
    return str(data.get("ip", "")).strip()

def show_ip(target=None, interactive=True):
    if target is None and interactive:
        target = input(t("target")).strip()
    target = target or ""
    print(t("working"))
    try:
        if not target:
            ip = own_public_ip()
            host = ip
        else:
            host, ip = resolve_target(target)
        if not ip:
            print(t("invalid_target"))
            return 1
        addr = ipaddress.ip_address(ip)
        result = {"input": target or "self", "host": host, "ip": ip, "address_type": "private" if not addr.is_global else "public"}
        print(f"{t('resolved_ip')}: {ip}")
        print(f"{t('type')}: {t('public') if addr.is_global else t('private')}")
        if not addr.is_global:
            print(t("offline_private"))
        else:
            try:
                geo = http_json("https://ipwho.is/" + urllib.parse.quote(ip, safe=""))
                if geo.get("success", True):
                    connection = geo.get("connection") or {}
                    tz = geo.get("timezone") or {}
                    result["geolocation"] = {
                        "country": geo.get("country"),
                        "region": geo.get("region"),
                        "city": geo.get("city"),
                        "isp": connection.get("isp"),
                        "asn": connection.get("asn"),
                        "timezone": tz.get("id"),
                        "latitude": geo.get("latitude"),
                        "longitude": geo.get("longitude"),
                    }
                    fields = [
                        ("country", t("country")),
                        ("region", t("region")),
                        ("city", t("city")),
                        ("isp", t("isp")),
                        ("asn", t("asn")),
                        ("timezone", t("timezone")),
                    ]
                    for key, label in fields:
                        value = result["geolocation"].get(key)
                        if value not in (None, ""):
                            print(f"{label}: {value}")
                    lat = result["geolocation"].get("latitude")
                    lon = result["geolocation"].get("longitude")
                    if lat is not None and lon is not None:
                        print(f"{t('coordinates')}: {lat}, {lon}")
                        if interactive:
                            answer = input(t("map_prompt")).strip().lower()
                            if answer in {"y", "yes", "ν", "ναι", "nαι"}:
                                webbrowser.open(f"https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map=10/{lat}/{lon}")
                    print(t("api_notice"))
                else:
                    result["geolocation_error"] = geo.get("message") or "unavailable"
            except Exception as exc:
                result["geolocation_error"] = str(exc)
                print(t("network_error"))
        path = save_report("ip", ip, result)
        print(f"{t('saved')} {path}")
        return 0
    except Exception:
        print(t("network_error"))
        return 1

def dns_lookup(target=None, interactive=True):
    if target is None and interactive:
        target = input(t("domain")).strip()
    host = normalize_host(target or "")
    if not host:
        print(t("invalid_target"))
        return 1
    ipv4 = []
    ipv6 = []
    reverse = {}
    try:
        infos = socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
        for info in infos:
            address = info[4][0]
            bucket = ipv6 if ":" in address else ipv4
            if address not in bucket:
                bucket.append(address)
        for address in ipv4 + ipv6:
            try:
                reverse[address] = socket.gethostbyaddr(address)[0]
            except OSError:
                pass
    except OSError:
        print(t("invalid_target"))
        return 1
    print(f"{t('dns_for')} {host}")
    print(f"{t('ipv4')}: {', '.join(ipv4) if ipv4 else '-'}")
    print(f"{t('ipv6')}: {', '.join(ipv6) if ipv6 else '-'}")
    if reverse:
        print(f"{t('reverse')}:")
        for address, name in reverse.items():
            print(f"  {address} -> {name}")
    data = {"host": host, "ipv4": ipv4, "ipv6": ipv6, "reverse_dns": reverse}
    path = save_report("dns", host, data)
    print(f"{t('saved')} {path}")
    return 0

def phone_lookup(number=None, interactive=True):
    if number is None and interactive:
        number = input(t("phone")).strip()
    raw = (number or "").strip()
    digits = "".join(ch for ch in raw if ch.isdigit())
    if raw.startswith("+"):
        normalized = "+" + digits
    elif digits.startswith("00"):
        normalized = "+" + digits[2:]
    elif len(digits) == 10 and digits.startswith(("2", "69")):
        normalized = "+30" + digits
    else:
        normalized = "+" + digits if digits else ""
    valid = False
    possible = False
    region = t("unknown")
    number_type = t("unknown")
    if normalized.startswith("+30") and len(normalized) == 13:
        local = normalized[3:]
        if local.startswith("69"):
            valid = True
            number_type = t("greek_mobile")
        elif local.startswith("2"):
            valid = True
            number_type = t("greek_landline")
        region = "Greece / Ελλάδα"
    elif normalized.startswith("+") and 8 <= len(digits) <= 15:
        possible = True
        region = t("international")
        number_type = t("international")
    status = t("phone_valid") if valid else t("phone_possible") if possible else t("phone_invalid")
    print(status)
    if normalized:
        print(f"{t('normalized')}: {normalized}")
    print(f"{t('phone_region')}: {region}")
    print(f"{t('phone_type')}: {number_type}")
    data = {"input": raw, "normalized": normalized, "valid": valid, "possible": possible, "region": region, "number_type": number_type}
    path = save_report("phone", normalized or "invalid", data)
    print(f"{t('saved')} {path}")
    return 0 if valid or possible else 1

def parse_ports(spec):
    ports = set()
    for part in (spec or "").split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            pieces = part.split("-", 1)
            if len(pieces) != 2:
                raise ValueError
            start = int(pieces[0])
            end = int(pieces[1])
            if start > end:
                start, end = end, start
            ports.update(range(start, end + 1))
        else:
            ports.add(int(part))
    if not ports or any(port < 1 or port > 65535 for port in ports) or len(ports) > 256:
        raise ValueError
    return sorted(ports)

def port_open(address, port, timeout=0.7):
    family = socket.AF_INET6 if ":" in address else socket.AF_INET
    sock = socket.socket(family, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        return sock.connect_ex((address, port)) == 0
    except OSError:
        return False
    finally:
        sock.close()

def scan_ports(target=None, ports_spec=None, authorized=False, interactive=True):
    if target is None and interactive:
        target = input(t("scan_target")).strip()
    host, address = resolve_target(target or "")
    if not address:
        print(t("invalid_target"))
        return 1
    if interactive and ports_spec is None:
        choice = input(t("scan_presets")).strip()
        presets = {"1": "20-23,25,53,80,110,139,143,443,445,3389,8080", "2": "80,443,8000,8080,8443", "3": "22,23,3389,5900,5901", "4": ""}
        ports_spec = presets.get(choice)
        if ports_spec == "":
            ports_spec = input(t("custom_ports")).strip()
    if not ports_spec:
        print(t("cli_ports"))
        return 1
    try:
        ports = parse_ports(ports_spec)
    except Exception:
        print(t("too_many_ports"))
        return 1
    if interactive:
        expected = {"YES", "ΝΑΙ"}
        authorized = input(t("authorization")).strip().upper() in expected
    if not authorized:
        print(t("not_authorized") if interactive else t("cli_auth"))
        return 1
    print(f"{t('scanning')} {address} ({len(ports)} ports)")
    open_ports = []
    completed = 0
    next_mark = 10
    workers = min(64, max(4, len(ports)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(port_open, address, port): port for port in ports}
        for future in concurrent.futures.as_completed(futures):
            port = futures[future]
            if future.result():
                open_ports.append(port)
            completed += 1
            percentage = int(completed * 100 / len(ports))
            if interactive and percentage >= next_mark:
                print(f"{percentage}%")
                next_mark += 10
    open_ports.sort()
    if open_ports:
        print(f"{t('open_ports')}: {', '.join(str(x) for x in open_ports)}")
    else:
        print(t("none_open"))
    data = {"host": host, "address": address, "ports_checked": ports, "open_ports": open_ports, "authorized": True}
    path = save_report("port-audit", address, data)
    print(f"{t('saved')} {path}")
    return 0

def local_ip():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        try:
            return socket.gethostbyname(socket.gethostname())
        except OSError:
            return "127.0.0.1"
    finally:
        sock.close()

def copy_text(value):
    commands = []
    if sys.platform == "darwin":
        commands.append(["pbcopy"])
    elif os.name == "nt":
        commands.append(["clip"])
    else:
        commands.extend([["termux-clipboard-set"], ["wl-copy"], ["xclip", "-selection", "clipboard"]])
    for command in commands:
        try:
            import subprocess
            subprocess.run(command, input=value, text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            return True
        except Exception:
            continue
    return False

def diagnostics_html(token):
    title = html.escape(t("consent_title"))
    intro = html.escape(t("consent_intro"))
    fields = html.escape(t("consent_fields"))
    no_sensitive = html.escape(t("consent_no_sensitive"))
    consent = html.escape(t("consent_label"))
    note = html.escape(t("optional_note"))
    submit = html.escape(t("submit"))
    return f"""<!doctype html><html lang=\"{'el' if LANG == 'gr' else 'en'}\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{title}</title><style>body{{font-family:system-ui,sans-serif;max-width:720px;margin:40px auto;padding:0 18px;line-height:1.55;background:#101319;color:#f1f3f5}}main{{background:#1b2028;padding:24px;border-radius:16px}}textarea{{width:100%;min-height:90px;box-sizing:border-box}}button{{padding:12px 18px;font-size:1rem}}label{{display:block;margin:18px 0}}.notice{{background:#252c36;padding:14px;border-radius:10px}}</style></head><body><main><h1>{title}</h1><p>{intro}</p><p class=\"notice\">{fields}</p><p>{no_sensitive}</p><form method=\"post\" action=\"/{token}\"><input type=\"hidden\" name=\"browser_language\" id=\"browser_language\"><input type=\"hidden\" name=\"platform\" id=\"platform\"><input type=\"hidden\" name=\"screen\" id=\"screen\"><input type=\"hidden\" name=\"timezone\" id=\"timezone\"><label><input required type=\"checkbox\" name=\"consent\" value=\"yes\"> {consent}</label><label>{note}<textarea name=\"note\" maxlength=\"500\"></textarea></label><button type=\"submit\">{submit}</button></form></main><script>document.getElementById('browser_language').value=navigator.language||'';document.getElementById('platform').value=navigator.platform||'';document.getElementById('screen').value=screen.width+'x'+screen.height;try{{document.getElementById('timezone').value=Intl.DateTimeFormat().resolvedOptions().timeZone||''}}catch(e){{}}</script></body></html>"""

def diagnostics_response(message, status=200):
    escaped = html.escape(message)
    return f"<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{escaped}</title></head><body style=\"font-family:system-ui;max-width:650px;margin:50px auto;padding:0 20px\"><h1>{escaped}</h1></body></html>".encode("utf-8"), status

def start_diagnostics(lan=None, port=None, interactive=True):
    if interactive and lan is None:
        lan = input(t("diagnostics_mode")).strip() == "2"
    lan = bool(lan)
    if interactive and port is None:
        value = input(t("diagnostics_port")).strip()
        port = int(value) if value else 8080
    port = int(port or 8080)
    if port < 1024 or port > 65535:
        port = 8080
    token = secrets.token_urlsafe(18)
    bind = "0.0.0.0" if lan else "127.0.0.1"
    visible_host = local_ip() if lan else "127.0.0.1"
    page = diagnostics_html(token).encode("utf-8")

    class Handler(http.server.BaseHTTPRequestHandler):
        server_version = "Chakravyuh"
        sys_version = ""

        def send_body(self, body, status=200):
            self.send_response(status)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if urllib.parse.urlparse(self.path).path != "/" + token:
                body, status = diagnostics_response(t("bad_request"), 404)
                self.send_body(body, status)
                return
            self.send_body(page)

        def do_POST(self):
            if urllib.parse.urlparse(self.path).path != "/" + token:
                body, status = diagnostics_response(t("bad_request"), 404)
                self.send_body(body, status)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                length = 0
            if length < 1 or length > 65536:
                body, status = diagnostics_response(t("bad_request"), 400)
                self.send_body(body, status)
                return
            values = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", errors="replace"), keep_blank_values=True)
            if values.get("consent", [""])[0] != "yes":
                body, status = diagnostics_response(t("consent_required"), 403)
                self.send_body(body, status)
                return
            data = {
                "consent": True,
                "client_ip": self.client_address[0],
                "user_agent": self.headers.get("User-Agent", "")[:500],
                "browser_language": values.get("browser_language", [""])[0][:100],
                "platform": values.get("platform", [""])[0][:100],
                "screen": values.get("screen", [""])[0][:40],
                "timezone": values.get("timezone", [""])[0][:100],
                "note": values.get("note", [""])[0][:500],
                "submitted_at": timestamp(),
            }
            path = save_report("consent-diagnostics", self.client_address[0], data)
            print(f"\n{t('diagnostics_saved')} {path}")
            body, status = diagnostics_response(t("thank_you"), 200)
            self.send_body(body, status)

        def log_message(self, format_value, *args):
            return

    try:
        server = http.server.ThreadingHTTPServer((bind, port), Handler)
    except OSError as exc:
        print(str(exc))
        return 1
    url = f"http://{visible_host}:{port}/{token}"
    print(f"{t('diagnostics_url')}\n{url}")
    if copy_text(url):
        print(t("url_copied"))
    print(t("diagnostics_stop"))
    try:
        server.serve_forever(poll_interval=0.3)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0

def report_files():
    if not REPORT_DIR.exists():
        return []
    return sorted(REPORT_DIR.glob("*.json"), reverse=True)

def show_reports(interactive=True):
    files = report_files()
    if not files:
        print(t("reports_empty"))
        return 0
    print(t("reports_title"))
    for index, path in enumerate(files, 1):
        print(f"[{index}] {path.name}")
    if not interactive:
        return 0
    action = input(t("report_action")).strip()
    if not action:
        return 0
    if action.lower() == "d":
        action = input(t("delete_number")).strip()
        try:
            files[int(action) - 1].unlink()
            print(t("deleted"))
        except Exception:
            print(t("invalid"))
        return 0
    try:
        print(files[int(action) - 1].read_text(encoding="utf-8"))
    except Exception:
        print(t("invalid"))
    return 0

def run_self_test():
    checks = []
    try:
        checks.append(normalize_host("https://example.com/path") == "example.com")
        checks.append(parse_ports("22,80,100-102") == [22, 80, 100, 101, 102])
        checks.append(len(parse_ports("1-256")) == 256)
        try:
            parse_ports("1-257")
            checks.append(False)
        except ValueError:
            checks.append(True)
        checks.append(ipaddress.ip_address("127.0.0.1").is_loopback)
        checks.append("consent" in diagnostics_html("token").lower())
        REPORT_DIR.mkdir(parents=True, exist_ok=True)
        checks.append(REPORT_DIR.is_dir())
    except Exception as exc:
        print(f"{t('self_test_fail')} {exc}")
        return 1
    if all(checks):
        print(t("self_test_ok"))
        return 0
    print(t("self_test_fail"), checks)
    return 1

def change_language(config):
    global LANG
    choice = input(TEXT["en"]["choose_language"]).strip()
    LANG = "gr" if choice == "2" else "en"
    config["language"] = LANG
    save_config(config)
    print(t("language_changed"))

def settings_menu(config):
    while True:
        choice = input(t("settings")).strip()
        if choice == "1":
            change_language(config)
        elif choice == "2":
            print(t("storage").format(config=CONFIG_FILE, reports=REPORT_DIR))
        elif choice == "3":
            answer = input(t("confirm_delete_all")).strip().upper()
            if answer in {"DELETE", "ΔΙΑΓΡΑΦΗ"}:
                for path in report_files():
                    try:
                        path.unlink()
                    except OSError:
                        pass
                print(t("all_deleted"))
        elif choice == "4":
            run_self_test()
        elif choice == "0":
            return
        else:
            print(t("invalid"))

def pause():
    try:
        input(t("press_enter"))
    except EOFError:
        pass

def interactive_menu(config):
    print(f"\n{t('title')} v{VERSION}")
    while True:
        choice = input(t("menu")).strip()
        if choice == "1":
            show_ip("", True)
            pause()
        elif choice == "2":
            show_ip(None, True)
            pause()
        elif choice == "3":
            dns_lookup(None, True)
            pause()
        elif choice == "4":
            phone_lookup(None, True)
            pause()
        elif choice == "5":
            scan_ports(None, None, False, True)
            pause()
        elif choice == "6":
            start_diagnostics(None, None, True)
            pause()
        elif choice == "7":
            show_reports(True)
            pause()
        elif choice == "8":
            settings_menu(config)
        elif choice == "0":
            print(t("goodbye"))
            return 0
        else:
            print(t("invalid"))

def build_parser():
    parser = argparse.ArgumentParser(prog="chakravyuh.sh", description="Bilingual IP intelligence and authorized network diagnostics")
    parser.add_argument("--language", choices=["en", "gr", "el"])
    parser.add_argument("--version", action="version", version=VERSION)
    sub = parser.add_subparsers(dest="command")
    sub.add_parser("menu")
    sub.add_parser("myip")
    ip_parser = sub.add_parser("ip")
    ip_parser.add_argument("target", nargs="?")
    dns_parser = sub.add_parser("dns")
    dns_parser.add_argument("target")
    phone_parser = sub.add_parser("phone")
    phone_parser.add_argument("number")
    scan_parser = sub.add_parser("scan")
    scan_parser.add_argument("target")
    scan_parser.add_argument("--ports", required=True)
    scan_parser.add_argument("--authorized", action="store_true")
    diag_parser = sub.add_parser("diagnostics")
    diag_parser.add_argument("--lan", action="store_true")
    diag_parser.add_argument("--port", type=int, default=8080)
    sub.add_parser("reports")
    language_parser = sub.add_parser("language")
    language_parser.add_argument("value", choices=["en", "gr", "el"])
    sub.add_parser("self-test")
    return parser

def main():
    parser = build_parser()
    args = parser.parse_args()
    config = load_config()
    forced = args.language
    if args.command == "language":
        forced = args.value
    choose_language(config, forced)
    if args.command in {None, "menu"}:
        return interactive_menu(config)
    if args.command == "myip":
        return show_ip("", False)
    if args.command == "ip":
        return show_ip(args.target or "", False)
    if args.command == "dns":
        return dns_lookup(args.target, False)
    if args.command == "phone":
        return phone_lookup(args.number, False)
    if args.command == "scan":
        return scan_ports(args.target, args.ports, args.authorized, False)
    if args.command == "diagnostics":
        return start_diagnostics(args.lan, args.port, False)
    if args.command == "reports":
        return show_reports(False)
    if args.command == "language":
        print(t("language_changed"))
        return 0
    if args.command == "self-test":
        return run_self_test()
    return 0

try:
    raise SystemExit(main())
except (EOFError, KeyboardInterrupt):
    print("\n" + t("goodbye"))
    raise SystemExit(0)
PYTHON
