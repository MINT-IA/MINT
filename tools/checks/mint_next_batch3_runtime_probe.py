#!/usr/bin/env python3
"""Execute Batch 3 browser semantics; screenshots/static greps are insufficient."""
from __future__ import annotations
import argparse,shutil,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlencode
HTML=Path('product/mint_next/batch3/prototype/index.html')

def chrome():
 for x in (shutil.which('google-chrome'),shutil.which('chromium'),'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'):
  if x and Path(x).exists():return x
 return None
def dump(binary,source,query,profile=None,width=1280):
 args=[binary,'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check','--window-size='+str(width)+',700','--dump-dom']
 if profile:args.append('--user-data-dir='+str(profile))
 proc=subprocess.run(args+[source+'?'+urlencode(query)],capture_output=True,text=True,timeout=30)
 if proc.returncode or '<body' not in proc.stdout or (width==320 and 'data-horizontal-overflow=' not in proc.stdout):
  proc=subprocess.run(args+[source+'?'+urlencode(query)],capture_output=True,text=True,timeout=30)
 return proc
def require(proc,expected,label):
 missing=[x for x in expected if x not in proc.stdout]
 forbidden=[x for x in ('B1-FX-01','CHF 1’500','108’000','2’400','Léa','CHF 2’166.59') if x in proc.stdout]
 if proc.returncode or missing or forbidden:
  print(f'ERROR mint_next_batch3_runtime_probe: {label} missing={missing} forbidden={forbidden} stderr={proc.stderr[-300:]}',file=sys.stderr);return False
 return True
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=Path.cwd());a=ap.parse_args();binary=chrome()
 if not binary:print('ERROR mint_next_batch3_runtime_probe: Chrome required',file=sys.stderr);return 1
 source=(a.root.resolve()/HTML).as_uri()
 matrix=dump(binary,source,{'probe':'matrix'},width=320)
 if not require(matrix,['data-matrix-count="18"','data-matrix-overflow="false"','data-matrix-missing-heading="false"'], '18-state-matrix@320'):return 1
 cases=[]
 for d in 'abc':
  cases += [
   (d,'result',{'direction':d,'step':4},['CHF 2’104','B2-VD-3A-2026-01','Écart fiscal indicatif du scénario','non personnalisé']),
   (d,'invalidate',{'direction':d,'probe':'correction_invalidation'},['5 / 6','id="invalidated"','Recalcul indisponible dans ce prototype','Montant masqué','data-rendered-result-visible="false"']),
   (d,'disclosure',{'direction':d,'probe':'disclosure'},['aria-modal="true"','version visible 10.4.0','Source officielle ACI Vaud','aucune API vaudoise supportée ou licenciée']),
   (d,'back-restores',{'direction':d,'probe':'back'},['4 / 6','CHF 2’104'])]
 def execute(case):
  d,label,query,expected=case;p=dump(binary,source,query);return require(p,expected,f'{d}-{label}')
 with ThreadPoolExecutor(max_workers=6) as pool:
  if not all(pool.map(execute,cases)):return 1
 persisted=dump(binary,source,{'probe':'save_all'})
 if not require(persisted,['data-persisted-direction-count="3"'],'three-direction-save-reload'):return 1
 print('OK mint_next_batch3_runtime_probe: 18 states, 320px, results, disclosure, invalidation, back, and persisted return executed.',file=sys.stderr);return 0
if __name__=='__main__':raise SystemExit(main())
