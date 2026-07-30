# SPEC — HeilpraktikerPrep (app base de prep tests americanos)

> **Status:** aprovado por Gio em 2026-06-10 (com ajustes de paywall).
> **Referências:** vídeo `Ref 01.MP4` (app MCAT Prep) · `PRINCIPIOS_GERAIS.md` · `iOS-PLAYBOOK.md` · `onboarding-playbook-i-am` · `MONETIZACAO.md`.

---

## 1. Visão

**HeilpraktikerPrep** é o app-mãe da linha de prep tests da Hermes Digital: um "Duolingo para prep tests" — ultra user-friendly, simples, visualmente agradável, focado em UX/UI. O codebase é 100% genérico; cada nicho (DMV, ASVAB, NREMT, TEAS, CCRN, OAB, Canadian Citizenship, Firefighter I&II, ...) vira um app próprio trocando apenas o **ContentPack** (3 JSONs + assets), ícone, accent e bundle ID. Nenhuma linha de Swift muda entre clones — inclusive para lançar em outro idioma/país.

**Conteúdo mock de desenvolvimento:** Prep Kit Text (~150 perguntas fictícias porém plausíveis, 5 matérias).

## 2. O que NÃO vamos construir (v1)

- Backend / contas / sync em nuvem — tudo local (guest-first, sem login)
- **Multi-idioma em runtime** — sem seletor de idioma, sem `xcstrings` com 15 línguas, sem pipeline de tradução (override consciente da Lei 7 Hermes). Cada app é **um único idioma**, mas a base é **language-agnostic**: o idioma inteiro do app vem do ContentPack (ver §10)
- Vídeo-aulas, flashcards, conteúdo teórico longo — só perguntas + explicações
- Ads — monetização é subscription pura
- Leaderboards / social
- iPad (iPhone only, portrait)
- Notificações push remotas (apenas locais)
- Geração dinâmica de perguntas por IA in-app

## 3. Arquitetura content-pack

```
HeilpraktikerPrep/HeilpraktikerPrep/
├── App/            AppEntry, AppRouter (fase: onboarding → main), AppSession (@Observable)
├── Models/         Question, Subject, ContentPack, QuizAttempt, AnswerRecord, UserProfile, StudyPlan
├── Logic/          QuizEngine, ScoringLogic, StreakLogic, PlanGenerator, QuestionSelector (puro Swift, testável)
├── Services/       ContentStore, ProgressStore, IAPService (HermesShared), NotificationService, ...
├── Design/         AppColor, AppFont, AppSpacing, AppRadius, AppMotion + Components/
├── Features/       Onboarding/, Paywall/, Home/, Quiz/, Study/, Review/, Stats/, Settings/
├── ContentPack/    pack.json, questions.json, strings.json, Illustrations/
└── Resources/
```

### pack.json (config por nicho)
- `examName`, `examShortName`, `tagline`
- `accentHex`
- `subjects[]`: `{ id, name, sfSymbol }` (strings finais em inglês)
- `mockExam`: `{ questionCount, minutes, passPercent }`
- `dailyQuestionsCount` (default 10), `quickQuizCount` (default 10)
- `products`: `{ weekly, monthly }` (product IDs)
- `onboarding`: overrides de copy (strings finais em inglês)

### questions.json
- `{ id, subjectId, difficulty (1–3), text, choices[4–5], correctIndex, explanation }`

### strings.json (todas as strings de UI do app)
- Struct `UIStrings` (`Codable`, **todos os campos obrigatórios**) com 100% do copy de interface: tabs, botões, paywall, onboarding base, stats, settings, empty states, mensagens de resultado.
- Decode falha no launch (em dev) se faltar qualquer chave — validação quase compile-time.
- Default da base em inglês (DMV). Clone OAB = traduzir este arquivo + questions.json. **Zero literal de string visível em views Swift.**

Pack, perguntas e strings são `Codable` + validados no load (fail fast em dev, fallback gracioso em prod).

## 4. Onboarding (~20 telas, data-driven)

Fluxo definido em `OnboardingFlow` (array de steps tipados); copy em inglês, com overrides do pack.

| # | Tela | Tipo |
|---|---|---|
| 1 | Value prop 1 — "Practice questions created by experts" | hero ilustrado |
| 2 | Value prop 2 — "Quiz modes for every way you study" | hero ilustrado |
| 3 | Nível atual (Newbie / Skilled / Master / Expert) | single-select |
| 4 | Objetivo (passar na prova / conhecimento / habilidades / vencer barreiras) | single-select |
| 5 | Já fez a prova antes? (nunca / uma vez / mais de uma) | single-select |
| 6 | Maior preocupação (reprovar / falta de tempo / matéria extensa / ansiedade) | single-select |
| 7 | Reflexão da dor (texto puro, tom empático) | marketing |
| 8 | Framing da solução — o "método" (prática espaçada + foco em pontos fracos) | marketing |
| 9 | Minutos por dia (10 / 15 / 30 / 60+) | single-select |
| 10 | Dias da semana (chips Seg–Dom) | multi-select |
| 11 | Horário de estudo preferido (slider 0–24h sobre ilustração skyline) | slider |
| 12 | Data da prova (calendar picker + contador "X days left") | date |
| 13 | Meta de streak (7 / 14 / 30 dias) | single-select |
| 14 | Notificações (embrulhada em benefício: "seu plano te lembra na hora certa") | permission |
| 15 | Matérias que mais preocupam (multi-select, vem do pack) | multi-select |
| 16 | "Personalizing your plan..." (loading animado com % e sub-etapas) | loading |
| 17 | "Your Personal Study Plan is Ready!" (gráfico de evolução + resumo do plano) | marketing |
| 18 | Paywall | paywall |
| 19 | Welcome (transição para o app) | marketing |

Regras (playbook i-am): single-select auto-avança ~350ms; multi-select exige Continue; skip pequeno cinza topo-direita só em perguntas (pula 1 tela); subheadline explica o porquê de cada pergunta; swipe-back livre, swipe-forward bloqueado; **zero números fabricados / prova social falsa** (detrator Apple).

## 5. Paywall

**Título:** "Unlock Your Personal Plan" + lista de features (perguntas de especialistas, todos os modos de quiz, plano personalizado, sem limites).

**Planos:**
| Plano | Preço default | Trial |
|---|---|---|
| Weekly | $5.99/week | — |
| **Monthly** (destaque, pré-selecionado, badge "SAVE 37%") | $14.99/month | **3 dias grátis** |

**Timeline visual (apenas quando Monthly selecionado):**
```
✅ ~~Install the app~~        (riscado, já feito)
🔓 Today — Free access begins (3 days)
💎 Day 3 — You become a member
```
- **Sem etapa de lembrete** e **sem toggle "remind me"** (decisão Gio + regra Hermes: lembrete destrói conversão líquida).
- Linguagem de pertencimento: "you become a member" — nunca "cobrança"/"billing" na timeline.

**CTA:**
- Monthly selecionado → **"Try for $0.00"** + subtítulo "3-day free trial, then $14.99/month. Cancel anytime."
- Weekly selecionado → **"Continue"** + subtítulo "$5.99/week. Cancel anytime." (timeline some)

**Compliance (3.1.2c):** preço + período na mesma tela do CTA; links "Terms of Use", "Privacy Policy" e "Restore Purchases" sempre visíveis; X para fechar (free path). "Secured with App Store. Cancel anytime."

**Product IDs (placeholders da base):** `app.hermesdigital.prepbase.weekly` / `app.hermesdigital.prepbase.monthly`. Arquivo `Products.storekit` no repo para testar trial/compra no simulador.

**Re-apresentação:** paywall reaparece ao tocar feature PRO e via banner na Home. Nunca bloqueia 100% do app.

## 6. Estrutura do app (5 tabs)

- **Home:** saudação + strip semanal com streak, card "Daily Questions" (CTA principal do dia), banner "Unlock all X+ questions", grid de modos: Quick 10 · Timed · Missed Questions · Collected · Mock Exam · Custom Quiz (PRO badge nos gated).
- **Study:** anel de progresso geral + lista de matérias com % e continue.
- **Review:** histórico de perguntas respondidas, filtros (todas / erradas / marcadas), tap abre a pergunta com explicação.
- **Stats:** streak, accuracy, gráfico semana/mês/trimestre, análise por matéria (barras), totais.
- **Settings:** modo de quiz (Learning / Quick / Mock), data da prova, meta diária, notificações, dark mode (Light/Dark/System), restore purchases, share, rate, Terms/Privacy, reset progress, contact.

### Free path (reviewer + usuário free)
- Grátis: Daily Questions (10/dia) + Quick 10 + Review/Stats do que respondeu.
- PRO: Timed, Missed, Collected, Mock, Custom, banco completo de perguntas.

## 7. Quiz engine

- **Modos de feedback:** Learning (explicação instantânea, verde/vermelho na hora) · Quick (feedback no fim) · Mock (sem feedback, timer, simula prova).
- **Tela de quiz:** progresso "Question n/m", controle de fonte (aA), bookmark, alternativas A–E, explicação expansível, Continue, quit-confirm ("View Results / Quit / Keep Going").
- **Resultado:** score % com mensagem por faixa, streak, tempo, Retake / Review, breakdown por matéria, answer card (grid verde/vermelho/flag).
- **QuestionSelector:** daily = mistura ponderada pelas matérias fracas do usuário; missed = erradas ainda não re-acertadas; mock = distribuição proporcional do pack.
- **Streak:** dia conta com ≥1 quiz completado; StreakLogic pura com testes.

## 8. Design system

- Tokens antes de qualquer view; altitude **Standard** (12–20pt spacing, 8–16pt radius).
- `AppColor`: background, surface, surfaceHigh, accent (do pack), textPrimary/Secondary/Dim, border, success, error — adaptativos light/dark.
- `AppFont`: display/heading/body/bodyMedium, rounded, Dynamic Type via relativeTo.
- `AppMotion`: snap/bouncy/smooth. Haptics em todo CTA e em acerto/erro.
- Componentes primitivos: `Card`, `PrimaryCTAButton`, `SelectableOptionCard`, `SettingsRow`, `SectionLabel`, `ProgressRing`, `ProBadge`.
- Ilustrações genéricas reutilizáveis em todos os nichos — ver `ILLUSTRATIONS.md` (geradas por Gio no Nano Banana).

## 9. Dados e persistência

- Conteúdo: JSONs do bundle via `ContentStore` (read-only).
- Progresso: `ProgressStore` grava JSON em Documents (attempts, answers, bookmarks) + UserDefaults para flags leves (onboarding done, profile, settings). Imutabilidade: structs novos, nunca mutação in-place.
- Sem SwiftData/CoreData — zero migração ao clonar, 100% testável.

## 10. Idioma — único por app, definido pelo ContentPack

Decisão Gio (2026-06-10): cada app mostra **um único idioma** ao usuário (sem seletor), mas esse idioma **pode ser qualquer um** — DMV em inglês, OAB em português, ENARM em espanhol.

- **Camada 1 — conteúdo de nicho:** perguntas, matérias e copy de onboarding já vivem em `questions.json`/`pack.json`, escritos no idioma do app.
- **Camada 2 — chrome de UI:** todo o resto (botões, tabs, labels, paywall, stats) vive em `strings.json` → struct `UIStrings`. Views nunca contêm string literal visível.
- Sem `L()`, sem `LanguagePreference`, sem `Localizable.xcstrings` multi-língua, sem tradução em runtime.
- `pack.json` declara `language` (ex.: `"en"`, `"pt-BR"`) → usado para `CFBundleDevelopmentRegion`/locale de formatação de datas e números; moeda do paywall vem automática do StoreKit (`displayPrice`).
- Lançar para outro país = traduzir 2 arquivos (`strings.json` + `questions.json`/`pack.json`). Zero Swift.

## 11. Testes

- Swift Testing, TDD na camada Logic: QuizEngine, ScoringLogic, StreakLogic, PlanGenerator, QuestionSelector, decoding/validação do ContentPack. Meta ≥80% em Logic/Models.
- `ScreenshotMode` (launch arg `-screenshot <fase>`) com estado mockado para pipeline de screenshots.

## 12. Métricas de sucesso (pós-launch, por clone)

- Free→Trial ≥ 40% · Trial→Paid ≥ 35% · D7 retention ≥ 25% · paywall conversion ≥ 3% · crash < 0.5%.

## 13. Como clonar para um nicho novo (resumo)

1. Duplicar repo → renomear slug (script futuro `clone.sh`)
2. Trocar `ContentPack/pack.json` + `questions.json` + ícone + accent
3. Se idioma ≠ inglês: traduzir `strings.json` (1 arquivo cobre 100% da UI)
4. Ajustar bundle ID / product IDs / display name no `project.yml`
5. Revisar copy de onboarding (overrides do pack)
5. Seguir Fases 04–05 do ROTEIRO (legal, pricing, ASC, fastlane)
