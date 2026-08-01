from __future__ import annotations
import shutil, subprocess, sys
from pathlib import Path
import pytest

REPO=Path(__file__).resolve().parents[3]
SCRIPT=REPO/'tools/checks/mint_next_batch3_guard.py'
BASE=Path('product/mint_next/batch3')
UPSTREAM=[
 'product/mint_next/batch1/directions.yaml','product/mint_next/batch1/evaluation.yaml','product/mint_next/batch1/prototype/index.html',
 'product/mint_next/batch2/batch.yaml','product/mint_next/batch2/fixture.yaml','product/mint_next/batch2/sources.yaml',
 'product/mint_next/batch2/evidence/vd-calculator-normalized-receipt-20260801.json','product/mint_next/batch2/evidence/promotion-20260801.yaml']

def copy(tmp_path:Path)->None:
 shutil.copytree(REPO/BASE,tmp_path/BASE)
 for rel in ('tools/checks/mint_next_batch3_runtime_probe.py','tools/checks/mint_next_batch3_render.py'):
  target=tmp_path/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy(REPO/rel,target)
 for rel in UPSTREAM:
  target=tmp_path/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy(REPO/rel,target)

def run(root:Path): return subprocess.run([sys.executable,str(SCRIPT),'--root',str(root)],capture_output=True,text=True)
def mutate(tmp_path:Path,rel:str,old:str,new:str):
 copy(tmp_path);p=tmp_path/BASE/rel;s=p.read_text();assert old in s;p.write_text(s.replace(old,new,1));return run(tmp_path)

def test_current_contract_passes():
 p=run(REPO);assert p.returncode==0,p.stderr
@pytest.mark.parametrize(('rel','old','new','message'),[
 ('scenario.yaml','baseline_taxable_income_icc_chf: 80000','baseline_taxable_income_icc_chf: 108000','scenario'),
 ('scenario.yaml','total_chf: 2104.00','total_chf: 2166.59','scenario'),
 ('scenario.yaml','linked_to_batch1_lea: false','linked_to_batch1_lea: true','persona'),
 ('scenario.yaml','municipality: Lausanne','municipality: Nyon','assumptions'),
 ('scenario.yaml','required_adjacent_labels: [official_indicative','required_adjacent_labels: [exact_personal','display'),
 ('scenario.yaml','hide_all_official_amounts_and_show_recalculation_unavailable_in_prototype','keep_result_visible','correction'),
 ('directions.yaml','state_count: 6','state_count: 5','direction'),
 ('directions.yaml','identical_financial_facts: true','identical_financial_facts: false','equality'),
 ('evaluation-readiness.yaml','participants: 0','participants: 12','user evidence'),
 ('evaluation-readiness.yaml','winner_selected: false','winner_selected: true','user evidence'),
 ('batch.yaml','author_cannot_approve: true','author_cannot_approve: false','promotion'),
 ('batch.yaml','nationwide_tax_claim','nationwide_tax_ready','scope'),
])
def test_rejects_contract_mutation(tmp_path,rel,old,new,message):
 p=mutate(tmp_path,rel,old,new);assert p.returncode==1 and message in p.stderr

def test_rejects_legacy_fixture_in_prototype(tmp_path):
 p=mutate(tmp_path,'prototype/index.html','</body>','CHF 1’500 B1-FX-01 Léa</body>');assert p.returncode==1 and 'legacy' in p.stderr

def test_rejects_upstream_hash_mutation(tmp_path):
 copy(tmp_path);p=tmp_path/'product/mint_next/batch2/fixture.yaml';p.write_text(p.read_text()+'\n');r=run(tmp_path);assert r.returncode==1 and 'upstream hash' in r.stderr

def test_rejects_dead_correction_contract(tmp_path):
 p=mutate(tmp_path,'prototype/index.html','data-critical-edit','data-cosmetic-edit');assert p.returncode==1 and 'runtime hooks' in p.stderr

def test_rejects_false_runtime_user_validation(tmp_path):
 p=mutate(tmp_path,'evidence/runtime-20260801.yaml','user_validated: false','user_validated: true');assert p.returncode==1 and 'runtime receipt' in p.stderr

def test_rejects_stale_render_bytes(tmp_path):
 copy(tmp_path);p=tmp_path/BASE/'evidence/renders/phone320-a-result.png';p.write_bytes(p.read_bytes()+b'x');r=run(tmp_path);assert r.returncode==1 and 'render artifact mismatch' in r.stderr

def test_rejects_education_removal(tmp_path):
 p=mutate(tmp_path,'scenario.yaml','pillar3a_reduces_liquidity','liquidity_irrelevant');assert p.returncode==1 and 'display' in p.stderr
