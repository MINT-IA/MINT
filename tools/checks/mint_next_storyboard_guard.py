#!/usr/bin/env python3
"""Fail closed: the storyboard can describe targets, never manufacture proof."""
import hashlib, importlib.util, json, re, subprocess, sys, tempfile
from pathlib import Path
import jsonschema

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'product/mint_next/storyboard'
SOURCE=BASE/'three_a.storyboard.json'; SCHEMA=BASE/'storyboard.contract.schema.json'; HTML=BASE/'index.html'
RENDERER=ROOT/'tools/storyboard/render_mint_storyboard.py'
SHA256=re.compile(r'^[0-9a-f]{64}$'); SHA40=re.compile(r'^[0-9a-f]{40}$')
TOP={'schema_version','goal','generated_at','phase_authority','design_authority','field_ownership','novice_validation','entry_scene','happy_path','branches','decisions','scenes'}
SCENE={'id','chapter','title','summary','user_sees','user_understands','primary_action','data','architecture','transitions','target','observations','evidence'}
BAD_TEXT=(re.compile(r'https?://',re.I),re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),re.compile(r'(^|["\s:])/(?:Users|private|etc|var|tmp)/'))

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def confined(root, raw, kind='file'):
    if not isinstance(raw,str) or not raw or '\\' in raw or raw.startswith(('/', '~')) or '..' in Path(raw).parts:
        return None
    try: p=(root/raw).resolve(); p.relative_to(root.resolve())
    except (OSError,ValueError): return None
    if p.is_symlink(): return None
    return p if (p.is_file() if kind=='file' else p.exists()) else None

def pinned_file(root, item, errors, label):
    if not isinstance(item,dict) or set(item) not in ({'path','sha256'},{'path','sha256','role'}) or not SHA256.fullmatch(str(item.get('sha256',''))):
        errors.append(f'{label}: pin fermé invalide'); return None
    p=confined(root,item['path'])
    if not p or digest(p)!=item['sha256']: errors.append(f'{label}: source absente ou hash divergent'); return None
    return p

def validate_schema(root=ROOT):
    errors=[]
    try: s=json.loads((root/'product/mint_next/storyboard/storyboard.contract.schema.json').read_text(),object_pairs_hook=no_duplicates)
    except Exception as e: return [f'schema illisible: {e}']
    try: jsonschema.Draft202012Validator.check_schema(s)
    except jsonschema.SchemaError as issue: errors.append(f'schema JSON Schema invalide: {issue.message}')
    if s.get('$id')!='mint-next-storyboard-v3' or s.get('additionalProperties') is not False or set(s.get('required',[]))!=TOP or set(s.get('properties',{}))!=TOP:
        errors.append('schema racine non équivalent au contrat fermé v3')
    def walk(node,where='$'):
        if isinstance(node,dict):
            if node.get('type')=='object' and node.get('additionalProperties') is not False:
                errors.append(f'schema ouvert interdit: {where}')
            for k,v in node.items(): walk(v,f'{where}/{k}')
        elif isinstance(node,list):
            for i,v in enumerate(node): walk(v,f'{where}/{i}')
    walk(s)
    return errors

def validate_receipt(root,item,keys,label,platform=False):
    if not isinstance(item,dict) or set(item)!=keys: return f'{label}: reçu fermé invalide'
    p=confined(root,item.get('path'))
    if not p or not SHA256.fullmatch(str(item.get('sha256',''))) or digest(p)!=item['sha256']: return f'{label}: faux path/hash'
    if 'product_sha' in keys and not SHA40.fullmatch(str(item.get('product_sha',''))): return f'{label}: SHA produit invalide'
    if platform and item.get('platform') not in {'ios','android'}: return f'{label}: plateforme invalide'
    return None

def resolve_phase(data,root=ROOT):
    pin=data['phase_authority']; p=confined(root,pin.get('path'))
    if not p or digest(p)!=pin.get('sha256'): raise ValueError('phase authority drift')
    text=p.read_text(); anchor=pin.get('status_anchor')
    if not isinstance(anchor,str) or text.count(anchor)!=1: raise ValueError('phase status anchor absent ou ambigu')
    m=re.match(r'Status: `([a-z_]+)`$',anchor)
    if not m: raise ValueError('phase status anchor invalide')
    return m.group(1)

def derived_axes(data):
    scenes=data['scenes']; novice=data['novice_validation']
    ios=all(any(r['platform']=='ios' for r in s['evidence']['runtime_receipts']) for s in scenes)
    android=all(any(r['platform']=='android' for r in s['evidence']['runtime_receipts']) for s in scenes)
    accessible=all(s['evidence']['code_refs'] and s['evidence']['runtime_receipts'] for s in scenes)
    novices=novice['status']=='passed' and len(novice['observations'])>=2
    showable=ios and android and accessible and novices and all(s['evidence']['exposure_receipts'] for s in scenes)
    return {'Cible':('définie, non prouvée','neutral'),'Accessible':('aucune preuve app','neutral') if not accessible else ('atteignable','pass'),'Novices':('non testé','neutral') if not novices else ('testé','pass'),'iOS':('aucune preuve','neutral') if not ios else ('prouvé','pass'),'Android':('aucune preuve','neutral') if not android else ('prouvé','pass'),'Montrable':('bloqué','blocked') if not showable else ('autorisé','pass')}

def validate_contract(data,root=ROOT):
    e=[]
    if not isinstance(data,dict) or set(data)!=TOP or data.get('schema_version')!=3: return ['contrat racine fermé invalide']
    try:
        schema=json.loads((root/'product/mint_next/storyboard/storyboard.contract.schema.json').read_text())
        for issue in jsonschema.Draft202012Validator(schema).iter_errors(data): e.append(f'schema data: {issue.json_path}: {issue.message}')
    except (OSError,ValueError,jsonschema.SchemaError) as issue: e.append(f'schema data inexécutable: {issue}')
    raw=json.dumps(data,ensure_ascii=False)
    if any(p.search(raw) for p in BAD_TEXT): e.append('réseau, PII ou chemin absolu interdit')
    if set(data['goal'])!={'id','title','promise'}: e.append('goal fermé invalide')
    phase=data['phase_authority']
    if not isinstance(phase,dict) or set(phase)!={'path','sha256','status_anchor'} or not SHA256.fullmatch(str(phase.get('sha256',''))): e.append('phase authority pin invalide')
    else:
        try: resolve_phase(data,root)
        except ValueError as x: e.append(str(x))
    design=data['design_authority']
    if not isinstance(design,dict) or set(design)!={'approved_revision','authority','historical_context'} or not design.get('approved_revision'): e.append('design authority fermée invalide')
    else:
        if design['authority'].get('role')!='authority' or design['historical_context'].get('role')!='historical_context': e.append('deux autorités visuelles concurrentes interdites')
        if design['authority'].get('path')!='docs/brand/mint-v2/tokens.jsx': e.append('tokens.jsx doit être l’unique autorité visuelle')
        pinned_file(root,design['authority'],e,'design tokens authority'); pinned_file(root,design['historical_context'],e,'design handoff historical context')
    owners={}
    for o in data['field_ownership']:
        if not isinstance(o,dict) or not {'field','path','anchor'}<=set(o) or set(o)-{'field','path','anchor','sha256'}: e.append('owner fermé invalide'); continue
        if o['field'] in owners: e.append(f'owner conflict: {o["field"]}')
        owners[o['field']]=o
        p=confined(root,o['path'])
        if not p: e.append(f'owner path invalide: {o["field"]}'); continue
        if o['anchor'] not in p.read_text(errors='replace'): e.append(f'owner anchor absent: {o["field"]}')
        if 'sha256' in o and (not SHA256.fullmatch(o['sha256']) or digest(p)!=o['sha256']): e.append(f'owner pin divergent: {o["field"]}')
    if set(owners)!={'narrative','navigation','phase_status','visual_language','observations'}: e.append('inventaire owners incomplet')
    novice=data['novice_validation']
    if set(novice)!={'status','protocol','observations'} or novice['protocol']!={'readers_required':2,'questions':5,'time_limit_seconds':60}: e.append('contrat novice invalide')
    if novice.get('status')!='not_run' or novice.get('observations')!=[]: e.append('validation novice non prouvée: seul not_run vide est admis dans ce slice')
    if not isinstance(data['decisions'],list) or not data['decisions']: e.append('journal de décision requis')
    else:
        for decision in data['decisions']:
            if not isinstance(decision,dict) or set(decision)!={'id','question','decision','rationale','rejected','revisited_when'} or not all(isinstance(v,str) and v.strip() for v in decision.values()): e.append('décision/discussion fermée invalide')
    scenes=data['scenes']; ids=[s.get('id') for s in scenes]; by={s.get('id'):s for s in scenes}
    if len(ids)!=len(set(ids)): e.append('duplicate scene id')
    happy=data['happy_path']; branches=data['branches']
    if not 5<=len(happy)<=7 or data['entry_scene']!=(happy[0] if happy else None): e.append('happy path/entry invalide')
    if set(branches)!={'missing_data','refusal','zero_choice'} or any(len(v)<2 for v in branches.values()): e.append('branches exactes requises')
    referenced=set(happy)
    for v in branches.values(): referenced.update(v)
    if referenced-set(ids): e.append('destination inconnue dans chemins')
    if set(ids)-referenced: e.append('unreachable scenes')
    def linked(path,label):
        for a,b in zip(path,path[1:]):
            if a not in by or not any(t.get('destination')==b for t in by[a].get('transitions',[])): e.append(f'{label}: transition {a} → {b} absente')
    linked(happy,'happy_path')
    for n,p in branches.items(): linked(p,n)
    expected_edges={(a,b) for path in [happy,*branches.values()] for a,b in zip(path,path[1:])}
    actual_edges={(s['id'],t.get('destination')) for s in scenes for t in s.get('transitions',[])}
    if actual_edges!=expected_edges: e.append('edge set exact divergent: transition cachée, supplémentaire ou absente')
    runtime_claims=set()
    for s in scenes:
        sid=s.get('id','?')
        if set(s)!=SCENE: e.append(f'{sid}: scène fermée invalide'); continue
        if set(s['data'])!={'reads','writes'} or set(s['architecture'])!={'route','state','contract'} or set(s['target'])!={'intention_oracle','observation_oracle'} or set(s['evidence'])!={'code_refs','runtime_receipts','exposure_receipts'}: e.append(f'{sid}: sous-contrat ouvert/incomplet')
        if not all(isinstance(s['target'][k],str) and s['target'][k].strip() for k in s['target']): e.append(f'{sid}: deux oracles cible requis')
        for label,value in [('id',s['id']),('chapter',s['chapter']),('title',s['title']),('summary',s['summary']),('user_sees',s['user_sees']),('user_understands',s['user_understands']),('primary_action',s['primary_action']),('route',s['architecture']['route']),('state',s['architecture']['state']),('contract',s['architecture']['contract'])]:
            if not isinstance(value,str) or not value.strip(): e.append(f'{sid}: chaîne vide interdite ({label})')
        if s['observations']!=[]: e.append(f'{sid}: observation non recevable sans protocole de promotion')
        for t in s['transitions']:
            if not isinstance(t,dict) or set(t)!={'event','destination'} or t.get('destination') not in by: e.append(f'{sid}: destination invalide')
            elif not isinstance(t['event'],str) or not t['event'].strip(): e.append(f'{sid}: event vide interdit')
        for c in s['evidence']['code_refs']:
            err=validate_receipt(root,c,{'path','sha256','symbol'},f'{sid} code'); e.extend([err] if err else [])
            if not str(c.get('path','')).startswith('apps/mobile/') or (confined(root,c.get('path')) and c.get('symbol') not in confined(root,c.get('path')).read_text(errors='replace')): e.append(f'{sid}: code ref non exécutable ou symbole absent')
        for r in s['evidence']['runtime_receipts']:
            err=validate_receipt(root,r,{'path','sha256','product_sha','platform','scene_id'},f'{sid} runtime',True); e.extend([err] if err else [])
            if r.get('scene_id')!=sid: e.append(f'{sid}: receipt runtime emprunté à une autre scène')
            claim=(r.get('path'),r.get('platform'),r.get('scene_id'))
            if claim in runtime_claims: e.append(f'{sid}: receipt scène/plateforme réutilisé')
            runtime_claims.add(claim)
            if not str(r.get('path','')).startswith('.planning/phases/mint-next-vertical01-3a-20260802/evidence/B5/'): e.append(f'{sid}: runtime doit provenir des artefacts B5 acceptés')
            rp=confined(root,r.get('path'))
            if rp:
                try: proof=json.loads(rp.read_text())
                except (ValueError,UnicodeDecodeError): proof={}
                expected={'schema_version':1,'platform':r.get('platform'),'product_sha':r.get('product_sha')}
                if any(proof.get(k)!=v for k,v in expected.items()) or proof.get('scenes',{}).get(sid,{}).get('status')!='pass': e.append(f'{sid}: artefact runtime ne prouve pas cette scène')
        for r in s['evidence']['exposure_receipts']:
            err=validate_receipt(root,r,{'path','sha256','product_sha'},f'{sid} exposure'); e.extend([err] if err else [])
        if s['evidence']['runtime_receipts'] and not s['evidence']['code_refs']: e.append(f'{sid}: runtime sans code vérifié')
        if s['evidence']['exposure_receipts'] and not s['evidence']['runtime_receipts']: e.append(f'{sid}: exposition sans runtime')
        if s['evidence']['exposure_receipts']: e.append(f'{sid}: aucun contrat de promotion Montrable dans ce thin slice')
    if any(s['evidence']['runtime_receipts'] for s in scenes):
        run=subprocess.run([sys.executable,str(root/'tools/checks/mint_next_three_a_batch_acceptance_guard.py'),'--require','B5'],cwd=root,capture_output=True,text=True)
        if run.returncode: e.append('receipt B5 non accepté par le garde cryptographique')
    return e

def renderer():
    spec=importlib.util.spec_from_file_location('storyboard_renderer',RENDERER); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

def render_to(root,out):
    d=json.loads((root/'product/mint_next/storyboard/three_a.storyboard.json').read_text()); out.write_text(renderer().render(d,root),encoding='utf-8')

def validate_render(root=ROOT):
    html_path=root/'product/mint_next/storyboard/index.html'
    if not html_path.is_file(): return ['HTML absent']
    with tempfile.TemporaryDirectory() as t:
        p=Path(t)/'index.html'; render_to(root,p)
        if p.read_bytes()!=html_path.read_bytes(): return ['HTML stale ou édité à la main']
    return validate_html_content(html_path.read_text())

def validate_html_content(raw):
    low=raw.lower()
    if low.count('<style>')!=1 or low.count('</style>')!=1: return ['exactement une feuille CSS inline est requise']
    required=("default-src 'none'",'style-src \'unsafe-inline\'','base-uri \'none\'','form-action \'none\'','id="atlas"','id="episode"','id="dossier"','@media(max-width:360px)','focus-visible','prefers-reduced-motion',':root{')
    if any(x not in low for x in required): return ['CSP, niveaux ou accessibilité statique manquants']
    forbidden=(r'<script\b',r'<link\b',r'<iframe\b',r'<object\b',r'<embed\b',r'<svg\b',r'\son\w+\s*=',r'url\s*\(',r'@import',r'https?://',r'frame-ancestors',r'<style>\s*\+',r'^\+</style')
    if any(re.search(x,low) for x in forbidden): return ['HTML/CSS/SVG/réseau interdit']
    css=low.partition('<style>')[2].partition('</style>')[0]
    if not css or css.count('{')!=css.count('}'): return ['syntaxe CSS manifestement cassée']
    return []

def no_duplicates(pairs):
    d={}
    for k,v in pairs:
        if k in d: raise ValueError(f'clé JSON dupliquée: {k}')
        d[k]=v
    return d

def main():
    try: data=json.loads(SOURCE.read_text(),object_pairs_hook=no_duplicates)
    except Exception as x: raise SystemExit(f'FAIL storyboard: {x}')
    errors=validate_schema()+validate_contract(data)+validate_render()
    if errors: raise SystemExit('FAIL storyboard:\n- '+'\n- '.join(errors))
    print('OK mint_next_storyboard_guard: cible séparée des observations; aucune fausse promotion')
if __name__=='__main__': main()
