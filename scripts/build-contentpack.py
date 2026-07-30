#!/usr/bin/env python3
"""Template: turn a raw question bank into this app's ContentPack.

Copy of the Hermes content-pipeline helper, genericized for the whitelabel.
Adapt the SUBJECTS map and the pack.json fields below to your niche, then run
from the app root:  python3 scripts/build-contentpack.py

Reads:
  - ~/🧠 GERAL - CRIACAO APPS/question-banks/<YOUR_BANK>.json   (source bank)
  - ./<TARGET>/ContentPack/pack.json                             (keeps generic fields)

Writes into ./<TARGET>/ContentPack/:
  - questions.json   (app schema)
  - pack.json        (niche config; generic achievements reused from template)

Source bank item is expected to look roughly like:
  { "id", "domain", "question", "options": {"A":..} | [..], "answer", "difficulty",
    "explanation", "imageName"?, "imageURL"? }
Tweak the parsing if your bank differs.
"""
import json, os, sys, glob

HOME = os.path.expanduser("~")

# ── EDIT THESE ────────────────────────────────────────────────────────────────
BANK_NAME = "REPLACE_bank_filename_without_ext"   # e.g. "asvab"
# source domain (exact string in the bank) -> (subjectId, display name, SF Symbol)
SUBJECTS = [
    ("REPLACE Source Domain 1", "subject-1", "REPLACE — Topic One",   "1.circle.fill"),
    ("REPLACE Source Domain 2", "subject-2", "REPLACE — Topic Two",   "2.circle.fill"),
    ("REPLACE Source Domain 3", "subject-3", "REPLACE — Topic Three", "3.circle.fill"),
]
PACK_OVERRIDES = {
    "examName": "REPLACE — Full exam name",
    "examShortName": "EXAM",
    "tagline": "REPLACE — one-line promise",
    "language": "en",
    "accentHex": "#1B9AF7",
    "mockExam": {"questionCount": 40, "minutes": 45, "passPercent": 75},
    "products": {"weekly": "app.hermesdigital.REPLACE.weekly",
                 "monthly": "app.hermesdigital.REPLACE.monthly"},
    "legal": {"privacyUrl": "https://REPLACE-ME.github.io/legal/privacy.html",
              "termsUrl": "https://REPLACE-ME.github.io/legal/terms.html",
              "supportEmail": "support@hermesdigital.app",
              "supportUrl": "https://REPLACE-ME.github.io/legal/support.html"},
}
# ──────────────────────────────────────────────────────────────────────────────

DOMAIN_TO_ID = {d: sid for (d, sid, _n, _s) in SUBJECTS}
DIFF = {"easy": 1, "medium": 2, "med": 2, "hard": 3, "1": 1, "2": 2, "3": 3}
LETTERS = ["A", "B", "C", "D", "E", "F"]

def find_target_contentpack():
    hits = glob.glob("*/ContentPack/pack.json")
    if not hits:
        sys.exit("No */ContentPack/pack.json found. Run from the app root.")
    return os.path.dirname(hits[0])

def main():
    src_path = os.path.join(HOME, "🧠 GERAL - CRIACAO APPS", "question-banks", f"{BANK_NAME}.json")
    if not os.path.exists(src_path):
        sys.exit(f"Bank not found: {src_path}\nEdit BANK_NAME at the top of this script.")
    cp = find_target_contentpack()
    src = json.load(open(src_path))
    qsrc = src["questions"] if isinstance(src, dict) and "questions" in src else src

    questions, seen = [], set()
    for q in qsrc:
        sid = DOMAIN_TO_ID.get(q.get("domain"))
        if sid is None:
            sys.exit(f"Unmapped domain: {q.get('domain')!r} — add it to SUBJECTS.")
        opts = q["options"]
        if isinstance(opts, list):
            choices = opts
            ans = q["answer"]
            correct = int(ans) if isinstance(ans, int) else LETTERS.index(str(ans))
        else:
            keys = [k for k in LETTERS if k in opts]
            choices, correct = [opts[k] for k in keys], keys.index(q["answer"])
        diff = DIFF.get(str(q["difficulty"]).lower())
        if diff is None:
            sys.exit(f"Unmapped difficulty {q['difficulty']!r} on {q.get('id')}")
        qid = q["id"]
        if qid in seen:
            sys.exit(f"Duplicate id {qid}")
        seen.add(qid)
        entry = {"id": qid, "subjectId": sid, "difficulty": diff,
                 "text": q["question"].strip(), "choices": choices,
                 "correctIndex": correct, "explanation": q["explanation"].strip()}
        for k_src, k_dst in (("imageName", "imageName"), ("image", "imageURL"),
                             ("imageURL", "imageURL"), ("imageSource", "imageSource")):
            if q.get(k_src):
                entry[k_dst] = q[k_src]
        questions.append(entry)

    pack = json.load(open(os.path.join(cp, "pack.json")))   # keep achievements etc.
    pack.update(PACK_OVERRIDES)
    pack["subjects"] = [{"id": sid, "name": name, "sfSymbol": sym}
                        for (_d, sid, name, sym) in SUBJECTS]
    pack.pop("regions", None)   # add back manually only for regional niches

    json.dump(questions, open(os.path.join(cp, "questions.json"), "w"), ensure_ascii=False, indent=1)
    json.dump(pack, open(os.path.join(cp, "pack.json"), "w"), ensure_ascii=False, indent=2)

    import collections
    by_sub = collections.Counter(q["subjectId"] for q in questions)
    print(f"questions: {len(questions)}  |  mock {pack['mockExam']['questionCount']} "
          f"<= {len(questions)}: {pack['mockExam']['questionCount'] <= len(questions)}")
    for (_d, sid, name, _s) in SUBJECTS:
        print(f"  {by_sub[sid]:4d}  {sid:12s} {name}")

if __name__ == "__main__":
    main()
