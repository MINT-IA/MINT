import asyncio
import json
import os
import random
from playwright.async_api import async_playwright

# Configuration
YEAR = "2025"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "../assets/config/tax_scales.json")
BASE_URL = "https://swisstaxcalculator.estv.admin.ch/#/taxdata/tax-scales"

# Liste complète
CANTONS = [
    "Zurich", "Bern", "Lucerne", "Uri", "Schwyz", "Obwalden", "Nidwalden", 
    "Glarus", "Zug", "Fribourg", "Solothurn", "Basel-Stadt", "Basel-Landschaft", 
    "Schaffhausen", "Appenzell A. Rh.", "Appenzell I. Rh.", "St. Gallen", 
    "Graubünden", "Aargau", "Thurgau", "Ticino", "Vaud", "Valais", 
    "Neuchâtel", "Geneva", "Jura"
]

async def extract_one_canton(browser, canton):
    page = await browser.new_page()
    try:
        print(f"   🌍 Loading page for {canton}...")
        # wait_until='networkidle' est souvent trop strict sur les SPAs bavardes,
        # 'domcontentloaded' + wait_for_selector est mieux.
        await page.goto(BASE_URL) 
        
        # Attendre le chargement initial critique
        await page.wait_for_selector(".radio-card", timeout=20000)
        await page.wait_for_timeout(1000) # Stabilisation

        # 1. Année
        try:
            # On cherche le label 2024.
            # L'UI met la classe 'checked' si sélectionné.
            # On clique forcement pour être sûr.
            await page.click(f".radio-card[aria-label='{YEAR}']", timeout=3000)
            await page.wait_for_timeout(500)
        except:
            pass # Peut-être déjà actif ou hors viewport immédiat (mais playwright scroll)

        # 2. Revenu (Income tax)
        try:
            await page.click(".radio-card[aria-label='Income tax']", timeout=3000)
            await page.wait_for_timeout(500)
        except:
            pass

        # 3. Canton
        # On clique sur le canton
        await page.click(f".radio-card[aria-label='{canton}']", timeout=5000)
        await page.wait_for_timeout(500)
        
        # 4. Submit
        submit_btn = page.locator("button.taxdata-form__button-submit")
        await submit_btn.click()
        
        # 5. Wait for Grid
        # On attend que la grille soit visible.
        # Si le serveur lag, ça peut prendre du temps.
        await page.wait_for_selector(".ag-center-cols-container .ag-row", timeout=20000)
        
        # Petite pause pour s'assurer que TOUTES les lignes sont rendues (virtual scrolling ?)
        # Ag-grid virtualise, mais "Extract Tax Rates" exporte souvent tout.
        # Ici on scrape le DOM. Si virtualisé, on risque d'en manquer.
        # Astuce: Le DOM contient souvent tout si la liste est petite (<100 lignes).
        await page.wait_for_timeout(2000)

        # Extraction logic
        rows = await page.evaluate("""() => {
            const rowNodes = document.querySelectorAll('.ag-center-cols-container .ag-row');
            const extracted = [];
            rowNodes.forEach(row => {
                const cells = row.querySelectorAll('.ag-cell-value');
                const rowData = Array.from(cells).map(cell => cell.innerText.trim());
                if (rowData.length > 0) extracted.push(rowData);
            });
            return extracted;
        }""")
        
        return rows

    finally:
        await page.close()

async def run():
    print(f"🚀 Starting ROBUST Extraction for {YEAR}...")
    
    # Load existing
    data = {}
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                print(f"📦 Resuming from {len(data)} cantons.")
        except:
            pass

    async with async_playwright() as p:
        # Launch Browser
        # On relance le browser périodiquement si besoin, mais ici on va garder une session
        browser = await p.chromium.launch(headless=False)
        
        for i, canton in enumerate(CANTONS):
            if canton in data:
                continue

            print(f"📍 [{i+1}/{len(CANTONS)}] Processing {canton}...")
            
            success = False
            for attempt in range(3):
                try:
                    rows = await extract_one_canton(browser, canton)
                    if rows and len(rows) > 0:
                        data[canton] = rows
                        print(f"✅ Success {canton}: {len(rows)} brackets.")
                        
                        # Save
                        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
                            json.dump(data, f, indent=2, ensure_ascii=False)
                        
                        success = True
                        break
                    else:
                        print(f"⚠️ Attempt {attempt+1}: No rows found.")
                except Exception as e:
                    print(f"⚠️ Attempt {attempt+1} error: {e}")
                    await asyncio.sleep(2) # Coolddown
            
            if not success:
                print(f"❌ FAILED {canton} after 3 attempts.")
        
        await browser.close()

if __name__ == "__main__":
    asyncio.run(run())
