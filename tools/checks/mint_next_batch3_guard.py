#!/usr/bin/env python3
"""Fail-closed contract for the derivative Batch 3 comparison prototype."""
from __future__ import annotations
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
import yaml
BASE=Path('product/mint_next/batch3')
HASHES={
 'product/mint_next/batch1/directions.yaml':'b8c9cf00329020d3a9c3409e7eedc75d1dcae1cd31b9e49ea73981c2b8129a1c',
 'product/mint_next/batch1/evaluation.yaml':'c296f971514009c164c73dc5f14b498fc47cb9a59733bd69b832ac4f2b37d222',
 'product/mint_next/batch1/prototype/index.html':'4b90a4e4482a97daa985b020be4d7f2c374df267632574d05c3da7aa7fd042b1',
 'product/mint_next/batch2/batch.yaml':'09c45417139a29315eae822f35fb42e3eb3418136fbe29658806e978b69e97e2',
 'product/mint_next/batch2/fixture.yaml':'f59b37bc21f19f18cb8ae57969b183cca824d52de605b14b8efb526a703886fc',
 'product/mint_next/batch2/sources.yaml':'44e5541f4be8382f9fd5751fdf05a72f203e5b07755c58d6b379fb7976cc0e8c',
 'product/mint_next/batch2/evidence/vd-calculator-normalized-receipt-20260801.json':'5ed976cb07688a6d08cba29f96e9c2a451fb3546f5daf6cc5fe58a4348832293',
 'product/mint_next/batch2/evidence/promotion-20260801.yaml':'7a6140df95080a43a71dac0a312836387b06e3b1c7f4e10ec0f9f9368d0098cb'}
LEGACY=['B1-FX-01','CHF 1’500','15’000','13’500','108’000','2’400','Léa','CHF 2’166.59']

def load(root,rel,errors):
 try:d=yaml.safe_load((root/BASE/rel).read_text())
 except Exception as e:errors.append(f'unable to load {rel}: {e}');return {}
 return d if isinstance(d,dict) else {}
def validate(root:Path)->list[str]:
 e=[];batch=load(root,'batch.yaml',e);scenario=load(root,'scenario.yaml',e);directions=load(root,'directions.yaml',e);evaluation=load(root,'evaluation-readiness.yaml',e)
 if any(x.get('schema_version')!=1 for x in (batch,scenario,directions,evaluation)):e.append('Batch 3 schema versions have drifted')
 if batch.get('status')!='draft_unproven' or batch.get('work_tracking')!={'system':'beads','id':'MINT_nosync-wgi','expected_live_status':'in_progress'}:e.append('Batch 3 draft lifecycle has drifted')
 exact_scope={'includes':['derivative_local_prototype','three_equal_depth_directions','one_identical_promoted_fixture','correction_invalidation','source_assumption_disclosure','runtime_and_accessibility_proofs','independent_roasts'],'excludes':['historical_batch1_edit','historical_batch2_edit','ux_winner','moderated_user_test_claim','flutter_product','tax_engine_change','production_connection','supported_or_licensed_api_claim','nationwide_tax_claim','jos006_closure']}
 if batch.get('scope')!=exact_scope:e.append('Batch 3 scope has drifted')
 if batch.get('upstream')!={'batch1_promoted_head':'c29d7dd95a6c6e9d6d0d3e24fbb523742a5e6f59','batch2_promoted_head':'424fdb14e1ab53a9fedc171e398f171b51be23b9'}:e.append('Batch 3 upstream promotion identity has drifted')
 exact_artifacts={'scenario':'product/mint_next/batch3/scenario.yaml','directions':'product/mint_next/batch3/directions.yaml','evaluation_readiness':'product/mint_next/batch3/evaluation-readiness.yaml','prototype':'product/mint_next/batch3/prototype/index.html','runtime_probe':'tools/checks/mint_next_batch3_runtime_probe.py','runtime_receipt':'product/mint_next/batch3/evidence/runtime-20260801.yaml','render_tool':'tools/checks/mint_next_batch3_render.py','render_receipt':'product/mint_next/batch3/evidence/render-20260801.yaml'}
 if batch.get('artifacts')!=exact_artifacts:e.append('Batch 3 artifact graph has drifted')
 exact_promotion={'author_cannot_approve':True,'requires':['upstream_hash_identity','three_direction_fact_parity','correction_invalidation_runtime','source_disclosure_runtime','accessibility_review','swiss_tax_and_compliance_review','independent_roast_no_p1_p2'],'never_sufficient':['author_summary','screenshots_only','grep_only','test_exit_code_without_mutation','same_file_expected_values','claimed_user_test_without_raw_evidence']}
 if batch.get('promotion')!=exact_promotion:e.append('Batch 3 promotion contract has drifted')
 for rel,digest in HASHES.items():
  p=root/rel
  if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:e.append(f'upstream hash mismatch: {rel}')
 expected_ref={'fixture_id':'B2-VD-3A-2026-01','promoted_batch2_head':'424fdb14e1ab53a9fedc171e398f171b51be23b9','files':{'batch.yaml':HASHES['product/mint_next/batch2/batch.yaml'],'fixture.yaml':HASHES['product/mint_next/batch2/fixture.yaml'],'sources.yaml':HASHES['product/mint_next/batch2/sources.yaml'],'evidence/vd-calculator-normalized-receipt-20260801.json':HASHES['product/mint_next/batch2/evidence/vd-calculator-normalized-receipt-20260801.json'],'evidence/promotion-20260801.yaml':HASHES['product/mint_next/batch2/evidence/promotion-20260801.yaml']}}
 if scenario.get('scenario_id')!='B3-B2-VD-3A-2026-01' or scenario.get('status')!='promoted_fixture_derivative_not_product_connected' or scenario.get('fixture_reference')!=expected_ref:e.append('Batch 3 scenario/upstream identity has drifted')
 persona=scenario.get('persona_boundary')
 if persona!={'synthetic':True,'anonymous':True,'linked_to_batch1_lea':False,'gross_income_chf':None,'rule':'declared_taxable_inputs_only_never_salary_derived'}:e.append('Batch 3 persona boundary has drifted')
 assumptions={'tax_year':2026,'canton':'VD','municipality':'Lausanne','full_year_domicile':True,'taxation':'ordinary','civil_status':'single','children_full_quotient':0,'children_half_quotient':0,'children_same_household':0,'intercantonal_or_international_allocation':False,'taxable_wealth_icc_chf':0,'employee_with_lpp':True,'pillar3a_contribution_credited_in_tax_year':True,'retroactive_3a_catchup':False}
 if scenario.get('assumptions')!=assumptions:e.append('Batch 3 assumptions have drifted')
 inputs={'baseline_taxable_income_icc_chf':80000,'baseline_taxable_income_ifd_chf':80000,'hypothetical_pillar3a_chf':7258,'counterfactual_submitted_icc_chf':72742,'counterfactual_submitted_ifd_chf':72742,'official_displayed_counterfactual_chf':72700}
 if scenario.get('inputs')!=inputs:e.append('Batch 3 scenario inputs have drifted')
 result=scenario.get('official_indicative_result',{}); expected_result={'baseline':{'icc_chf':14423.15,'ifd_chf':1378.2,'total_chf':15801.35},'counterfactual':{'icc_chf':12648.75,'ifd_chf':1048.6,'total_chf':13697.35},'difference':{'icc_chf':1774.4,'ifd_chf':329.6,'total_chf':2104.0},'definitive_tax_set_by':'ACI_Vaud','calculator_version_visible':'10.4.0','captured_on':__import__('datetime').date(2026,8,1),'expires_on':__import__('datetime').date(2026,12,31)}
 if result!=expected_result:e.append('Batch 3 scenario result has drifted')
 display=scenario.get('display_contract',{})
 expected_labels=['official_indicative','declared_taxable_inputs','not_personalized','not_filing_result','not_advice','official_rounding','no_contribution_recommendation']
 expected_education=['pillar3a_reduces_liquidity','capital_locked_until_eligible_release','withdrawal_taxed_separately']
 if display!={'heading':'Écart fiscal indicatif du scénario','identity':'Scénario illustratif B2-VD-3A-2026-01 · non personnalisé','required_adjacent_labels':expected_labels,'required_education':expected_education,'source_url':'https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/calculer-mes-impots','api_boundary':'manual_evidence_only_no_supported_or_licensed_Vaud_API_identified'}:e.append('Batch 3 display contract has drifted')
 correction=scenario.get('correction_invariant',{})
 expected_correction={'critical_fields':['tax_year','canton','municipality','full_year_domicile','taxation','civil_status','children','allocation','taxable_wealth','taxable_income','pillar3a_amount','pillar3a_timing'],'on_any_change':'hide_all_official_amounts_and_show_recalculation_unavailable_in_prototype','exact_revert':'may_restore_only_the_exact_promoted_fixture'}
 if correction!=expected_correction:e.append('Batch 3 correction contract has drifted')
 expected_forbidden_strings=['B1-FX-01','CHF 1’500','15’000','13’500','108’000','2’400','Léa','CHF 2’166.59']
 expected_forbidden_claims=['personal_tax_estimate','tax_filing_result','advice_or_recommendation','recommended_contribution','guaranteed_saving','exact_engine_result','FINMA_certified','supported_or_licensed_api','product_connected','nationwide_coverage','winner_selected','users_tested','LLM_calculation']
 if scenario.get('forbidden_active_strings')!=expected_forbidden_strings or scenario.get('forbidden_claims')!=expected_forbidden_claims:e.append('Batch 3 forbidden claim boundary has drifted')
 shared=directions.get('shared_contract',{})
 if shared!={'fixture_id':'B2-VD-3A-2026-01','state_count':6,'primary_task':'understand_verify_and_save_the_same_bounded_tax_question','required_capabilities':['result_with_adjacent_provenance','disclosure_overlay','correction_invalidation','exact_revert','back','continue_without_account','save_and_return']}:e.append('Batch 3 direction shared contract has drifted')
 expected_directions={'a':{'mechanism':'receipt_first','states':['promise','exact_inputs_gate','pillar3a_context','official_receipt','verification_and_correction','saved_cap']},'b':{'mechanism':'life_decision_first','states':['life_question','horizons','bounded_tax_angle','official_before_after_canvas','verification_and_correction','saved_plan']},'c':{'mechanism':'question_to_structured_card','states':['intent','clarification','required_inputs','official_fixture_card','verification_and_correction','saved_card']}}
 if directions.get('directions')!=expected_directions:e.append('Batch 3 direction mechanisms or state graphs have drifted')
 expected_equality={'identical_financial_facts':True,'identical_result_labels':True,'identical_source_discoverability':True,'identical_correction_invalidation':True,'equal_depth':True,'differing_only':['entry_mechanism','visual_object','return_loop']}
 if directions.get('equality_rules')!=expected_equality:e.append('Batch 3 equality contract has drifted')
 if evaluation!={'schema_version':1,'status':'protocol_not_executed','participants':0,'winner_selected':False,'raw_user_evidence_present':False,'upstream_batch1_evaluation':{'path':'product/mint_next/batch1/evaluation.yaml','sha256':'c296f971514009c164c73dc5f14b498fc47cb9a59733bd69b832ac4f2b37d222'},'moderated_tasks_reused':['understand_scenario_without_personal_advice_confusion','find_source_and_assumptions','correct_an_assumption_and_observe_invalidation','continue_without_account','recover_next_step_on_return'],'next_honest_gate':'moderated_protocol_with_raw_evidence_after_Batch3_promotion','forbidden_claims':['user_testing_completed','winner_selected','score_95_achieved','production_feasibility_proven']}:e.append('Batch 3 user evidence readiness has drifted')
 html_path=root/BASE/'prototype/index.html'
 if not html_path.is_file():e.append('Batch 3 prototype missing');return e
 html=html_path.read_text()
 if any(token in html for token in LEGACY):e.append('Batch 3 prototype contains legacy fixture/persona values')
 if 'Reçu officiel' in html or 'reçu officiel' in html:e.append('Batch 3 prototype implies official receipt or endorsement')
 required=['B2-VD-3A-2026-01','CHF 2’104','Recalcul indisponible dans ce prototype','data-critical-edit','data-disclosure-trigger','id="disclosure"','id="invalidated"','mint-b3-']
 if any(token not in html for token in required):e.append('Batch 3 prototype runtime hooks or fixture identity are incomplete')
 if html.count('data-direction=')<3:e.append('Batch 3 prototype does not expose three directions')
 runtime=load(root,'evidence/runtime-20260801.yaml',e)
 expected_runtime={'schema_version':1,'status':'local_browser_runtime_evidence_not_user_validation','prototype_sha256':'e52da538236ee9f5fef399fbf477b1c7113f29c829a1d951a929e236b87b3f13','probe_sha256':'630e8a26848b2ed0ba7be03e4c566b33fe633d94f34fff68b52f3f7aeed21e1c','command':'python3 tools/checks/mint_next_batch3_runtime_probe.py','proofs':{'state_matrix':'18_of_18_traversed_by_CDP_input_at_true_320px_viewport','document_horizontal_overflow':False,'scoped_visible_result_A_B_C':'pass_at_A4_B3_C4','visible_disclosure_A_B_C':'pass','modal_keyboard_focus_and_background_isolation':'pass','correction_invalidation_A_B_C':'pass','stale_amount_in_invalidated_content':False,'back_preserves_correction_A_B_C':'pass','explicit_revert_restores_exact_fixture_A_B_C':'pass','save_reload_returns_state6_A_B_C':'pass','direction_primary_secondary_chip_and_reset_controls':'pass','modal_visible_focus_source_close_tab_shift_tab':'pass','all_back_edges_A_B_C_with_deliberate_focus':'pass','result_content_CDP_wheel_reachability':'pass','reduced_motion_emulation':'pass','modal_close_explicit_contrast_and_44px_target':'pass'},'claims':{'user_validated':False,'accessibility_fully_validated':False,'flutter_or_product_runtime':False,'winner_selected':False}}
 if runtime!=expected_runtime:e.append('Batch 3 runtime receipt has drifted')
 if hashlib.sha256(html_path.read_bytes()).hexdigest()!=runtime.get('prototype_sha256'):e.append('Batch 3 runtime prototype hash mismatch')
 probe=root/'tools/checks/mint_next_batch3_runtime_probe.py'
 if not probe.is_file() or hashlib.sha256(probe.read_bytes()).hexdigest()!=runtime.get('probe_sha256'):e.append('Batch 3 runtime probe hash mismatch')
 render_tool=root/'tools/checks/mint_next_batch3_render.py'
 if not render_tool.is_file() or hashlib.sha256(render_tool.read_bytes()).hexdigest()!='ecdc0f1a5c55e684c04b58783f902e3606e820573bb6b4ea298c308042684515':e.append('Batch 3 render tool hash mismatch')
 render=load(root,'evidence/render-20260801.yaml',e); expected_names={f'{v}-{d}-{s}.png' for v in ('component320','desktop1280') for d in 'abc' for s in ('result','disclosure','invalidated')}
 if render.get('schema_version')!=1 or render.get('status')!='local_render_evidence_not_user_or_accessibility_validation' or render.get('source')!='product/mint_next/batch3/prototype/index.html' or render.get('viewports')!={'component320':'320px_constrained_component_in_headless_chrome','desktop1280':'1280x900'} or set(render.get('artifacts',{}))!=expected_names or render.get('claims')!={'all_18_targeted_renders_created_not_all_18_journey_states':True,'user_validated':False,'accessibility_validated_by_screenshots':False,'winner_selected':False}:e.append('Batch 3 render receipt has drifted')
 for name,item in render.get('artifacts',{}).items():
  p=root/str(item.get('path',''))
  if not p.is_file() or p.name!=name or hashlib.sha256(p.read_bytes()).hexdigest()!=item.get('sha256') or p.stat().st_size!=item.get('bytes'):e.append(f'Batch 3 render artifact mismatch: {name}')
 return e

def live(root):
 p=subprocess.run(['git','rev-parse','--path-format=absolute','--git-common-dir'],cwd=root,capture_output=True,text=True)
 if p.returncode:return ['unable to locate canonical repository for live Bead check']
 canonical=Path(p.stdout.strip()).parent;q=subprocess.run(['bd','show','MINT_nosync-wgi','--json'],cwd=canonical,capture_output=True,text=True)
 try:item=json.loads(q.stdout)[0]
 except Exception:return ['unable to parse live Batch 3 Bead']
 return [] if item.get('status')=='in_progress' else [f"live Batch 3 Bead must be in_progress, got {item.get('status')}"]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--root',type=Path,default=Path.cwd());ap.add_argument('--live-work-tracking',action='store_true');a=ap.parse_args();errors=validate(a.root.resolve());errors+=live(a.root.resolve()) if a.live_work_tracking else []
 if errors:
  for x in errors:print('ERROR mint_next_batch3_guard:',x,file=sys.stderr)
  return 1
 print('OK mint_next_batch3_guard: derivative fixture comparison remains bounded and unpromoted.',file=sys.stderr);return 0
if __name__=='__main__':raise SystemExit(main())
