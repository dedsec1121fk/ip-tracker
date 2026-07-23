# Chakravyuh Red Team & OSINT Suite 4.3.0

Chakravyuh is a bilingual English/Greek command-line framework for passive OSINT, security assessment, and explicitly authorized red-team validation. The application itself is contained in one executable file, `chakravyuh.sh`. Python code is embedded in the Bash launcher and is not shipped as separate modules.

The framework does not run active checks automatically. Port scanning, SMTP verification, DNS zone transfer, directory discovery, and reverse-shell payload generation require an explicit authorization confirmation or the `--authorized` command-line flag.

---

## English

### Requirements

- Android with Termux, Linux, or macOS
- Internet access for online OSINT sources and first-time package installation
- Python 3

When Python 3 is missing, the launcher attempts to install it through Termux `pkg`, APT, DNF, YUM, Pacman, APK, Zypper, or Homebrew. On first use, the script checks the actual Python import names and attempts to install only the missing packages:

- `requests`
- `dnspython`
- `phonenumbers`
- `python-whois`
- `beautifulsoup4`
- `qrcode`
- `Pillow`

If normal and user-level package installation are unavailable, the installer also tries an application-local package directory under `~/.local/share/chakravyuh/python-packages`. If every installation method fails, the program remains usable in a reduced fallback mode. Basic HTTP requests, IP resolution, limited DNS lookup, basic phone normalization, reports, and offline tests still work where possible.

### Termux installation

```bash
pkg update -y
pkg install -y unzip
cd ~/storage/downloads
unzip -o chakravyuh-fixed-v4.3.0.zip
cd chakravyuh-fixed-v4.3.0
chmod +x chakravyuh.sh
./chakravyuh.sh
```

Termux storage access may be enabled with:

```bash
termux-setup-storage
```

### Linux and macOS

```bash
unzip chakravyuh-fixed-v4.3.0.zip
cd chakravyuh-fixed-v4.3.0
chmod +x chakravyuh.sh
./chakravyuh.sh
```

### Language

The language is selected on first launch and saved in the local configuration.

```bash
./chakravyuh.sh language en
./chakravyuh.sh language gr
./chakravyuh.sh --language el menu
```

`gr` and `el` both select Greek.

### Main commands

```text
myip                         Show public IP information
ip TARGET                    IP/domain geolocation, RDAP, and WHOIS
dns TARGET                   DNS enumeration
subdomain TARGET             Certificate-transparency subdomains
email EMAIL                  Format, MX, and HIBP breach check
phone NUMBER                 Phone validation and normalization
username USERNAME            Username indicators across public platforms
mac MAC                      MAC vendor lookup
asn IP|ASN                   ASN and prefix information
ssl TARGET                   TLS certificate analysis
headers URL                  HTTP security-header audit
tech URL                     Web technology fingerprint
metadata FILE                EXIF/metadata extraction
vt-hash HASH                 VirusTotal hash report
shodan TARGET                Shodan host report
censys TARGET                Censys host report
dork QUERY                   Generate a Google search URL
pastebin KEYWORD             Search Pastebin references with fallback URL
qr TEXT                      Generate a QR image
reports                      Browse locally saved reports
doctor                       Check dependencies and storage paths
self-test                    Run offline functional tests
```

Commands are case-sensitive; use `dns`, not `DNS`.

### Authorized active checks

```bash
./chakravyuh.sh email-verify user@example.com --authorized
./chakravyuh.sh scan 192.168.1.10 --ports 22,80,443 --authorized --banner
./chakravyuh.sh zone-transfer example.internal --authorized
./chakravyuh.sh dirb https://test.example --wordlist words.txt --authorized
./chakravyuh.sh reverse --lhost 10.0.0.5 --lport 4444 --type bash --authorized
```

The `--authorized` flag is an acknowledgement, not proof of permission. Keep written scope and rules of engagement for every assessment.

The scanner accepts individual ports and ranges, for example `22,80,443,8000-8010`. A maximum of 256 unique ports is enforced per run. IPv4 and IPv6 targets are supported where the operating system and target permit them.

Directory discovery reads at most 10,000 unique entries per run and filters common soft-404 responses. It reports useful success, redirect, authentication-required, and forbidden responses.

Reverse-shell output is generated as text only. Chakravyuh does not execute the payload. Use this module only in an isolated lab or a specifically authorized engagement.

### API keys

Keys are entered through a hidden prompt and stored in:

```text
~/.config/chakravyuh/apikeys.json
```

The file is written with owner-only permissions where the operating system supports POSIX permissions.

Configure keys interactively:

```bash
./chakravyuh.sh apikey shodan
./chakravyuh.sh apikey virustotal
./chakravyuh.sh apikey hibp
./chakravyuh.sh apikey censys
./chakravyuh.sh apikey censys-org
```

Remove a key:

```bash
./chakravyuh.sh apikey-remove shodan
```

Supported values:

- `shodan`: Shodan API key
- `virustotal`: VirusTotal API key
- `hibp`: Have I Been Pwned API key
- `censys` or `censys-pat`: Censys Platform Personal Access Token
- `censys-org`: optional Censys organization ID

Chakravyuh uses the current Censys Platform host endpoint with Bearer-token authentication. Existing `censys_id` and `censys_secret` values from older configurations are retained as a legacy fallback. HIBP account lookup is not attempted without an HIBP API key, so the tool will never incorrectly claim that an address is breach-free merely because authentication failed.

Official references:

- Shodan API: https://developer.shodan.io/api
- VirusTotal API: https://docs.virustotal.com/reference/overview
- HIBP API: https://haveibeenpwned.com/API/v3
- Censys API: https://docs.censys.com/reference/get-started

Follow each provider's terms, quotas, and licensing requirements. API access and available fields vary by account tier.

### Reports and privacy

Reports are JSON files stored by default in:

```text
~/Chakravyuh-Reports/
```

QR images are stored in the same directory. Report and image files use owner-only permissions when supported. Change the report location for one invocation with:

```bash
CHAKRAVYUH_REPORT_DIR="$HOME/my-assessment" ./chakravyuh.sh ip 8.8.8.8
```

The program has no analytics or hidden telemetry. Data is sent only to the online service required by the selected module. For example, an IP lookup sends the selected IP to the configured geolocation or RDAP provider, and a Shodan lookup sends the target to Shodan.

Do not commit the configuration directory, API keys, private reports, customer targets, evidence, or engagement wordlists to a public repository.

### Automatic installation controls

Disable Python package installation:

```bash
CHAKRAVYUH_NO_AUTO_INSTALL=1 ./chakravyuh.sh --no-install doctor
```

Check the current environment:

```bash
./chakravyuh.sh doctor
```

The `doctor` command exits with a non-zero status when one or more optional packages remain unavailable.

### JSON output

Most commands support machine-readable output:

```bash
./chakravyuh.sh --json ip 8.8.8.8
```

The JSON result is written to standard output. The saved report path is written to standard error so it does not corrupt piped JSON.

### Offline self-test

```bash
./chakravyuh.sh self-test
```

The self-test validates parsing, a local TCP scan, filesystem operations, and core internal behavior. It deliberately does not contact public APIs, so it can run offline and does not consume API credits.

### Troubleshooting

**Permission denied**

```bash
chmod +x chakravyuh.sh
```

**Python package installation fails**

```bash
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade requests dnspython phonenumbers python-whois beautifulsoup4 qrcode Pillow
```

On Debian/Ubuntu, `python3-pip` and `python3-venv` may also be required.

**Termux cannot access a file**

Run `termux-setup-storage` and use a path under `~/storage/shared` or `~/storage/downloads`.

**HIBP always reports that a key is required**

Save a valid HIBP key with `./chakravyuh.sh apikey hibp`. The authenticated breached-account endpoint does not support anonymous requests.

**Censys authentication fails**

Create a Censys Platform Personal Access Token and save it with `./chakravyuh.sh apikey censys`. Organization accounts may also require the organization ID.

**Username search produces a questionable match**

Username results are indicators, not identity proof. Open the returned profile and verify context manually.

**SMTP verification says a mailbox is not verified**

Most mail servers disable or intentionally obscure `VRFY`. A negative or ambiguous result does not prove that the mailbox does not exist.

---

## Ελληνικά

### Απαιτήσεις

- Android με Termux, Linux ή macOS
- Σύνδεση στο διαδίκτυο για online OSINT πηγές και την αρχική εγκατάσταση πακέτων
- Python 3

Όταν λείπει το Python 3, το launcher προσπαθεί να το εγκαταστήσει μέσω Termux `pkg`, APT, DNF, YUM, Pacman, APK, Zypper ή Homebrew. Στην πρώτη χρήση, το script ελέγχει τα πραγματικά ονόματα εισαγωγής των Python modules και εγκαθιστά μόνο όσα λείπουν:

- `requests`
- `dnspython`
- `phonenumbers`
- `python-whois`
- `beautifulsoup4`
- `qrcode`
- `Pillow`

Αν δεν είναι διαθέσιμη η κανονική ή user-level εγκατάσταση, ο installer δοκιμάζει επίσης τοπικό φάκελο `~/.local/share/chakravyuh/python-packages`. Αν αποτύχουν όλες οι μέθοδοι, το πρόγραμμα συνεχίζει σε περιορισμένη λειτουργία. Βασικά HTTP requests, επίλυση IP, περιορισμένο DNS lookup, βασική κανονικοποίηση τηλεφώνου, αναφορές και offline tests παραμένουν διαθέσιμα όπου είναι δυνατό.

### Εγκατάσταση στο Termux

```bash
pkg update -y
pkg install -y unzip
cd ~/storage/downloads
unzip -o chakravyuh-fixed-v4.3.0.zip
cd chakravyuh-fixed-v4.3.0
chmod +x chakravyuh.sh
./chakravyuh.sh
```

Για πρόσβαση στα αρχεία του Android:

```bash
termux-setup-storage
```

### Linux και macOS

```bash
unzip chakravyuh-fixed-v4.3.0.zip
cd chakravyuh-fixed-v4.3.0
chmod +x chakravyuh.sh
./chakravyuh.sh
```

### Γλώσσα

Η γλώσσα επιλέγεται στην πρώτη εκτέλεση και αποθηκεύεται τοπικά.

```bash
./chakravyuh.sh language en
./chakravyuh.sh language gr
./chakravyuh.sh --language el menu
```

Τα `gr` και `el` επιλέγουν Ελληνικά.

### Βασικές εντολές

```text
myip                         Εμφάνιση δημόσιας IP
ip TARGET                    Γεωεντόπιση, RDAP και WHOIS
dns TARGET                   Εγγραφές DNS
subdomain TARGET             Υποτομείς μέσω certificate transparency
email EMAIL                  Έλεγχος μορφής, MX και HIBP
phone NUMBER                 Έλεγχος και κανονικοποίηση τηλεφώνου
username USERNAME            Ενδείξεις username σε δημόσιες πλατφόρμες
mac MAC                      Κατασκευαστής MAC
asn IP|ASN                   ASN και prefixes
ssl TARGET                   Ανάλυση πιστοποιητικού TLS
headers URL                  Έλεγχος HTTP security headers
tech URL                     Αναγνώριση τεχνολογίας web
metadata FILE                Εξαγωγή EXIF/metadata
vt-hash HASH                 Αναφορά VirusTotal
shodan TARGET                Αναφορά Shodan
censys TARGET                Αναφορά Censys
dork QUERY                   Δημιουργία Google search URL
pastebin KEYWORD             Αναζήτηση αναφορών Pastebin
qr TEXT                      Δημιουργία QR
reports                      Προβολή τοπικών αναφορών
doctor                       Έλεγχος εξαρτήσεων και paths
self-test                    Offline λειτουργικός έλεγχος
```

Οι εντολές είναι case-sensitive. Χρησιμοποιήστε `dns`, όχι `DNS`.

### Ενεργοί έλεγχοι με εξουσιοδότηση

```bash
./chakravyuh.sh email-verify user@example.com --authorized
./chakravyuh.sh scan 192.168.1.10 --ports 22,80,443 --authorized --banner
./chakravyuh.sh zone-transfer example.internal --authorized
./chakravyuh.sh dirb https://test.example --wordlist words.txt --authorized
./chakravyuh.sh reverse --lhost 10.0.0.5 --lport 4444 --type bash --authorized
```

Το `--authorized` είναι επιβεβαίωση του χρήστη και όχι απόδειξη άδειας. Διατηρείτε γραπτό scope και rules of engagement για κάθε έλεγχο.

Η σάρωση δέχεται μεμονωμένες θύρες και ranges, όπως `22,80,443,8000-8010`. Υπάρχει όριο 256 μοναδικών TCP θυρών ανά εκτέλεση. Υποστηρίζονται IPv4 και IPv6 όπου το επιτρέπουν το λειτουργικό και ο στόχος.

Το directory discovery διαβάζει έως 10.000 μοναδικές εγγραφές και φιλτράρει συνηθισμένα soft-404 responses. Αναφέρει επιτυχίες, redirects, authentication-required και forbidden responses.

Το reverse-shell module παράγει μόνο κείμενο. Δεν εκτελεί το payload. Χρησιμοποιήστε το μόνο σε απομονωμένο lab ή σε συγκεκριμένα εξουσιοδοτημένο engagement.

### API keys

Τα κλειδιά εισάγονται μέσω κρυφού prompt και αποθηκεύονται στο:

```text
~/.config/chakravyuh/apikeys.json
```

Όπου υποστηρίζονται POSIX permissions, το αρχείο είναι αναγνώσιμο μόνο από τον ιδιοκτήτη.

```bash
./chakravyuh.sh apikey shodan
./chakravyuh.sh apikey virustotal
./chakravyuh.sh apikey hibp
./chakravyuh.sh apikey censys
./chakravyuh.sh apikey censys-org
```

Αφαίρεση κλειδιού:

```bash
./chakravyuh.sh apikey-remove shodan
```

Υποστηριζόμενες υπηρεσίες:

- `shodan`: Shodan API key
- `virustotal`: VirusTotal API key
- `hibp`: Have I Been Pwned API key
- `censys` ή `censys-pat`: Censys Platform Personal Access Token
- `censys-org`: προαιρετικό Censys organization ID

Το Chakravyuh χρησιμοποιεί το σύγχρονο Censys Platform host endpoint με Bearer token. Παλιές τιμές `censys_id` και `censys_secret` διατηρούνται μόνο ως legacy fallback. Η αναζήτηση λογαριασμού HIBP δεν εκτελείται χωρίς HIBP API key, ώστε να μη δηλώνεται λανθασμένα ότι ένα email δεν έχει παραβιαστεί όταν στην πραγματικότητα απέτυχε η πιστοποίηση.

Επίσημη τεκμηρίωση:

- Shodan API: https://developer.shodan.io/api
- VirusTotal API: https://docs.virustotal.com/reference/overview
- HIBP API: https://haveibeenpwned.com/API/v3
- Censys API: https://docs.censys.com/reference/get-started

Τηρείτε τους όρους, τα quotas και τις άδειες κάθε υπηρεσίας. Τα διαθέσιμα δεδομένα διαφέρουν ανάλογα με το account tier.

### Αναφορές και ιδιωτικότητα

Οι αναφορές αποθηκεύονται ως JSON στο:

```text
~/Chakravyuh-Reports/
```

Τα QR images αποθηκεύονται στον ίδιο φάκελο. Όπου υποστηρίζεται, τα αρχεία γράφονται με owner-only permissions.

```bash
CHAKRAVYUH_REPORT_DIR="$HOME/my-assessment" ./chakravyuh.sh ip 8.8.8.8
```

Το πρόγραμμα δεν διαθέτει analytics ή κρυφή τηλεμετρία. Δεδομένα στέλνονται μόνο στην online υπηρεσία που απαιτεί το module που επέλεξε ο χρήστης.

Μην ανεβάζετε σε δημόσιο repository API keys, ιδιωτικές αναφορές, customer targets, evidence ή wordlists engagement.

### Έλεγχος αυτόματης εγκατάστασης

```bash
CHAKRAVYUH_NO_AUTO_INSTALL=1 ./chakravyuh.sh --no-install doctor
```

```bash
./chakravyuh.sh doctor
```

Το `doctor` επιστρέφει non-zero exit status όταν παραμένουν μη διαθέσιμα πακέτα.

### JSON output

```bash
./chakravyuh.sh --json ip 8.8.8.8
```

Το JSON γράφεται στο standard output και το path της αναφοράς στο standard error, ώστε να μη χαλάει το piped JSON.

### Offline αυτοέλεγχος

```bash
./chakravyuh.sh self-test
```

Ο αυτοέλεγχος εξετάζει parsing, τοπική TCP σάρωση, filesystem και βασική εσωτερική λειτουργία. Δεν καλεί δημόσια APIs και δεν καταναλώνει API credits.

### Αντιμετώπιση προβλημάτων

**Permission denied**

```bash
chmod +x chakravyuh.sh
```

**Αποτυχία εγκατάστασης Python packages**

```bash
python3 -m ensurepip --upgrade
python3 -m pip install --upgrade requests dnspython phonenumbers python-whois beautifulsoup4 qrcode Pillow
```

Σε Debian/Ubuntu μπορεί να χρειάζονται και τα `python3-pip` και `python3-venv`.

**Το Termux δεν διαβάζει ένα αρχείο**

Εκτελέστε `termux-setup-storage` και χρησιμοποιήστε path κάτω από `~/storage/shared` ή `~/storage/downloads`.

**Το HIBP ζητά πάντα API key**

Αποθηκεύστε έγκυρο κλειδί με `./chakravyuh.sh apikey hibp`. Το authenticated breached-account endpoint δεν δέχεται anonymous requests.

**Αποτυχία Censys authentication**

Δημιουργήστε Censys Platform Personal Access Token και αποθηκεύστε το με `./chakravyuh.sh apikey censys`. Organization accounts μπορεί να χρειάζονται και organization ID.

**Αμφίβολο αποτέλεσμα username**

Τα αποτελέσματα username είναι ενδείξεις και όχι απόδειξη ταυτότητας. Ανοίξτε το profile και επιβεβαιώστε χειροκίνητα το context.

**Αρνητικό SMTP verification**

Οι περισσότεροι mail servers απενεργοποιούν ή παραποιούν σκόπιμα το `VRFY`. Ένα αρνητικό αποτέλεσμα δεν αποδεικνύει ότι το mailbox δεν υπάρχει.
