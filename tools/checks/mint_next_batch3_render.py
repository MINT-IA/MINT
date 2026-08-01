#!/usr/bin/env python3
"""Reproduce Batch 3 visual evidence; images are not user/a11y validation."""
from __future__ import annotations
import argparse,hashlib,shutil,subprocess,sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlencode
import yaml
HTML=Path('product/mint_next/batch3/prototype/index.html'); OUT=Path('product/mint_next/batch3/evidence/renders'); RECEIPT=Path('product/mint_next/batch3/evidence/render-20260801.yaml')
def chrome():
 for x in (shutil.which('google-chrome'),shutil.which('chromium'),'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'):
  if x and Path(x).exists():return x
 return None
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=Path.cwd());ap.add_argument('--write',action='store_true');a=ap.parse_args();root=a.root.resolve();binary=chrome()
 if not binary:print('ERROR renderer: Chrome required',file=sys.stderr);return 1
 cases=[]
 result_steps={'a':4,'b':3,'c':4}
 for viewport,(w,h) in {'component320':(320,700),'desktop1280':(1280,900)}.items():
  for d in 'abc':
   for state,query in {'result':{'direction':d,'step':result_steps[d]},'disclosure':{'direction':d,'probe':'disclosure'},'invalidated':{'direction':d,'probe':'correction_invalidation'}}.items():cases.append((viewport,w,h,d,state,query))
 out=root/OUT;out.mkdir(parents=True,exist_ok=True);source=(root/HTML).as_uri()
 def render(case):
  viewport,w,h,d,state,query=case;p=out/f'{viewport}-{d}-{state}.png';proc=subprocess.run([binary,'--headless=new','--disable-gpu','--no-first-run','--no-default-browser-check',f'--window-size={w},{h}',f'--screenshot={p}',source+'?'+urlencode(query)],capture_output=True,text=True,timeout=30);return p,proc
 with ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(render,cases))
 bad=[(p,r.returncode,r.stderr[-200:]) for p,r in results if r.returncode or not p.is_file() or p.stat().st_size<1000]
 if bad:print(f'ERROR renderer: {bad}',file=sys.stderr);return 1
 artifacts={p.name:{'path':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p,_ in results}
 receipt={'schema_version':1,'status':'local_render_evidence_not_user_or_accessibility_validation','renderer':'Google Chrome headless','source':str(HTML),'viewports':{'component320':'320px_constrained_component_in_headless_chrome','desktop1280':'1280x900'},'states':['result','disclosure','invalidated'],'directions':['a','b','c'],'artifacts':dict(sorted(artifacts.items())),'claims':{'all_18_targeted_renders_created_not_all_18_journey_states':True,'user_validated':False,'accessibility_validated_by_screenshots':False,'winner_selected':False}}
 if a.write:(root/RECEIPT).write_text(yaml.safe_dump(receipt,sort_keys=False,allow_unicode=True),encoding='utf-8')
 elif not (root/RECEIPT).is_file() or yaml.safe_load((root/RECEIPT).read_text())!=receipt:print('ERROR renderer: receipt drift; run --write after intentional review',file=sys.stderr);return 1
 print('OK mint_next_batch3_render: 18 deterministic evidence images match receipt.',file=sys.stderr);return 0
if __name__=='__main__':raise SystemExit(main())
