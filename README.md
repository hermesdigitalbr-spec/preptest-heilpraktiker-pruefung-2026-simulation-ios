# PrepKit Text DE — base crua (whitelabel) para prep tests **sem imagens**, em **alemão**

Variante em **alemão (de-DE)** da linha de prep tests da Hermes Digital, com toda a interface
(onboarding, quiz, stats, paywall, widget — as 331 chaves de `strings.json`, as 82 conquistas
e os textos hardcoded do widget) **traduzida para alemão**, revisada para soar natural a um
falante nativo. Pronta para receber um novo nicho (prova) cujo banco de questões é **100%
texto, em alemão** (sem diagramas/imagens).

> **Use esta base quando:** a prova/banco de questões é em **alemão** e **não tem imagens**.
> Para provas em alemão **com imagens**, adapte a base `prepkit-image-template` seguindo o
> mesmo processo de tradução. Para provas em inglês/português/espanhol, use a base do idioma
> correspondente.

**Origem do fork:** este repo foi forkado de **`prepkit-text-template-ptbr`**, e não da base
inglesa. Motivo: a base pt-BR já traz o fix de `developmentLanguage`/`knownRegions` no
`project.yml` — uma base não-inglesa precisa declarar o idioma real no binário, senão o
`CFBundleDevelopmentRegion` sai como `en` e a App Store exibe **"Idioma: Inglês"** na ficha
do app. A base pt-BR está em paridade de features com a inglesa; a copy inglesa foi usada
como âncora semântica (é o original) e a pt-BR como referência de tom.

**Repositórios**
- Este repo (base sem imagem, de-DE): <https://github.com/hermesdigitalbr-spec/prepkit-text-template-de>
- Base pt-BR (origem do fork): <https://github.com/hermesdigitalbr-spec/prepkit-text-template-ptbr>
- Base original em inglês (sem imagem): <https://github.com/hermesdigitalbr-spec/prepkit-text-template>
- Base original em inglês (com imagem): <https://github.com/hermesdigitalbr-spec/prepkit-image-template>

**Regra de ouro:** nenhuma linha de Swift muda entre nichos. Um app novo = trocar o
**ContentPack** (3 JSONs), ícone, accent e a identidade (bundle/nome). Toda string com
`REPLACE` neste repo é um placeholder que você preenche.

---

## Configuração de mercado (já aplicada nesta base)

| Item | Valor |
|---|---|
| Locale ASC / fastlane | `de-DE` (pasta `fastlane/metadata/de-DE/`, `language: "de-DE"` no Fastfile) |
| Storefront StoreKit | `DEU` |
| Moeda | **EUR** |
| Preço semanal (padrão) | **5,99 €** |
| Preço mensal (padrão) | **14,99 €** |
| `developmentLanguage` / `knownRegions` | `de` |
| `pack.json → language` | `de` |
| Formato de preço no ScreenshotMode | `"5,99 €"` / `"14,99 €"` (vírgula decimal, símbolo depois, com espaço) |

> Preços são o **padrão de partida** do mercado alemão para prep test. Ajuste por nicho
> (prova profissional aguenta mais que prova de público geral) antes de criar as assinaturas
> na ASC.

---

## Decisões terminológicas do alemão (leia antes de editar copy)

O que quebra tradução de app de prova em alemão não é gramática — é terminologia de domínio.
As decisões abaixo estão aplicadas de forma consistente em `strings.json`, `pack.json` e no
widget. **Mantenha-as** ao escrever a copy do nicho.

### ⚠️ A armadilha nº 1: `lernen` vs. `studieren`

**"estudar para uma prova" = `lernen`. NUNCA `studieren`.**
Em alemão, `studieren` significa *cursar uma universidade* (ser universitário). Escrever
"Studiere für die Prüfung" soa como "matricule-se numa faculdade para a prova" — é o falso
amigo que mais destrói tradução literal PT/EN→DE neste app. Toda ocorrência de *study /
estudar* nesta base virou `lernen` (aba "Lernen", `Lernplan`, `Lernzeit`, `Lerneinheit`).

### Glossário aplicado

| EN / PT | DE | Por quê |
|---|---|---|
| exam / prova | **Prüfung** | Termo neutro e universal. Exame de estado = `Staatsexamen`. |
| mock exam / simulado | **Probeprüfung** | Simulado completo. `Prüfungssimulation` como sinônimo na copy longa. |
| practice test / teste prático | **Übungstest** | Usado na copy de compartilhamento. |
| to study / estudar | **lernen** | Ver a armadilha acima. |
| to pass / passar | **bestehen** ("die Prüfung bestehen") | Colocação fixa. |
| to fail / ser reprovado | **durchfallen** / "durch die Prüfung fallen" | `scheitern` é genérico demais (fracassar na vida). |
| score / pontuação | **Punktzahl** (`Ergebnis` p/ resultado) | |
| streak / sequência | **Serie** ("Tage in Serie") | `Streak` em alemão soa gíria importada; `Serie` é limpo e curto. |
| streak freeze / congelamento | **Joker** | Tradução literal (`Einfrieren`) não comunica nada; `Joker` é o idioma de jogo em alemão. |
| subject / matéria | **Fach** / `Fachgebiet` | `Fächer` no plural. |
| topic / tema | **Thema** (pl. `Themen`) | |
| review (repetição espaçada) | **Wiederholung** | Aba: `Wiederholen`. |
| accuracy / taxa de acerto | **Trefferquote** | Muito mais idiomático que `Genauigkeit`. |
| achievements / conquistas | **Erfolge** | Padrão de plataforma de jogo em alemão. |
| exam state / estado da prova | **Bundesland** | Equivalente federativo alemão (a prova varia por Bundesland). |

### Registro e tipografia

- **Registro `du` (informal), 100% consistente.** Padrão de app de consumo em alemão; nenhum
  `Sie` em lugar nenhum. Ao escrever copy de nicho, siga o `du` mesmo em prova formal.
- **Substantivos sempre com maiúscula** (`Fragen`, `Prüfung`, `Serie`, `Fach`).
- **Compostos longos são risco de layout.** Alemão estoura botão/card com facilidade. Onde o
  composto correto não cabia, a copy foi reescrita mais curta em vez de truncada — ex.:
  `Bestehenswahrscheinlichkeit` → **`Bestehenschance`**; "Durchschnittliche Punktzahl" →
  **`Ø Punktzahl`** (o card de stat tem 1/3 da largura da tela).
- **Números e preços:** vírgula decimal e ponto de milhar (`1.000 Fragen`, `14,99 €`), símbolo
  do euro **depois** do número com espaço, `%` separado por espaço (`90 %`).

---

## O que já está pronto vs. o que é placeholder

| Já pronto (não mexer) | Placeholder (você preenche — procure por `REPLACE`) |
|---|---|
| Todo o app Swift (onboarding, quiz, stats, paywall, widget) | `HeilpraktikerPrep/ContentPack/pack.json` (exam, subjects, products, legal…) |
| Design system, componentes, lógica testada | `HeilpraktikerPrep/ContentPack/questions.json` (banco de questões) |
| 82 achievements em alemão (reutilizáveis) | `HeilpraktikerPrep/ContentPack/strings.json` (copy de onboarding do nicho) |
| `ContentValidator` (valida o pack no launch) | Ícone (`Assets.xcassets/AppIcon`) e accent (`accentHex`) |
| `project.yml` parametrizado (marcadores `← EDITAR`) | Identidade: nome do target, bundle id, display name |
| `fastlane/` (lanes de build/submit) | `fastlane/metadata/de-DE/*` + URLs legais |

O app **compila e roda agora**, com **15 questões-placeholder** (só texto) e **5 subjects
genéricos**, para você ver a estrutura funcionando e tirar screenshots.

---

## O ContentPack (o único lugar que define o nicho)

`HeilpraktikerPrep/ContentPack/` tem 3 arquivos, todos `Codable` e validados no launch:

### `pack.json` — configuração do nicho
```jsonc
{
  "examName": "...",          // nome completo da prova (em alemão)
  "examShortName": "EXAM",    // sigla curta (widget, share card)
  "tagline": "...",           // promessa de 1 linha
  "language": "de",           // já configurado — não mexer
  "accentHex": "#1B9AF7",     // cor de destaque do app
  "subjects": [ { "id", "name", "sfSymbol" } ],   // Fächer (SF Symbols da Apple)
  "mockExam": { "questionCount", "minutes", "passPercent" },
  "products": { "weekly", "monthly" },            // product IDs do StoreKit/ASC
  "appStoreUrl": null,        // preencher após registrar na ASC (null = share sem link)
  "legal": { "privacyUrl", "termsUrl", "supportEmail", "supportUrl" },
  "achievements": [ ... ]     // 82, já em alemão — pode manter como está
}
```

### `questions.json` — o banco (array de questões, texto)
```jsonc
{
  "id": "STRING-UNICO",
  "subjectId": "subject-1",   // precisa existir em pack.subjects
  "difficulty": 2,            // 1 (fácil) … 3 (difícil)
  "text": "...",
  "choices": ["...","...","...","..."],   // 2 a 6 alternativas
  "correctIndex": 0,          // índice da correta em choices
  "explanation": "..."        // mostrada após responder
}
```
> Precisa de imagem em alguma questão? O campo `imageName` (asset) ou `imageURL` (remota)
> funciona aqui também — mas se o nicho for visual, prefira `prepkit-image-template`.

### `strings.json` — 100% do copy de UI
Struct `UIStrings`, **331 valores, todos obrigatórios** (o app não sobe se faltar chave).
O chrome já é genérico; ajuste sobretudo o bloco `onboarding`, que muda bastante por nicho.
**Nunca** coloque string visível direto na view Swift. Ao editar, respeite o glossário e o
registro `du` acima.

> Nota editorial: `onboarding.painFailingPoints` tem **2 itens** nesta base (a inglesa tem 3).
> É decisão editorial herdada do pt-BR — **não** restaure o terceiro item.

---

## Como criar um app novo a partir deste template

1. **Clonar e renomear a identidade**
   ```bash
   gh repo clone hermesdigitalbr-spec/prepkit-text-template-de meu-app-novo
   cd meu-app-novo && rm -rf .git && git init
   ./scripts/rename-app.sh HeilpraktikerPrep MeuAppNovo meuappnovo "Mein Neues App"
   #                        <alvo atual> <novo alvo> <slug bundle> "<display>"
   ```
   Renomeia target/dirs/arquivos, bundle id (`app.hermesdigital.meuappnovo`), app group,
   URL scheme e product IDs.

2. **Preencher `pack.json`** — exam, subjects (com SF Symbols), mockExam, products, legal,
   accentHex. Nomes de Fächer em alemão, substantivos com maiúscula.

3. **Trocar `questions.json`** pelo banco real (em alemão). Duas rotas:
   - Colocar o JSON-fonte em `~/🧠 GERAL - CRIACAO APPS/question-banks/` e rodar
     `python3 scripts/build-contentpack.py` (ajuste o mapeamento de subjects no topo).
   - Ou substituir o arquivo direto, respeitando o schema acima.

4. **Ajustar `strings.json`** — reescreva o `onboarding` para o tom/nicho, mantendo `du`.

5. **Ícone + accent** — troque `AppIcon`/`ShareAppIcon` em Assets e o `accentHex`.

6. **fastlane + legal** — preencha `fastlane/metadata/de-DE/*` e publique as páginas legais;
   atualize as URLs em `pack.json` e nos metadados.

7. **Gerar e rodar**
   ```bash
   export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
   /opt/homebrew/bin/xcodegen generate      # nunca commitar o .xcodeproj
   xcodebuild -project MeuAppNovo.xcodeproj -scheme MeuAppNovo \
     -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
   ```

---

## Regras que o conteúdo precisa satisfazer (`ContentValidator`)
O app valida no launch e **crasha em dev** se algo estiver errado:
- `subjects` não vazio; ids de subject únicos.
- Todo `subjectId` de questão existe em `subjects`.
- `choices`: 2 a 6; `correctIndex` dentro do range; `difficulty` 1–3.
- `text` e `explanation` não vazios; ids de questão únicos.
- `mockExam.questionCount` ≤ número de questões.
- `dailyQuestionsCount` e `quickQuizCount` > 0.

Por isso o template já vem com um seed mínimo (15 questões) — mantenha ≥ `mockExam.questionCount`.

---

## Checklist antes de submeter
- [ ] `pack.json` sem nenhum `REPLACE`; `appStoreUrl` preenchido após ASC
- [ ] `pack.json → language` continua `"de"`
- [ ] `questions.json` = banco real, em alemão; nenhuma questão `SAMPLE-*`
- [ ] `strings.json` com onboarding do nicho, registro `du` consistente
- [ ] Nenhum composto alemão estourando botão/card (checar nos screenshots)
- [ ] Ícone, accent e display name trocados
- [ ] Páginas legais no ar; URLs batendo em `pack.json` + fastlane
- [ ] Binário com `CFBundleDevelopmentRegion = de` (conferir no `.app` gerado)
- [ ] `xcodegen generate` + build + testes verdes

> Referência de arquitetura: `docs/SPEC.md` e `docs/MEMORY.md` (do app original, em PT —
> explicam as decisões de produto e o porquê de cada camada).
