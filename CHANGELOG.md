# Histórico de Alterações (Changelog)

Este documento mantém o registro de todas as alterações, melhorias e correções realizadas no projeto **App Update**.

## [Não Lançado] - 2026-02-06

### Adicionado
- **Arquivo `CHANGELOG.md`**: Criado para documentar o histórico de mudanças do projeto.
- **Frontend Modularizado**:
    - `style.css`: Arquivo dedicado para todos os estilos CSS, substituindo estilos inline no HTML.
    - `script.js`: Arquivo dedicado para toda a lógica JavaScript (renderização da tabela, filtros, modal), substituindo scripts inline no HTML.
    - Classes CSS "Clean" (ex: `.status-badges`, `.table-container`, `.modal-overlay`) para melhor organização visual.
- **Persistência de Dados**:
    - Lógica no `apps_update.ps1` para ler o `apps_output.csv` existente antes de gerar um novo.
    - Preservação da coluna "Observacao" entre execuções do script (evita que anotações manuais sumam).

### Alterado
- **`index.html`**:
    - Removido todo CSS e JS inline.
    - Adicionadas referências para `style.css` e `script.js`.
    - Estrutura simplificada para usar classes CSS semânticas.
- **`apps_update.ps1`**:
    - Refatorado para carregar observações pré-existentes via `Import-Csv`.
    - Normalização de nomes de aplicação para garantir correspondência correta ao salvar/carregar dados.
- **Git Workflow**:
    - Adoção de versionamento Git.
    - Criação da branch `refactor-frontend` para isolar o trabalho de limpeza do frontend.

### Corrigido
- **Perda de Dados**: A coluna "Observacao" era apagada toda vez que o script `apps_update.ps1` rodava. Agora ela é preservada.
- **Estilos Inline**: O código HTML estava poluído com muitos estilos diretos, dificultando a manutenção. Isso foi resolvido com a extração para CSS.

---

## [Iteração 2] - 2026-02-05

### Adicionado
- **Coluna "Observacao"**: Inserida no CSV e na interface para permitir anotações manuais sobre cada aplicação.
- **Edição de URLs**: Adicionada funcionalidade para editar as URLs de busca (JSON/Source) diretamente pelo modal na interface web.

### Alterado
- **Cálculo de Status**: Removido o campo "Status" estático do CSV. O status (UpToDate/UpdateAvailable) passou a ser calculado dinamicamente pelo JavaScript no frontend, comparando `InstalledVersion` e `LatestVersion`.
- **Normalização de Licença**: O campo "License" passou a ser formatado automaticamente para *Title Case* (ex: "free" -> "Free") para consistência visual.

### Refatoração (Backend)
- **Regex no JSON**: Migração das expressões regulares (Regex) que estavam *hardcoded* no script PowerShell para o arquivo de configuração `appSources.json`.
    - *Benefício*: Permite ajustar regras de extração de versão sem modificar o código do script.

---

## [Versão Inicial] - 2026-01-28

### Adicionado
- **`server.py`**: Servidor HTTP simples em Python para servir a página e aceitar requisições POST (salvamento de dados).
- **`apps_output.csv`**: Arquivo de dados principal, gerado pelo PowerShell e lido pelo Frontend.
- **`appSources.json`**: Configuração centralizada das fontes de dados e URLs de busca.

### Alterado
- **Fluxo de Dados**:
    - Mudança da geração direta de HTML pelo PowerShell para geração de CSV (`apps_output.csv`).
    - O HTML agora é um template estático (`index.html`) que lê o CSV via JavaScript.
- **Normalização**:
    - Ajustes na normalização de nomes e licenças (Title Case).
    - Migração de regex hardcoded no PowerShell para o arquivo JSON de configuração.

---

## Como usar este documento

1.  Sempre que fizer uma alteração significativa (nova funcionalidade, correção de bug, refatoração), adicione uma entrada aqui.
2.  Use as seções **Adicionado**, **Alterado**, **Corrigido** ou **Removido**.
3.  Mantenha o registro cronológico reverso (o mais recente no topo).
