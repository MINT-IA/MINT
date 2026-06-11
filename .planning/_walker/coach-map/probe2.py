#!/usr/bin/env python3
"""Re-run probes that errored (429) — throttled sequential — and merge into results.json.
Also improves correctness check (normalize spaces/apostrophes/commas)."""
import json, re, uuid, urllib.request, urllib.error, time, os
from probe import PROBES, BASE, BANNED, REFUSE, CHF, CITE, OUT

def norm(s): return re.sub(r"[ '’]","",s).replace(",",".")

def ask(p):
    pid, dom, kind, temporal, q, expect = p
    sess = str(uuid.uuid4())
    body = json.dumps({"message": q, "language": "fr"}).encode()
    req = urllib.request.Request(BASE, data=body, method="POST",
        headers={"Content-Type":"application/json","X-Anonymous-Session":sess})
    rec = {"id":pid,"domain":dom,"kind":kind,"temporal":temporal,"q":q,"expect":expect}
    t0=time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.loads(r.read().decode())
        msg = d.get("message","") or ""
        rec.update(reply=msg, tokens=d.get("tokensUsed"), eclairage=bool(d.get("eclairage")),
            refused=bool(REFUSE.search(msg)), has_chf=bool(CHF.search(msg)), has_cite=bool(CITE.search(msg)),
            banned=sorted(set(m.lower() for m in BANNED.findall(msg))) if BANNED.search(msg) else [],
            correct=(norm(expect) in norm(msg)) if expect else None)
    except urllib.error.HTTPError as e:
        rec["error"]=f"HTTP {e.code}: {e.read().decode()[:120]}"
    except Exception as e:
        rec["error"]=f"{type(e).__name__}: {e}"
    rec["secs"]=round(time.time()-t0,1)
    return rec

def main():
    prev={r["id"]:r for r in json.load(open(os.path.join(OUT,"results.json")))}
    todo=[p for p in PROBES if prev.get(p[0],{}).get("error") or p[0] not in prev]
    print(f"re-running {len(todo)} probes throttled (5s spacing)...")
    for p in todo:
        r=ask(p); prev[r["id"]]=r
        print(f"[{r['id']}] {r['domain']:6} refused={r.get('refused')} chf={r.get('has_chf')} cite={r.get('has_cite')} correct={r.get('correct')} banned={r.get('banned')} err={r.get('error','')[:50]}", flush=True)
        time.sleep(5)
    out=[prev[k] for k in sorted(prev)]
    json.dump(out, open(os.path.join(OUT,"results.json"),"w"), ensure_ascii=False, indent=1)
    print(f"\nMERGED -> results.json ({len(out)} total, {sum(1 for r in out if r.get('error'))} still errored)")

if __name__=="__main__": main()
