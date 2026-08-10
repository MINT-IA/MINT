import copy, importlib.util, json, tempfile, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; GP=ROOT/'tools/checks/mint_next_storyboard_guard.py'; S=importlib.util.spec_from_file_location('g',GP); g=importlib.util.module_from_spec(S); S.loader.exec_module(g)
class GuardTests(unittest.TestCase):
 def setUp(self): self.d=json.loads((ROOT/'product/mint_next/storyboard/three_a.storyboard.json').read_text())
 def errors(self,fn=None):
  d=copy.deepcopy(self.d)
  if fn: fn(d)
  return g.validate_contract(d,ROOT)
 def test_canonical_contract_schema_and_render(self): self.assertEqual([],g.validate_schema()); self.assertEqual([],self.errors()); self.assertEqual([],g.validate_render())
 def test_axes_are_independent_and_no_green_today(self):
  a=g.derived_axes(self.d); self.assertEqual({'Cible','Accessible','Novices','iOS','Android','Montrable'},set(a)); self.assertTrue(all(v[1] != 'pass' for v in a.values())); self.assertEqual(('bloqué','blocked'),a['Montrable'])
 def test_fake_strings_paths_cannot_promote_ios(self):
  def m(d): d['scenes'][0]['evidence']['runtime_receipts']=[{'path':'evidence/fake.png','sha256':'0'*64,'product_sha':'1'*40,'platform':'ios','scene_id':'today_opportunity'}]
  self.assertTrue(any('faux path' in x or 'runtime sans code' in x for x in self.errors(m)))
 def test_runtime_without_code_cannot_promote(self):
  def m(d): d['scenes'][0]['evidence']['runtime_receipts']=[{'path':'docs/DESIGN_SYSTEM.md','sha256':g.digest(ROOT/'docs/DESIGN_SYSTEM.md'),'product_sha':'1'*40,'platform':'ios','scene_id':'today_opportunity'}]
  self.assertTrue(any('runtime sans code' in x for x in self.errors(m)))
 def test_exposure_without_runtime_cannot_promote(self):
  def m(d): d['scenes'][0]['evidence']['exposure_receipts']=[{'path':'docs/DESIGN_SYSTEM.md','sha256':g.digest(ROOT/'docs/DESIGN_SYSTEM.md'),'product_sha':'1'*40}]
  self.assertTrue(any('exposition sans runtime' in x for x in self.errors(m)))
 def test_phase_status_is_not_authored_and_pin_drift_fails(self):
  self.assertNotIn('phase_status',self.d['goal']); self.assertTrue(any('phase authority' in x for x in self.errors(lambda d:d['phase_authority'].update(sha256='0'*64))))
 def test_tokens_are_unique_visual_authority(self):
  design=self.d['design_authority']; self.assertEqual(('docs/brand/mint-v2/tokens.jsx','authority','historical_context'),(design['authority']['path'],design['authority']['role'],design['historical_context']['role']))
  self.assertTrue(any('concurrentes' in x for x in self.errors(lambda d:d['design_authority']['historical_context'].update(role='authority'))))
 def test_owner_duplicate_anchor_and_hash_fail(self):
  self.assertTrue(any('owner conflict' in x for x in self.errors(lambda d:d['field_ownership'].append(copy.deepcopy(d['field_ownership'][0])))))
  self.assertTrue(any('anchor absent' in x for x in self.errors(lambda d:d['field_ownership'][0].update(anchor='DOES NOT EXIST'))))
  self.assertTrue(any('pin divergent' in x for x in self.errors(lambda d:d['field_ownership'][1].update(sha256='0'*64))))
 def test_absolute_parent_and_network_paths_fail(self):
  for bad in ('/etc/passwd','../secret','https://tracker.invalid/x'):
   self.assertTrue(self.errors(lambda d,v=bad:d['phase_authority'].update(path=v)))
 def test_pii_fails(self): self.assertTrue(any('PII' in x for x in self.errors(lambda d:d['scenes'][0].update(summary='test@example.com'))))
 def test_happy_path_must_match_transitions(self): self.assertTrue(any('happy_path' in x for x in self.errors(lambda d:d['scenes'][0]['transitions'].clear())))
 def test_hidden_extra_transition_fails_exact_edge_set(self):
  self.assertTrue(any('edge set exact' in x for x in self.errors(lambda d:d['scenes'][0]['transitions'].append({'event':'secret','destination':'return_today'}))))
 def test_branch_path_must_match_transitions(self): self.assertTrue(any('refusal' in x for x in self.errors(lambda d:d['branches'].__setitem__('refusal',['confirm_fact','return_today']))))
 def test_unknown_unreachable_and_duplicate_scenes_fail(self):
  self.assertTrue(self.errors(lambda d:d['happy_path'].__setitem__(1,'ghost')))
  self.assertTrue(any('duplicate' in x for x in self.errors(lambda d:d['scenes'].append(copy.deepcopy(d['scenes'][0])))))
 def test_target_is_not_observation(self):
  self.assertTrue(all(s['observations']==[] for s in self.d['scenes']))
  self.assertTrue(self.errors(lambda d:d['scenes'][0]['observations'].append({'receipt_path':'fake','sha256':'0'*64,'criterion':'x','result':'pass'})))
 def test_empty_narrative_route_and_event_fail(self):
  self.assertTrue(any('chaîne vide' in x for x in self.errors(lambda d:d['scenes'][0].update(title='  '))))
  self.assertTrue(any('event vide' in x for x in self.errors(lambda d:d['scenes'][0]['transitions'][0].update(event=' '))))
 def test_novice_contract_is_honestly_not_run(self):
  n=self.d['novice_validation']; self.assertEqual(('not_run',2,5,60,[]),(n['status'],n['protocol']['readers_required'],n['protocol']['questions'],n['protocol']['time_limit_seconds'],n['observations']))
  self.assertTrue(any('non prouvée' in x for x in self.errors(lambda d:d['novice_validation'].update(status='passed'))))
 def test_schema_is_closed_everywhere(self): self.assertEqual([],g.validate_schema())
 def test_render_is_byte_deterministic(self):
  with tempfile.TemporaryDirectory() as t:
   a,b=Path(t)/'a',Path(t)/'b'; g.render_to(ROOT,a); g.render_to(ROOT,b); self.assertEqual(a.read_bytes(),b.read_bytes())
 def test_render_has_axes_wireframes_branches_truth_and_decision(self):
  x=(ROOT/'product/mint_next/storyboard/index.html').read_text()
  for q in ('Cible','Accessible','Novices','iOS','Android','Montrable','MAQUETTE · PAS LE PRODUIT','Donnée manquante','Refus d’enregistrer','Choisir CHF 0','Aucun écran runtime iOS ou Android n’est prouvé','Test novice : non exécuté','Décisions et discussion'): self.assertIn(q,x)
  for q in ('Autorité visuelle : <code>tokens.jsx</code>','contexte historique, non concurrent','Aucune fonte n’est embarquée ou chargée par le réseau'): self.assertIn(q,x)
  self.assertNotIn('<button',x.lower())
  episode=x.split('id="episode"',1)[1].split('id="dossier"',1)[0]
  for technical in ('eligibility','tax_year','factrecord','ruleset hash'): self.assertNotIn(technical,episode.lower())
 def test_render_has_strict_csp_and_accessibility_contracts(self): self.assertEqual([],g.validate_render())
 def test_html_hostiles_detected(self):
  raw=(ROOT/'product/mint_next/storyboard/index.html').read_text()
  for payload in ('<script>alert(1)</script>','<svg></svg>','<style>x{background:url(x)}</style>','<style>+:root{}</style>','<style>:root{</style>'):
   self.assertTrue(g.validate_html_content(raw+payload))
if __name__=='__main__': unittest.main()
