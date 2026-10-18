#!/usr/bin/env python3
"""Template: turn a raw question bank into this app's ContentPack.

Copy of the Hermes content-pipeline helper, genericized for the whitelabel.
Adapt the SUBJECTS map and the pack.json fields below to your niche, then run
from the app root:  python3 scripts/build-contentpack.py [--format trueFalse]

--format multipleChoice (default): `options` + letter/index `answer`.
--format trueFalse: Verdadeiro/Falso bank — no `options`; `answer` accepts,
  case-insensitively, true/false (JSON bool), "V"/"F", "T"/"F", "Verdadeiro"/
  "Falso", "True"/"False" or "Certo"/"Errado". Choices are written as
  the choices read from strings.json quiz.trueLabel/falseLabel and
  pack.json gets "niche": {"questionFormat": "trueFalse"}.

Reads:
  - ~/🧠 GERAL - CRIACAO APPS/question-banks/<YOUR_BANK>.json   (source bank)
  - ./<TARGET>/ContentPack/pack.json                             (keeps generic fields)

Writes into ./<TARGET>/ContentPack/:
  - questions.json   (app schema)
  - pack.json        (niche config; generic achievements reused from template)

Source bank item is expected to look roughly like:
  { "id", "domain", "question", "options": {"A":..} | [..], "answer", "difficulty",
    "explanation", "imageName"?, "imageURL"? }
Images: `imageName` must be an imageset in <TARGET>/Assets.xcassets (the app
refuses to launch otherwise); this script checks that before writing.
Tweak the parsing if your bank differs.
"""
import argparse, json, os, sys, glob

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
TRUE_TOKENS = {"true", "v", "t", "verdadeiro", "certo"}
FALSE_TOKENS = {"false", "f", "falso", "errado"}


def true_false_choices():
    """V/F labels in the app's language, as ContentValidator expects."""
    hits = glob.glob("*/ContentPack/strings.json")
    if not hits:
        sys.exit("No */ContentPack/strings.json found. Run from the app root.")
    quiz = json.load(open(hits[0], encoding="utf-8"))["quiz"]
    return [quiz["trueLabel"], quiz["falseLabel"]]


def parse_true_false(raw, qid):
    if isinstance(raw, bool):
        return 0 if raw else 1
    token = str(raw).strip().lower()
    if token in TRUE_TOKENS:
        return 0
    if token in FALSE_TOKENS:
        return 1
    sys.exit(f"Unrecognized V/F answer {raw!r} on {qid}")


def parse_multiple_choice(q):
    opts = q["options"]
    if isinstance(opts, list):
        ans = q["answer"]
        return opts, (int(ans) if isinstance(ans, int) else LETTERS.index(str(ans)))
    keys = [k for k in LETTERS if k in opts]
    return [opts[k] for k in keys], keys.index(q["answer"])


def existing_imagesets(cp):
    assets = os.path.join(os.path.dirname(cp), "Assets.xcassets")
    return {os.path.basename(p)[:-len(".imageset")]
            for p in glob.glob(os.path.join(assets, "**", "*.imageset"), recursive=True)}

def find_target_contentpack():
    hits = glob.glob("*/ContentPack/pack.json")
    if not hits:
        sys.exit("No */ContentPack/pack.json found. Run from the app root.")
    return os.path.dirname(hits[0])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--format", choices=["multipleChoice", "trueFalse"], default="multipleChoice")
    fmt = ap.parse_args().format
    src_path = os.path.join(HOME, "🧠 GERAL - CRIACAO APPS", "question-banks", f"{BANK_NAME}.json")
    if not os.path.exists(src_path):
        sys.exit(f"Bank not found: {src_path}\nEdit BANK_NAME at the top of this script.")
    cp = find_target_contentpack()
    src = json.load(open(src_path))
    qsrc = src["questions"] if isinstance(src, dict) and "questions" in src else src

    imagesets = existing_imagesets(cp)
    questions, seen = [], set()
    for q in qsrc:
        sid = DOMAIN_TO_ID.get(q.get("domain"))
        if sid is None:
            sys.exit(f"Unmapped domain: {q.get('domain')!r} — add it to SUBJECTS.")
        if fmt == "trueFalse":
            choices, correct = true_false_choices(), parse_true_false(q["answer"], q.get("id"))
        else:
            choices, correct = parse_multiple_choice(q)
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
        if entry.get("imageName") and entry["imageName"] not in imagesets:
            sys.exit(f"{qid}: imageName {entry['imageName']!r} has no imageset in Assets.xcassets")
        questions.append(entry)

    pack = json.load(open(os.path.join(cp, "pack.json")))   # keep achievements etc.
    pack.update(PACK_OVERRIDES)
    pack["subjects"] = [{"id": sid, "name": name, "sfSymbol": sym}
                        for (_d, sid, name, sym) in SUBJECTS]
    pack.pop("regions", None)   # add back manually only for regional niches
    niche = dict(pack.get("niche") or {})
    if fmt == "trueFalse":
        niche["questionFormat"] = "trueFalse"
    else:
        niche.pop("questionFormat", None)
    if niche:
        pack["niche"] = niche
    else:
        pack.pop("niche", None)

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
