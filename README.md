# Chakravyuh IP Tracker 3.0

## English

Chakravyuh is a compact bilingual utility for IP information, DNS checks, basic phone-number validation, authorized TCP port auditing, consent-based browser diagnostics, and local JSON reports. The complete application is contained in one executable file: `chakravyuh.sh`.

### What is included

- `chakravyuh.sh` — the complete application, dependency bootstrapper, interface, scanner, diagnostics server, and command-line tool.
- `README.md` — installation, usage, troubleshooting, privacy, and technical notes in English and Greek.
- `SECURITY.md` — vulnerability-reporting and authorized-use policy.
- `LICENSE` — MIT license.

No separate Python source files, launchers, requirements files, templates, or test folders are required.

### Supported systems

- Android with Termux
- Debian, Ubuntu, Kali, Linux Mint, Fedora, Arch, Alpine, openSUSE, and similar Linux systems
- macOS with Homebrew available when Python 3 is missing
- Windows through WSL

Native Windows Command Prompt and PowerShell do not run Bash scripts directly. Use WSL for the intended experience.

### Automatic dependency installation

The application requires only Python 3. When Python 3 is missing, `chakravyuh.sh` automatically attempts to install it using the available package manager:

- Termux: `pkg`
- Debian/Ubuntu/Kali/Mint: `apt-get`
- Fedora: `dnf`
- RHEL-family systems: `yum`
- Arch: `pacman`
- Alpine: `apk`
- openSUSE: `zypper`
- macOS: `brew`

The application itself uses Python’s standard library, so it does not need pip packages, virtual environments, Node.js, PHP, Nmap, jq, curl, or dnsutils. Package installation occurs only when Python 3 is missing. Administrator privileges may be requested by the operating system.

### Termux installation

Place the ZIP in the Downloads folder, extract it, and run:

```bash
cd ~/storage/downloads
unzip -o ip-tracker-compact-bilingual-v3.0.0.zip
cd ip-tracker-main
chmod +x chakravyuh.sh
./chakravyuh.sh
```

When Termux storage has not been enabled, run this once first:

```bash
termux-setup-storage
```

### Linux and WSL installation

```bash
unzip -o ip-tracker-compact-bilingual-v3.0.0.zip
cd ip-tracker-main
chmod +x chakravyuh.sh
./chakravyuh.sh
```

### macOS installation

```bash
unzip -o ip-tracker-compact-bilingual-v3.0.0.zip
cd ip-tracker-main
chmod +x chakravyuh.sh
./chakravyuh.sh
```

If Python 3 is absent, Homebrew must already be available so the script can install Python automatically.

### Language

The first launch asks for English or Greek and stores the choice. Change it later from Settings or directly:

```bash
./chakravyuh.sh language en
./chakravyuh.sh language gr
```

`el` is accepted as an alternative Greek code.

### Main menu

1. Check your own public IP.
2. Check an IP address, website, hostname, or full URL.
3. Resolve IPv4, IPv6, and reverse-DNS information.
4. Validate Greek local numbers and general international-number structure.
5. Audit up to 256 TCP ports on an authorized target.
6. Start a local consent diagnostics page.
7. View saved JSON reports.
8. Change settings, display storage locations, delete reports, or run self-tests.

### Command-line examples

```bash
./chakravyuh.sh myip
./chakravyuh.sh ip 8.8.8.8
./chakravyuh.sh ip https://example.com/path
./chakravyuh.sh dns example.com
./chakravyuh.sh phone 6912345678
./chakravyuh.sh phone +306912345678
./chakravyuh.sh scan 192.168.1.1 --ports 22,80,443 --authorized
./chakravyuh.sh scan 127.0.0.1 --ports 1-100 --authorized
./chakravyuh.sh diagnostics
./chakravyuh.sh diagnostics --lan --port 8080
./chakravyuh.sh reports
./chakravyuh.sh self-test
./chakravyuh.sh --language gr myip
```

### IP information

Leaving the target blank in the interactive IP check retrieves your public IP. A supplied hostname or URL is normalized and resolved first. Public addresses may be sent to `ipwho.is` to obtain approximate city, region, country, ISP, ASN, time zone, latitude, and longitude. Your own public address is obtained from `api.ipify.org`.

IP geolocation is approximate. It may identify an ISP area, city, or regional routing location rather than a person’s exact physical position. Private, loopback, reserved, multicast, and local addresses are not sent for public geolocation.

### DNS information

The DNS function uses the operating system resolver through Python. It displays resolved IPv4 and IPv6 addresses and attempts reverse DNS for each address. It does not enumerate every DNS record type such as MX, TXT, CAA, or DNSSEC because the compact edition avoids external DNS libraries and tools.

### Phone-number validation

The compact edition performs local Greek and general international structural checks without sending phone numbers to an online service. Greek ten-digit mobile numbers beginning with `69` and landline numbers beginning with `2` are normalized with `+30`. International numbers are checked against the general E.164 length range.

This does not reveal a person’s identity, live location, address, SIM owner, or current device position. A structurally possible number is not proof that the number exists or belongs to a specific person.

### Authorized port auditing

The port auditor uses TCP connection attempts and supports individual ports, comma-separated lists, and ranges. Examples:

```text
22,80,443
1-100
22,80,8000-8010
```

A maximum of 256 ports is enforced. Interactive use requires typing `YES` or `ΝΑΙ`. Command-line use requires `--authorized`. Use it only on your own devices, training labs, or systems for which you have explicit permission.

A closed or filtered result can be affected by firewalls, routing, rate limits, temporary service state, or network policy. An open port does not automatically mean a vulnerability exists.

### Consent diagnostics page

The diagnostics function starts a temporary local web server. Two modes are available:

- This device only: bound to `127.0.0.1`.
- Same Wi-Fi: bound to all local interfaces and displayed using the device’s LAN address.

The URL contains a random access token. The page clearly lists the data and requires an affirmative checkbox before submission. It can record only:

- the client IP visible to the local server;
- browser user agent;
- browser language;
- platform string;
- screen dimensions;
- browser time zone;
- submission time;
- an optional note entered by the participant.

It does not request or access the camera, microphone, GPS, files, contacts, passwords, cookies, credentials, or clipboard. It does not imitate login, update, Cloudflare, banking, social-media, or other trusted pages. It does not upload reports to Telegram or another remote destination.

Stop the diagnostics server with `Ctrl+C`. The same-Wi-Fi mode may require firewall permission. Do not expose it to the public internet or forward its port through a router.

### Reports and configuration

Reports are stored as readable JSON files in:

```text
~/Chakravyuh-Reports
```

The language preference is stored in:

```text
~/.config/chakravyuh/config.json
```

The configuration file is written with restrictive permissions where supported. Reports may contain IP addresses and browser metadata, so protect them and delete them when no longer required.

To use another report folder for one launch:

```bash
CHAKRAVYUH_REPORT_DIR="$HOME/my-reports" ./chakravyuh.sh
```

### Self-test

Run the offline self-test after installation or modification:

```bash
./chakravyuh.sh self-test
```

It validates URL normalization, port parsing, the 256-port limit, IP parsing, diagnostics consent-page generation, and report-directory access. It does not scan an external system or require internet access.

### Troubleshooting

**Permission denied**

```bash
chmod +x chakravyuh.sh
./chakravyuh.sh
```

**Python installation fails**

Update the operating system repositories, verify internet access, and install Python 3 using the system package manager. Then rerun the script.

**Public IP or geolocation fails**

Verify internet access and DNS resolution. The external service may be unavailable or blocked. DNS, phone validation, local scanning, reports, settings, and self-test remain independent of the geolocation service.

**Same-Wi-Fi page does not open**

Confirm both devices are on the same network, mobile-data isolation is not interfering, the displayed address is the current LAN address, and the selected port is allowed by the local firewall. Some guest Wi-Fi networks block communication between clients.

**A port scan shows no open ports**

Confirm the target is online, the address is correct, the service is running, and a firewall is not filtering connections.

### Removal

Delete the extracted project folder. To remove user data as well:

```bash
rm -rf "$HOME/Chakravyuh-Reports" "$HOME/.config/chakravyuh"
```

Review the command before running it. It permanently removes the application’s reports and saved language preference.

### Security and responsible use

Read `SECURITY.md`. Do not scan third-party systems without authorization. Do not publish reports containing personal data, internal addresses, tokens, or security-sensitive results. The project is intended for personal diagnostics, education, controlled labs, and authorized security work.

### License

MIT. See `LICENSE`.

---

## Ελληνικά

Το Chakravyuh είναι ένα συμπαγές δίγλωσσο εργαλείο για πληροφορίες IP, ελέγχους DNS, βασικό έλεγχο αριθμών τηλεφώνου, εξουσιοδοτημένο έλεγχο θυρών TCP, διαγνωστικά φυλλομετρητή με συναίνεση και τοπικές αναφορές JSON. Ολόκληρη η εφαρμογή περιέχεται σε ένα εκτελέσιμο αρχείο: `chakravyuh.sh`.

### Περιεχόμενα

- `chakravyuh.sh` — ολόκληρη η εφαρμογή, η αυτόματη εγκατάσταση εξάρτησης, το περιβάλλον, ο έλεγχος θυρών, ο διακομιστής διαγνωστικών και οι εντολές τερματικού.
- `README.md` — εγκατάσταση, χρήση, αντιμετώπιση προβλημάτων, ιδιωτικότητα και τεχνικές πληροφορίες στα Ελληνικά και στα Αγγλικά.
- `SECURITY.md` — πολιτική αναφοράς ευπαθειών και εξουσιοδοτημένης χρήσης.
- `LICENSE` — άδεια MIT.

Δεν απαιτούνται ξεχωριστά αρχεία Python, εκκινητές, requirements, templates ή φάκελοι δοκιμών.

### Υποστηριζόμενα συστήματα

- Android με Termux
- Debian, Ubuntu, Kali, Linux Mint, Fedora, Arch, Alpine, openSUSE και παρόμοια Linux
- macOS με διαθέσιμο Homebrew όταν λείπει το Python 3
- Windows μέσω WSL

Το εγγενές Command Prompt και το PowerShell των Windows δεν εκτελούν άμεσα αρχεία Bash. Χρησιμοποιήστε WSL για την προβλεπόμενη λειτουργία.

### Αυτόματη εγκατάσταση εξάρτησης

Η εφαρμογή χρειάζεται μόνο Python 3. Όταν λείπει, το `chakravyuh.sh` προσπαθεί αυτόματα να το εγκαταστήσει με τον διαθέσιμο διαχειριστή πακέτων:

- Termux: `pkg`
- Debian/Ubuntu/Kali/Mint: `apt-get`
- Fedora: `dnf`
- Συστήματα οικογένειας RHEL: `yum`
- Arch: `pacman`
- Alpine: `apk`
- openSUSE: `zypper`
- macOS: `brew`

Η εφαρμογή χρησιμοποιεί τις ενσωματωμένες βιβλιοθήκες του Python. Δεν χρειάζεται πακέτα pip, virtual environment, Node.js, PHP, Nmap, jq, curl ή dnsutils. Εγκατάσταση πακέτου γίνεται μόνο όταν λείπει το Python 3. Το λειτουργικό σύστημα μπορεί να ζητήσει δικαιώματα διαχειριστή.

### Εγκατάσταση στο Termux

Τοποθετήστε το ZIP στις Λήψεις, αποσυμπιέστε το και εκτελέστε:

```bash
cd ~/storage/downloads
unzip -o ip-tracker-compact-bilingual-v3.0.0.zip
cd ip-tracker-main
chmod +x chakravyuh.sh
./chakravyuh.sh
```

Αν δεν έχει ενεργοποιηθεί η πρόσβαση του Termux στον αποθηκευτικό χώρο, εκτελέστε πρώτα μία φορά:

```bash
termux-setup-storage
```

### Εγκατάσταση σε Linux και WSL

```bash
unzip -o ip-tracker-compact-bilingual-v3.0.0.zip
cd ip-tracker-main
chmod +x chakravyuh.sh
./chakravyuh.sh
```

### Εγκατάσταση σε macOS

```bash
unzip -o ip-tracker-compact-bilingual-v3.0.0.zip
cd ip-tracker-main
chmod +x chakravyuh.sh
./chakravyuh.sh
```

Αν λείπει το Python 3, το Homebrew πρέπει να είναι ήδη διαθέσιμο ώστε το script να το εγκαταστήσει αυτόματα.

### Γλώσσα

Στην πρώτη εκκίνηση επιλέγετε Αγγλικά ή Ελληνικά και η επιλογή αποθηκεύεται. Μπορείτε να την αλλάξετε από τις Ρυθμίσεις ή απευθείας:

```bash
./chakravyuh.sh language en
./chakravyuh.sh language gr
```

Γίνεται επίσης δεκτός ο κωδικός `el` για τα Ελληνικά.

### Κύριο μενού

1. Έλεγχος της δικής σας δημόσιας IP.
2. Έλεγχος διεύθυνσης IP, ιστοσελίδας, ονόματος υπολογιστή ή πλήρους URL.
3. Επίλυση IPv4, IPv6 και αντίστροφου DNS.
4. Έλεγχος ελληνικών τοπικών και γενικών διεθνών αριθμών.
5. Έλεγχος έως 256 θυρών TCP σε εξουσιοδοτημένο προορισμό.
6. Εκκίνηση τοπικής σελίδας διαγνωστικών με συναίνεση.
7. Προβολή αποθηκευμένων αναφορών JSON.
8. Αλλαγή ρυθμίσεων, προβολή θέσεων αποθήκευσης, διαγραφή αναφορών ή αυτοέλεγχος.

### Παραδείγματα εντολών

```bash
./chakravyuh.sh myip
./chakravyuh.sh ip 8.8.8.8
./chakravyuh.sh ip https://example.com/path
./chakravyuh.sh dns example.com
./chakravyuh.sh phone 6912345678
./chakravyuh.sh phone +306912345678
./chakravyuh.sh scan 192.168.1.1 --ports 22,80,443 --authorized
./chakravyuh.sh scan 127.0.0.1 --ports 1-100 --authorized
./chakravyuh.sh diagnostics
./chakravyuh.sh diagnostics --lan --port 8080
./chakravyuh.sh reports
./chakravyuh.sh self-test
./chakravyuh.sh --language gr myip
```

### Πληροφορίες IP

Αφήνοντας κενό τον προορισμό στον διαδραστικό έλεγχο, λαμβάνεται η δημόσια IP σας. Ένα όνομα υπολογιστή ή URL κανονικοποιείται και επιλύεται πρώτα. Οι δημόσιες διευθύνσεις μπορεί να αποσταλούν στο `ipwho.is` για κατά προσέγγιση πόλη, περιοχή, χώρα, πάροχο, ASN, ζώνη ώρας, γεωγραφικό πλάτος και μήκος. Η δική σας δημόσια IP λαμβάνεται από το `api.ipify.org`.

Η γεωεντόπιση IP είναι κατά προσέγγιση. Μπορεί να δείχνει περιοχή παρόχου, πόλη ή θέση δικτυακής δρομολόγησης και όχι την ακριβή φυσική θέση ενός ατόμου. Ιδιωτικές, loopback, δεσμευμένες, multicast και τοπικές διευθύνσεις δεν αποστέλλονται για δημόσια γεωεντόπιση.

### Πληροφορίες DNS

Η λειτουργία DNS χρησιμοποιεί τον resolver του λειτουργικού συστήματος μέσω Python. Εμφανίζει τις διευθύνσεις IPv4 και IPv6 και επιχειρεί αντίστροφο DNS για καθεμία. Δεν απαριθμεί όλους τους τύπους εγγραφών, όπως MX, TXT, CAA ή DNSSEC, επειδή η συμπαγής έκδοση αποφεύγει εξωτερικές βιβλιοθήκες και εργαλεία DNS.

### Έλεγχος αριθμού τηλεφώνου

Η συμπαγής έκδοση εκτελεί ελέγχους δομής για ελληνικούς τοπικούς και γενικούς διεθνείς αριθμούς χωρίς αποστολή τους σε online υπηρεσία. Οι ελληνικοί δεκαψήφιοι αριθμοί κινητού που αρχίζουν με `69` και οι αριθμοί σταθερού που αρχίζουν με `2` κανονικοποιούνται με `+30`. Οι διεθνείς αριθμοί ελέγχονται σύμφωνα με το γενικό εύρος μήκους E.164.

Αυτό δεν αποκαλύπτει ταυτότητα, ζωντανή τοποθεσία, διεύθυνση, κάτοχο SIM ή τρέχουσα θέση συσκευής. Ένας δομικά πιθανός αριθμός δεν αποδεικνύει ότι υπάρχει ή ότι ανήκει σε συγκεκριμένο άτομο.

### Εξουσιοδοτημένος έλεγχος θυρών

Ο έλεγχος θυρών χρησιμοποιεί συνδέσεις TCP και υποστηρίζει μεμονωμένες θύρες, λίστες και εύρη. Παραδείγματα:

```text
22,80,443
1-100
22,80,8000-8010
```

Επιβάλλεται όριο 256 θυρών. Η διαδραστική χρήση απαιτεί να γράψετε `YES` ή `ΝΑΙ`. Η χρήση από γραμμή εντολών απαιτεί `--authorized`. Χρησιμοποιήστε τη λειτουργία μόνο σε δικές σας συσκευές, εργαστήρια εκπαίδευσης ή συστήματα για τα οποία έχετε ρητή άδεια.

Ένα αποτέλεσμα κλειστής ή φιλτραρισμένης θύρας μπορεί να επηρεάζεται από firewall, δρομολόγηση, όρια αιτημάτων, προσωρινή κατάσταση υπηρεσίας ή πολιτική δικτύου. Μια ανοιχτή θύρα δεν σημαίνει αυτόματα ότι υπάρχει ευπάθεια.

### Σελίδα διαγνωστικών με συναίνεση

Η λειτουργία διαγνωστικών ξεκινά έναν προσωρινό τοπικό web server. Υπάρχουν δύο τρόποι:

- Μόνο αυτή η συσκευή: σύνδεση στο `127.0.0.1`.
- Ίδιο Wi-Fi: σύνδεση σε όλες τις τοπικές διεπαφές και εμφάνιση της διεύθυνσης LAN της συσκευής.

Το URL περιέχει τυχαίο διακριτικό πρόσβασης. Η σελίδα αναφέρει καθαρά τα δεδομένα και απαιτεί ενεργή επιλογή συναίνεσης πριν από την υποβολή. Μπορεί να καταγράψει μόνο:

- την IP του πελάτη όπως τη βλέπει ο τοπικός διακομιστής,
- το user agent του φυλλομετρητή,
- τη γλώσσα του φυλλομετρητή,
- το όνομα πλατφόρμας,
- τις διαστάσεις οθόνης,
- τη ζώνη ώρας του φυλλομετρητή,
- την ώρα υποβολής,
- μια προαιρετική σημείωση του συμμετέχοντα.

Δεν ζητά ή προσπελαύνει κάμερα, μικρόφωνο, GPS, αρχεία, επαφές, κωδικούς, cookies, διαπιστευτήρια ή πρόχειρο. Δεν μιμείται σελίδες σύνδεσης, ενημέρωσης, Cloudflare, τραπεζών, κοινωνικών δικτύων ή άλλων αξιόπιστων υπηρεσιών. Δεν αποστέλλει αναφορές στο Telegram ή σε άλλο απομακρυσμένο προορισμό.

Σταματήστε τον διακομιστή με `Ctrl+C`. Η λειτουργία ίδιου Wi-Fi μπορεί να χρειάζεται άδεια firewall. Μην την εκθέτετε στο δημόσιο διαδίκτυο και μην προωθείτε τη θύρα της μέσω router.

### Αναφορές και ρυθμίσεις

Οι αναφορές αποθηκεύονται ως αναγνώσιμα αρχεία JSON στον φάκελο:

```text
~/Chakravyuh-Reports
```

Η προτίμηση γλώσσας αποθηκεύεται στο:

```text
~/.config/chakravyuh/config.json
```

Το αρχείο ρυθμίσεων λαμβάνει περιορισμένα δικαιώματα όπου υποστηρίζεται. Οι αναφορές μπορεί να περιέχουν IP και μεταδεδομένα φυλλομετρητή, γι’ αυτό πρέπει να προστατεύονται και να διαγράφονται όταν δεν χρειάζονται.

Για διαφορετικό φάκελο αναφορών σε μία εκκίνηση:

```bash
CHAKRAVYUH_REPORT_DIR="$HOME/my-reports" ./chakravyuh.sh
```

### Αυτοέλεγχος

Εκτελέστε τον offline αυτοέλεγχο μετά την εγκατάσταση ή τροποποίηση:

```bash
./chakravyuh.sh self-test
```

Ελέγχει την κανονικοποίηση URL, την ανάλυση θυρών, το όριο 256 θυρών, την ανάλυση IP, τη δημιουργία σελίδας διαγνωστικών με συναίνεση και την πρόσβαση στον φάκελο αναφορών. Δεν ελέγχει εξωτερικό σύστημα και δεν χρειάζεται σύνδεση στο διαδίκτυο.

### Αντιμετώπιση προβλημάτων

**Permission denied**

```bash
chmod +x chakravyuh.sh
./chakravyuh.sh
```

**Αποτυχία εγκατάστασης Python**

Ενημερώστε τα αποθετήρια του λειτουργικού συστήματος, ελέγξτε τη σύνδεση στο διαδίκτυο και εγκαταστήστε Python 3 με τον διαχειριστή πακέτων. Μετά εκτελέστε ξανά το script.

**Αποτυχία δημόσιας IP ή γεωεντόπισης**

Ελέγξτε τη σύνδεση και το DNS. Η εξωτερική υπηρεσία μπορεί να είναι εκτός λειτουργίας ή αποκλεισμένη. Το DNS, ο έλεγχος τηλεφώνου, ο τοπικός έλεγχος θυρών, οι αναφορές, οι ρυθμίσεις και ο αυτοέλεγχος παραμένουν ανεξάρτητα από τη γεωεντόπιση.

**Η σελίδα ίδιου Wi-Fi δεν ανοίγει**

Βεβαιωθείτε ότι οι δύο συσκευές βρίσκονται στο ίδιο δίκτυο, ότι δεν υπάρχει απομόνωση λόγω δεδομένων κινητής, ότι η διεύθυνση που εμφανίζεται είναι η τρέχουσα LAN και ότι η επιλεγμένη θύρα επιτρέπεται από το τοπικό firewall. Ορισμένα guest Wi-Fi εμποδίζουν την επικοινωνία μεταξύ συσκευών.

**Ο έλεγχος δεν εμφανίζει ανοιχτές θύρες**

Επιβεβαιώστε ότι ο προορισμός είναι ενεργός, η διεύθυνση σωστή, η υπηρεσία εκτελείται και το firewall δεν φιλτράρει τις συνδέσεις.

### Αφαίρεση

Διαγράψτε τον αποσυμπιεσμένο φάκελο του έργου. Για να αφαιρέσετε και τα δεδομένα χρήστη:

```bash
rm -rf "$HOME/Chakravyuh-Reports" "$HOME/.config/chakravyuh"
```

Ελέγξτε την εντολή πριν την εκτέλεση. Διαγράφει μόνιμα τις αναφορές και την αποθηκευμένη προτίμηση γλώσσας.

### Ασφάλεια και υπεύθυνη χρήση

Διαβάστε το `SECURITY.md`. Μην ελέγχετε συστήματα τρίτων χωρίς άδεια. Μην δημοσιεύετε αναφορές με προσωπικά δεδομένα, εσωτερικές διευθύνσεις, tokens ή ευαίσθητα αποτελέσματα. Το έργο προορίζεται για προσωπικά διαγνωστικά, εκπαίδευση, ελεγχόμενα εργαστήρια και εξουσιοδοτημένη εργασία ασφάλειας.

### Άδεια

MIT. Δείτε το `LICENSE`.
