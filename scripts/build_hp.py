import json

SUBJECTS = [
    ("Anatomie und Physiologie", "anatomie", "Anatomie & Physiologie", "figure.stand"),
    ("Berufs- und Gesetzeskunde", "berufsrecht", "Berufs- & Gesetzeskunde", "book.closed.fill"),
    ("Diagnostik und Untersuchungstechniken", "diagnostik", "Diagnostik & Untersuchung", "waveform.path.ecg"),
    ("Hygiene", "hygiene", "Hygiene", "drop.fill"),
    ("Infektionskrankheiten und Infektionsschutzgesetz", "infektionsschutz", "Infektionskrankheiten & IfSG", "cross.case.fill"),
    ("Krankheitslehre Innere Medizin", "innere-medizin", "Innere Medizin", "heart.fill"),
    ("Krankheitslehre Neurologie", "neurologie", "Neurologie", "brain.head.profile"),
    ("Notfallmedizin und Erste Hilfe", "notfallmedizin", "Notfallmedizin & Erste Hilfe", "cross.fill"),
    ("Pharmakologie", "pharmakologie", "Pharmakologie", "pills.fill"),
    ("Krankheitslehre Psychiatrie", "psychiatrie", "Psychiatrie", "brain"),
]
DOMAIN_TO_ID = {d: sid for (d, sid, _n, _s) in SUBJECTS}
DIFF = {"easy": 1, "medium": 2, "hard": 3}
LETTERS = ["A", "B", "C", "D", "E", "F"]

src = json.load(open("bank_questions.json"))
qsrc = src["questions"]

questions, seen = [], set()
for q in qsrc:
    sid = DOMAIN_TO_ID.get(q["domain"])
    if sid is None:
        raise SystemExit(f"Unmapped domain: {q['domain']!r}")
    opts = q["options"]
    keys = [k for k in LETTERS if k in opts]
    choices, correct = [opts[k] for k in keys], keys.index(q["answer"])
    diff = DIFF[q["difficulty"].lower()]
    qid = q["id"]
    if qid in seen:
        raise SystemExit(f"Duplicate id {qid}")
    seen.add(qid)
    entry = {"id": qid, "subjectId": sid, "difficulty": diff,
             "text": q["question"].strip(), "choices": choices,
             "correctIndex": correct, "explanation": q["explanation"].strip()}
    questions.append(entry)

print("total questions:", len(questions))

cp_path = "HeilpraktikerPrep/ContentPack/pack.json"
pack = json.load(open(cp_path))
pack.update({
    "examName": "Heilpraktikerprüfung (Überprüfung nach dem HeilprG)",
    "examShortName": "HP",
    "tagline": "Bestehe die schriftliche Überprüfung nach dem Heilpraktikergesetz.",
    "language": "de",
    "mockExam": {"questionCount": 60, "minutes": 120, "passPercent": 75},
    "products": {"weekly": "app.hermesdigital.hp.weekly",
                 "monthly": "app.hermesdigital.hp.monthly"},
    "legal": {"privacyUrl": "https://hermesdigitalbr-spec.github.io/heilpraktiker-pruefung-2026-simulation-legal/privacy.html",
              "termsUrl": "https://hermesdigitalbr-spec.github.io/heilpraktiker-pruefung-2026-simulation-legal/terms.html",
              "supportEmail": "support@hermesdigital.app",
              "supportUrl": "https://hermesdigitalbr-spec.github.io/heilpraktiker-pruefung-2026-simulation-legal/support.html"},
    "appStoreUrl": None,
})
pack.pop("regions", None)
pack["subjects"] = [{"id": sid, "name": name, "sfSymbol": sym} for (_d, sid, name, sym) in SUBJECTS]

with open(cp_path, "w") as f:
    json.dump(pack, f, ensure_ascii=False, indent=2)
with open("HeilpraktikerPrep/ContentPack/questions.json", "w") as f:
    json.dump(questions, f, ensure_ascii=False, indent=2)

# sanity: sum per subject
from collections import Counter
c = Counter(q["subjectId"] for q in questions)
for _d, sid, name, _s in SUBJECTS:
    print(sid, c[sid])
