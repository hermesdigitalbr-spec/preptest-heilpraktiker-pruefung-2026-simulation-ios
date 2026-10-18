#!/usr/bin/env bash
# Cria um app novo a partir da test-base: idioma + formato + rename.
# Uso: scripts/new-app.sh <TargetName> <bundle-sufixo> <locale> [multipleChoice|trueFalse] ["Display Name"]
# Ex.: scripts/new-app.sh AsvabPrep asvabprep en
set -euo pipefail
cd "$(dirname "$0")/.."

[[ $# -ge 3 ]] || { echo "uso: $0 <TargetName> <bundle-sufixo> <locale> [multipleChoice|trueFalse] ["Display Name"]" >&2; exit 1; }
target="$1"; suffix="$2"; locale="$3"; format="${4:-multipleChoice}"

[[ "$target" =~ ^[A-Z][A-Za-z0-9]+$ ]] || { echo "TargetName inválido: $target" >&2; exit 1; }
[[ "$suffix" =~ ^[a-z][a-z0-9]+$ ]] || { echo "bundle-sufixo inválido (só a-z0-9): $suffix" >&2; exit 1; }
[[ "$format" == multipleChoice || "$format" == trueFalse ]] || { echo "formato inválido: $format" >&2; exit 1; }
[[ -f "locales/$locale/strings.json" ]] || { echo "idioma sem biblioteca: $locale" >&2; exit 1; }
[[ -f "locales/$locale/achievements.json" ]] || { echo "idioma sem conquistas: locales/$locale/achievements.json" >&2; exit 1; }
[[ -d TestBase ]] || { echo "target TestBase não encontrado (script já rodou?)" >&2; exit 1; }

# 1) Gate de idioma: só o idioma escolhido precisa estar completo.
python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "locales/$locale/strings.json" \
  || { echo "locales/$locale/strings.json não é JSON válido" >&2; exit 1; }
problems="$(python3 scripts/check-locales.py 2>/dev/null | grep -F "$locale:" | grep -E "^${locale//./\\.}:" || true)"
if [[ -n "$problems" ]]; then
  echo "idioma $locale incompleto:" >&2; echo "$problems" >&2; exit 1
fi

# 2) Strings + seed de conteúdo + pack.json
cp "locales/$locale/strings.json" TestBase/ContentPack/strings.json

# O seed de exemplo (questões + matérias) segue o idioma escolhido; sem ele o app
# nasceria em português mesmo sendo, p.ex., japonês (screenshots/QA saíam errados).
seed_locale="$locale"
if [[ ! -d "seeds/$seed_locale" ]]; then
  echo "AVISO: seeds/$locale não existe; usando o seed pt-BR. Crie seeds/$locale/ (questions.json + subjects.json)." >&2
  seed_locale="pt-BR"
fi
[[ -f "seeds/$seed_locale/questions.json" && -f "seeds/$seed_locale/subjects.json" ]] \
  || { echo "seed incompleto: seeds/$seed_locale precisa de questions.json e subjects.json" >&2; exit 1; }
cp "seeds/$seed_locale/questions.json" TestBase/ContentPack/questions.json

python3 - "$locale" "$format" "$seed_locale" <<'PY'
import json, sys
locale, fmt, seed_locale = sys.argv[1], sys.argv[2], sys.argv[3]
p = "TestBase/ContentPack/pack.json"
d = json.load(open(p, encoding="utf-8"))
seed = json.load(open(f"seeds/{seed_locale}/subjects.json", encoding="utf-8"))
if isinstance(seed, list):          # formato antigo: só a lista de matérias
    seed = {"subjects": seed}
d["subjects"] = seed["subjects"]
for key in ("examName", "examShortName", "tagline"):
    if key in seed:
        d[key] = seed[key]
d["language"] = locale
# Conquistas: mesmos ids/critérios, título e descrição vêm de locales/<locale>/achievements.json
ach_path = f"locales/{locale}/achievements.json"
ach = json.load(open(ach_path, encoding="utf-8"))
missing = [a["id"] for a in d.get("achievements", []) if a["id"] not in ach]
if missing:
    sys.exit(f"{ach_path} sem as conquistas: {', '.join(missing[:5])}")
for a in d.get("achievements", []):
    a["title"], a["detail"] = ach[a["id"]]["title"], ach[a["id"]]["detail"]
d.setdefault("niche", {})["questionFormat"] = fmt
with open(p, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write("\n")
if fmt == "trueFalse":
    qs = json.load(open("TestBase/ContentPack/questions.json", encoding="utf-8"))
    mc = [q.get("id") for q in qs if len(q.get("choices", [])) != 2]
    if mc:
        print(f"AVISO: formato trueFalse, mas {len(mc)} questões do questions.json não têm 2 alternativas "
              f"(ex.: {mc[0]}). O seed MC precisa ser trocado por um banco V/F antes do build.")
PY

# 3) Idioma do binário (knownRegions travado em en já custou 23 rebuilds)
LC_ALL=C sed -i '' "s/^\(  developmentLanguage:\) .*/\1 $locale/" project.yml
python3 - "$locale" <<'PY'
import re, sys
loc = sys.argv[1]
p = "project.yml"
s = open(p, encoding="utf-8").read()
s = re.sub(r"(  knownRegions:\n    - Base\n)    - [A-Za-z-]+\n", rf"\g<1>    - {loc}\n", s, count=1)
s = re.sub(r"(CFBundleDevelopmentRegion:) .*", rf"\1 {loc}", s)
open(p, "w", encoding="utf-8").write(s)
PY
grep -q "^  developmentLanguage: $locale$" project.yml || { echo "falha ao setar developmentLanguage" >&2; exit 1; }
grep -A2 "knownRegions:" project.yml | grep -q -- "- $locale$" || { echo "falha ao setar knownRegions" >&2; exit 1; }
for plist in TestBase/Info.plist TestBaseWidget/Info.plist; do
  if [[ -f "$plist" ]] && /usr/libexec/PlistBuddy -c "Print :CFBundleDevelopmentRegion" "$plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion $locale" "$plist"
  fi
done

# 3b) Metadata da App Store no idioma certo.
# O código do app (BCP-47) não é o mesmo que o App Store Connect aceita: o app
# usa "de", a loja quer "de-DE". Mapa conferido contra as ALL_LANGUAGES do
# fastlane/deliver; mantenha-o igual ao ASC_LOCALE_MAP do fastlane/Fastfile.
asc_locale_for() {
  case "$1" in
    pt-BR)   echo "pt-BR" ;;
    en)      echo "en-US" ;;
    es-MX)   echo "es-MX" ;;
    es-ES)   echo "es-ES" ;;
    de)      echo "de-DE" ;;
    fr)      echo "fr-FR" ;;
    it)      echo "it" ;;
    ja)      echo "ja" ;;
    ko)      echo "ko" ;;
    th)      echo "th" ;;
    tr)      echo "tr" ;;
    vi)      echo "vi" ;;
    zh-Hant) echo "zh-Hant" ;;
    *)       echo "" ;;
  esac
}
asc_locale="$(asc_locale_for "$locale")"
if [[ -z "$asc_locale" ]]; then
  echo "locale sem equivalente no App Store Connect: $locale (adicione ao asc_locale_for e ao ASC_LOCALE_MAP do Fastfile)" >&2
  exit 1
fi
# A pasta é só renomeada — os placeholders REPLACE continuam intactos para serem
# preenchidos depois (o texto em si é traduzido na etapa de ASO, não aqui).
if [[ -d "fastlane/metadata/pt-BR" && "$asc_locale" != "pt-BR" ]]; then
  [[ -e "fastlane/metadata/$asc_locale" ]] && { echo "fastlane/metadata/$asc_locale já existe" >&2; exit 1; }
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git mv "fastlane/metadata/pt-BR" "fastlane/metadata/$asc_locale"
  else
    mv "fastlane/metadata/pt-BR" "fastlane/metadata/$asc_locale"
  fi
  echo "metadata: fastlane/metadata/pt-BR → fastlane/metadata/$asc_locale"
fi

# 4) Rename de identidade (target, bundle, app group, URL scheme)
current_display="$(grep -m1 'CFBundleDisplayName:' project.yml | sed 's/.*CFBundleDisplayName: *//; s/ *#.*//; s/"//g')"
scripts/rename-app.sh TestBase "$target" "$suffix" "${5:-$current_display}"

echo "OK: $target (app.hermesdigital.$suffix, $locale, $format, metadata $asc_locale)."
echo "Agora preencha docs/PARTICULARIDADES.md antes do banco, ajuste o display name e rode xcodegen generate."
