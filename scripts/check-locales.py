#!/usr/bin/env python3
"""Compara cada locales/<code>/strings.json com a referência pt-BR.

Regras:
- toda chave escalar do pt-BR precisa existir no outro idioma;
- placeholders (%d, %@, %1$s, %lld...) precisam bater;
- valor idêntico ao pt-BR contendo ã/õ/ç é tratado como tradução esquecida;
- listas podem ter tamanhos diferentes por idioma: só se exige que a lista
  exista, seja lista e não esteja vazia (itens não são comparados por índice).
- sinal de português (PT_WORDS + til, allowlist mínima PT_WORD_OK) em todo texto
  mostrado de idioma não-pt: strings.json, achievements.json e seeds/<code>/;
- widget e conquistas (locales/<code>/achievements.json) são estritos: qualquer
  valor idêntico ao pt-BR num idioma não-pt é erro, salvo palavra que existe igual
  no idioma (SAME_OK). As conquistas precisam ter exatamente os ids do pt-BR.

Modo pack: `check-locales.py --pack TestBase/ContentPack [locales]` confere um app
já gerado: se pack.language não é pt, o widget (strings.json) e as conquistas
(pack.json) não podem ter texto pt e precisam bater com locales/<language>.
"""
import json
import pathlib
import re
import sys

REF = "pt-BR"
PH = re.compile(r"%(?:\d+\$)?(?:lld|[@dfs])")
PT_MARKER = re.compile(r"[ãõçÃÕÇ]")


def flatten(node, prefix=""):
    """Gera (caminho, valor) para escalares e (caminho, list) para listas."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield from flatten(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(node, list):
        yield prefix, node
    else:
        yield prefix, node


def load(root, code):
    path = root / code / "strings.json"
    return dict(flatten(json.loads(path.read_text(encoding="utf-8"))))


def compare(loc, ref, cur):
    errors = []
    for key, val in ref.items():
        if key not in cur:
            errors.append(f"{loc}: falta {key}")
            continue
        other = cur[key]
        if isinstance(val, list):
            if not isinstance(other, list):
                errors.append(f"{loc}: esperava lista em {key}")
            elif not other:
                errors.append(f"{loc}: lista vazia em {key}")
            continue
        if isinstance(val, str) and isinstance(other, str):
            if sorted(PH.findall(val)) != sorted(PH.findall(other)):
                errors.append(f"{loc}: placeholders diferentes em {key}")
            elif val == other and PT_MARKER.search(val):
                errors.append(f"{loc}: igual ao pt-BR em {key}")
    return errors


# Palavras que são iguais ao pt-BR e corretas no idioma (não é tradução esquecida).
SAME_OK = {
    "en": {"Inferno", "Professor"},
    "de": {"Inferno", "Professor"},
    "it": {"Pronto", "Inferno", "Preciso", "Diligente", "Devoto"},
    "es-MX": {"Máquina de Quiz", "Mente Maratonista", "Preciso", "Perfeccionista",
              "Comprometido", "Diligente", "Devoto", "Especialista", "Completo",
              "Nota Máxima", "Curador", "Madrugador", "Persistente", "Saque Rápido",
              "Explorador", "Estudioso"},
}
SAME_OK["es-ES"] = SAME_OK["es-MX"]


# Sinal de português: palavras pt comuns + terminações com til. Vale para TODO
# texto mostrado (strings.json, achievements.json, seeds/, pack.json do app).
PT_WORDS = ("você|vocês|não|questões|questão|sequência|simulado|simulados|matéria|matérias|"
            "acerto|acertos|estudo|estude|aprovado|aprovados|hoje|amanhã|semana|seu|sua|seus|"
            "suas|meu|minha|para a|do dia|de estudo|prova|provas|assinatura|grátis|começar|"
            "continuar|agora|também|então|já|está|são|nós|até|ótimo|parabéns|dias seguidos")
PT_WORD_RX = re.compile(r"(?<![\wÀ-ÿ])(?:" + PT_WORDS + r")(?![\wÀ-ÿ])", re.I)
PT_TILDE_RX = re.compile(r"ção|ções|ão\b|ões\b|ãe")
# Allowlist mínima: palavra pt que existe igual (e correta) no idioma.
PT_WORD_OK = {
    "es-ES": {"continuar", "semana", "está"},
    "es-MX": {"continuar", "semana", "está"},
    "it": {"prova", "sua"},
}
PT_TILDE_SKIP = {"vi"}   # vietnamita usa ã/õ legitimamente


# Sinal de inglês num idioma pt (texto en esquecido no pt-BR). "quiz"/"quizzes" ficam
# de fora: são empréstimo usado no próprio pt-BR ("Termine seu primeiro quiz").
EN_WORDS = ("complete|completed|your|you|unlock|unlocked|the|and|with|start|finish|"
            "practice|questions|today|ready|done|streak|correct|answers|keep|great|tap|"
            "close|next|score|best|free|week|try")
EN_WORD_RX = re.compile(r"(?<![\wÀ-ÿ])(?:" + EN_WORDS + r")(?![\wÀ-ÿ])", re.I)
# Allowlist mínima: palavra en que é correta no pt-BR.
EN_WORD_OK = set()


def en_signal(text):
    """Primeiro trecho com cara de inglês num texto pt, ou None."""
    for m in EN_WORD_RX.finditer(text):
        if m.group().lower() not in EN_WORD_OK:
            return m.group()
    return None


def pt_signal(code, text):
    """Primeiro trecho com cara de português no texto, ou None."""
    ok = PT_WORD_OK.get(code, set())
    for m in PT_WORD_RX.finditer(text):
        if m.group().lower() not in ok:
            return m.group()
    if code not in PT_TILDE_SKIP:
        m = PT_TILDE_RX.search(text)
        if m:
            return m.group()
    return None


def iter_texts(node, prefix=""):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from iter_texts(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from iter_texts(v, f"{prefix}[{i}]")
    elif isinstance(node, str):
        yield prefix, node


# Campos do pack.json que não são texto mostrado (ids, URLs, símbolos, cores).
NON_TEXT_KEYS = {"id", "subjectId", "icon", "tint", "sfSymbol", "emoji", "type", "language",
                 "accentHex", "heroImage", "imageName", "imageURL", "privacyUrl", "termsUrl",
                 "supportUrl", "supportEmail", "appStoreUrl", "weekly", "monthly", "quarterly",
                 "examOutcome", "questionFormat"}


def scan_pt(code, label, data):
    """Texto no idioma errado: pt num idioma não-pt, en num idioma pt."""
    errors = []
    for path, text in iter_texts(data):
        if path.split(".")[-1].split("[")[0] in NON_TEXT_KEYS:
            continue
        if is_pt(code):
            hit = en_signal(text)
            if hit:
                errors.append(f"{code}: inglês em {label}:{path} ({hit!r}): {text[:60]!r}")
            continue
        hit = pt_signal(code, text)
        if hit:
            errors.append(f"{code}: português em {label}:{path} ({hit!r}): {text[:60]!r}")
    return errors


def scan_library(root, loc):
    errors = []
    for name in ("strings.json", "achievements.json"):
        f = root / loc / name
        if f.exists():
            errors.extend(scan_pt(loc, name, json.loads(f.read_text(encoding="utf-8"))))
    seeds = root.parent / "seeds" / loc
    for f in sorted(seeds.glob("*.json")) if seeds.is_dir() else []:
        errors.extend(scan_pt(loc, f"seeds/{f.name}", json.loads(f.read_text(encoding="utf-8"))))
    return errors


def is_pt(code):
    return code.lower().startswith("pt")


def strict_same(loc, key, ref_val, val):
    if is_pt(loc) or not isinstance(val, str) or val != ref_val:
        return []
    if val in SAME_OK.get(loc, set()) or not any(c.isalpha() for c in val):
        return []
    return [f"{loc}: texto pt-BR em {key}: {val!r}"]


def load_ach(root, code):
    path = root / code / "achievements.json"
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def compare_strict(loc, ref, cur, ref_ach, ach):
    errors = []
    for key, val in ref.items():
        if key.startswith("widget.") and key in cur:
            errors.extend(strict_same(loc, key, val, cur[key]))
    if ach is None:
        return errors + [f"{loc}: falta achievements.json"]
    if set(ach) != set(ref_ach):
        errors.append(f"{loc}: ids de conquistas diferentes do pt-BR "
                      f"(faltam {sorted(set(ref_ach) - set(ach))[:5]}, sobram {sorted(set(ach) - set(ref_ach))[:5]})")
    for aid, entry in ach.items():
        for field in ("title", "detail"):
            val = (entry or {}).get(field)
            if not isinstance(val, str) or not val.strip():
                errors.append(f"{loc}: conquista {aid}.{field} vazia")
            elif aid in ref_ach:
                errors.extend(strict_same(loc, f"achievements.{aid}.{field}", ref_ach[aid][field], val))
    return errors


def check_pack(pack_dir, root):
    """Confere um ContentPack gerado contra a biblioteca de idiomas."""
    pack_dir, root = pathlib.Path(pack_dir), pathlib.Path(root)
    pack = json.loads((pack_dir / "pack.json").read_text(encoding="utf-8"))
    strings = dict(flatten(json.loads((pack_dir / "strings.json").read_text(encoding="utf-8"))))
    loc = pack.get("language", REF)
    errors = []
    if not (root / loc / "strings.json").exists():
        return [f"pack: idioma {loc} sem biblioteca em {root}"]
    ref, lib = load(root, REF), load(root, loc)
    ref_ach, lib_ach = load_ach(root, REF), load_ach(root, loc) or {}
    for key, val in ref.items():
        if key.startswith("widget."):
            if key not in strings:
                errors.append(f"pack({loc}): falta {key} no strings.json")
            else:
                errors.extend(strict_same(loc, key, val, strings[key]))
    for a in pack.get("achievements") or []:
        aid = a.get("id")
        for field in ("title", "detail"):
            if aid in ref_ach:
                errors.extend(strict_same(loc, f"pack.achievements.{aid}.{field}", ref_ach[aid][field], a.get(field)))
            if aid in lib_ach and a.get(field) != lib_ach[aid][field]:
                errors.append(f"pack({loc}): conquista {aid}.{field} diferente de locales/{loc}/achievements.json")
    errors.extend(scan_pt(loc, "strings.json", json.loads((pack_dir / "strings.json").read_text(encoding="utf-8"))))
    errors.extend(scan_pt(loc, "pack.json", pack))
    return [e.replace(f"{loc}: ", f"pack({loc}): ", 1) if e.startswith(f"{loc}: ") else e for e in errors]


def main(root):
    root = pathlib.Path(root)
    ref = load(root, REF)
    ref_ach = load_ach(root, REF)
    errors = scan_library(root, REF)
    for loc in sorted(p.name for p in root.iterdir() if p.is_dir() and p.name != REF):
        cur = load(root, loc)
        errors.extend(compare(loc, ref, cur))
        if ref_ach is not None:
            errors.extend(compare_strict(loc, ref, cur, ref_ach, load_ach(root, loc)))
        errors.extend(scan_library(root, loc))
    print("\n".join(errors) or "ok")
    return 1 if errors else 0


if __name__ == "__main__":
    args = sys.argv[1:]
    if args and args[0] == "--pack":
        errs = check_pack(args[1], args[2] if len(args) > 2 else "locales")
        print("\n".join(errs) or "ok")
        sys.exit(1 if errs else 0)
    sys.exit(main(args[0] if args else "locales"))
