# Biblioteca de idiomas

- `pt-BR/strings.json` é a **referência**. Toda chave nova entra primeiro no pt-BR, depois nos demais idiomas.
- Cada idioma vive em `locales/<code>/strings.json` com a mesma estrutura.
- Listas (ex.: `signupToastNames`, `reviews`) podem ter tamanho diferente por idioma, mas precisam existir e não estar vazias.
- Um idioma novo precisa de **três** peças: `locales/<code>/strings.json` (a interface, incluindo `widget.*` e `common.a11y*`), `locales/<code>/achievements.json` (título/descrição das 82 conquistas, mesmos ids do pt-BR) **e** `seeds/<code>/` com `questions.json` + `subjects.json` (o conteúdo de exemplo). O `scripts/new-app.sh` copia as duas; sem o seed ele cai no pt-BR com um aviso e o app nasce com texto de exemplo em português.
- Antes de commitar, rode: `python3 scripts/check-locales.py locales` (deve imprimir `ok`).

Nota: o `pt-BR/strings.json` atual é cópia de `TestBase/ContentPack/strings.json`; será regenerado depois que as Tasks 3–7 forem mescladas.
