import requests
import json
import os
import time
from datetime import datetime

# === CONFIGURATION ===
YEAR = 2025
OUTPUT_DIR = "../assets/data/tax"
LOG_FILE = "tax_fetch.log"

# Liste officielle des cantons suisses (ordre standard)
CANTONS = [
    "ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL", "ZG", "FR", "SO", "BS", "BL", "SH", "AR", "AI", "SG", "GR", "AG", "TG", "TI", "VD", "VS", "NE", "GE", "JU"
]

# API Endpoints (Reverse-Engineered form ESTV Tax Calculator)
# Note: These might change. If script fails, check network tab on https://swisstaxcalculator.estv.admin.ch
BASE_URL = "https://swisstaxcalculator.estv.admin.ch/api/taxscalestaxrates"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Content-Type": "application/json;charset=UTF-8",
    "Origin": "https://swisstaxcalculator.estv.admin.ch",
    "Referer": "https://swisstaxcalculator.estv.admin.ch/"
}

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")
    try:
        with open(LOG_FILE, "a", encoding='utf-8') as f:
            f.write(f"[{datetime.now().isoformat()}] {msg}\n")
    except Exception:
        pass # Ignore logging errors to keep script running

def fetch_multipliers():
    log("Fetching Tax Multipliers for {YEAR} (Whole CH)...")
    try:
        # Same heuristic logic as before
        pass 
    except Exception as e:
        log(f"Error fetching multipliers: {e}")

def create_scraper_instruction():
    pass

# === THE REAL SCRIPT ===

def fetch_canton_scales(canton_code):
    log(f"Fetching scales for {canton_code}...")
    
    url = f"{BASE_URL}/tax-scales/{YEAR}/{canton_code}"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            save_json(data, f"tax_scales_{YEAR}_{canton_code}.json")
            log(f"Success for {canton_code}")
        else:
            log(f"Failed for {canton_code}: {response.status_code}")
            attempt_post_fetch(canton_code)
            
    except Exception as e:
        log(f"Exception for {canton_code}: {e}")

def attempt_post_fetch(canton_code):
    log(f"   -> Trying POST method for {canton_code}...")
    url = f"{BASE_URL}/search" 
    payload = {
        "year": YEAR,
        "canton": canton_code,
        "type": "income"
    }
    try:
        response = requests.post(url, json=payload, headers=HEADERS, timeout=10)
        if response.status_code == 200:
            save_json(response.json(), f"tax_scales_{YEAR}_{canton_code}.json")
            log(f"   POST Success for {canton_code}")
        else:
            log(f"   POST Failed: {response.text[:100]}")
    except Exception as e:
         log(f"   POST Exception: {e}")

def save_json(data, filename):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

def main():
    print(f"=== MINT TAX HARVESTER {YEAR} ===")
    print(f"Target: ESTV Admin ({BASE_URL})")
    print("-----------------------------------")
    
    for canton in CANTONS:
        fetch_canton_scales(canton)
        time.sleep(1) 
        
    print("-----------------------------------")
    print("Harvest complete. Check log file.")

if __name__ == "__main__":
    main()
