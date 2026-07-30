# MEMORY — HeilpraktikerPrep

Decisões arquiteturais e de produto persistentes. Toda sessão futura lê isto no início.

## 2026-06-10 — Fundação

- **HeilpraktikerPrep é o app-mãe** da linha de prep tests. Codebase 100% genérico; nicho vive em `ContentPack/` (pack.json + questions.json + Illustrations). Clonar = trocar pack, ícone, accent, bundle ID. Nenhuma linha de Swift muda entre clones.
- **Mock de desenvolvimento:** Prep Kit Text (~150 perguntas fictícias, 5 matérias). Escolhido por Gio (maior mercado, fácil de mockar).
- **Paywall (decisões explícitas do Gio):**
  - Apenas **Weekly $5.99** (sem trial) e **Monthly $14.99** (trial 3 dias, destaque, SAVE 37%).
  - Timeline **sem etapa de lembrete** ("dia 2 reminder" removido — regra Hermes: lembrete destrói conversão líquida).
  - Dia 3 = **"You become a member"** — linguagem de pertencimento, nunca "cobrança/billing".
  - CTA "Try for $0.00" quando Monthly; "Continue" quando Weekly (timeline some).
- **Onboarding híbrido ~20 telas** (estrutura do REF MCAT + blocos Hermes de dor/framing/comprometimento). Data-driven via `OnboardingFlow`, copy com overrides do pack.
- **Idioma único por app, definido pelo ContentPack (decisão Gio, override da Lei 7 Hermes):** cada app mostra UM idioma só (sem seletor, sem `L()`, sem xcstrings multi-língua) — mas o idioma pode ser qualquer um (DMV en, OAB pt-BR, ENARM es). Implementação: 100% das strings de UI em `ContentPack/strings.json` → struct `UIStrings` com campos obrigatórios; perguntas/copy de nicho em `questions.json`/`pack.json`. Proibido string literal visível em view Swift. Lançar em outro idioma = traduzir 2 arquivos, zero Swift.
- **Persistência sem SwiftData** — JSON em Documents + UserDefaults. Motivo: zero migração ao clonar, 100% testável, requisitos são simples.
- **Ilustrações genéricas reutilizáveis** (sem elementos de nicho) geradas por Gio no Nano Banana — specs e prompts em `ILLUSTRATIONS.md`.
- **Ordem de build (decisão Gio): core primeiro, onboarding por último.** 1) Fundação (tokens + ContentPack + models + logic TDD) → 2) Quiz engine + Home → 3) Tabs (Study/Review/Stats/Settings) → 4) Paywall + IAP → 5) Onboarding (~20 telas, usando prints reais do app) → 6) Polish. Motivo: onboarding vende o app que existe; pré-paywall usa screenshots reais. Onboarding continua sendo a fase de maior investimento (Lei 1), só muda a sequência.
- **IAP próprio, sem HermesShared no HeilpraktikerPrep:** o pacote hermes-shared declara GoogleMobileAds como dependência — linkar só pelo IAPService arrastaria o SDK de ads para um app sem ads. `Services/IAPService.swift` é StoreKit 2 direto (template do iOS-PLAYBOOK). Trial 3 dias APENAS no monthly (intro offer); weekly sem trial.
- **Validação de compra no simulador:** a StoreKit Configuration (`HeilpraktikerPrep.storekit`) só ativa rodando pelo scheme no Xcode (Run) — `simctl launch` não carrega. Pendente: testar compra do trial quando o Xcode estiver livre.
- **Light + dark mode desde a fundação:** toda cor via `AppColor.*` adaptativo; proibido Color literal em views. Dark mode é consequência dos tokens, não tema retrofitado.
- **Gotchas de tooling (2026-06-10):** (1) usar o xcodegen do Homebrew (`/opt/homebrew/bin/xcodegen`) — o binário em `~/bin` não tem SettingPresets e gera projeto quebrado (PRODUCT_NAME vazio); (2) o template `~/HERMES-FASTLANE/xcodegen/project.yml` tinha `settings.groups` inválido, bundle IDs com case errado e sem scheme de teste — corrigidos no project.yml deste repo; (3) `hermes-shared` 1.2.0 NÃO COMPILA (HapticsService estende View sem `import SwiftUI`) — fix de 1 linha pendente de push pelo Gio antes da Fase 4 (IAP).
- Referência visual/estrutural: vídeo `Ref 01.MP4` em `/Users/gio/PREP TESTS` (app de MCAT prep). Frames extraídos em `.ref-frames/` na mesma pasta.
