# Histórico de Alterações (Changelog)

Este documento mantém o registro de todas as alterações, melhorias e correções realizadas no projeto **App Update**.

## [Regras de Versão, TipoApp e Licença] - 2026-02-21

### Adicionado
- **Coluna `TipoApp` no CSV e na Web**:
    - Novos valores suportados: `app comercial` (padrão) e `app interno`.
    - Campo visível na tabela e no modal de edição da interface web.
- **Regra para Aplicações Internas**:
    - Apps marcados como `app interno` não realizam scraping externo.
    - Mantêm as colunas de versão preenchidas apenas com dados internos (quando houver).
- **Gestão Manual de Licenças**:
    - Campo de licença agora totalmente manual (`Free` / `Licensed`).
    - Interface web com combo para selecionar o tipo de licença por aplicação.

### Alterado
- **Cálculo de Status para Apps sem Versão Instalada**:
    - Quando não há `InstalledVersion`, o backend usa `0.0.0` apenas internamente para comparação.
    - O `Status` passa a ser sempre `UpdateAvailable` nesses casos, usando a última versão do site.
    - O valor `0.0.0` nunca é gravado no CSV (colunas de versão continuam vazias).
- **Persistência de `TipoApp` e Licença**:
    - O script `apps_update.ps1` agora lê e preserva as colunas `TipoApp` e `License` existentes.
    - Atualizações sucessivas não sobrescrevem mais escolhas manuais feitas na planilha ou na web.

### Corrigido
- **Reflexo de `TipoApp` na Interface Web**:
    - A coluna `TipoApp` agora aparece corretamente na tabela e no modal.
    - Salvando pelo frontend, os valores são mantidos em `apps_output.csv`.
- **Normalização de Licença**:
    - Removida inferência automática agressiva de licença.
    - As licenças passam a respeitar exclusivamente o valor configurado pelo usuário.

## [Melhorias de Layout e Funcionalidade] - 2026-02-06

### Adicionado
- **Layout Fixo (Sticky)**: Implementada experiência de "aplicativo desktop" na web.
    - Cabeçalho global e filtros fixos no topo da tela.
    - Cabeçalho da tabela fixo logo abaixo dos filtros durante a rolagem.
    - Painel direito (Gráfico e Botão) fixo na tela enquanto a lista rola.
    - Barras de rolagem independentes para a lista de aplicativos.
- **Versionamento de Cache**: Adicionado parâmetro de versão (`?v=XX`) nas chamadas de CSS e JS para garantir carregamento imediato das alterações.

### Alterado
- **Interface Gráfica**:
    - Ícones dos aplicativos aumentados em 75% para melhor visibilidade.
    - Cores dos botões de status restauradas para o padrão (Vermelho, Verde, Amarelo).
    - Badges do filtro de status sincronizados com as mesmas cores dos botões.
    - Alinhamento corrigido da data "Última Verificação" ao lado do botão de ação.
- **Comportamento do Botão "Atualizar"**:
    - Não recarrega mais a página inteira (F5) ao concluir.
    - Texto muda para "Atualizando..." e botão fica desabilitado durante o processo.
    - Feedback visual de sucesso/erro integrado na interface.

### Corrigido
- **Persistência de Dados**: Corrigido bug onde colunas ocultas (`IconUrl`, `SourceId`, `IsNewVersion`) eram perdidas ao editar e salvar uma observação. O script agora preserva todos os campos do CSV original.

## [Não Lançado] - 2026-02-06

### Adicionado
- **Arquivo `CHANGELOG.md`**: Criado para documentar o histórico de mudanças do projeto.
- **Frontend Modularizado**:
    - `style.css`: Arquivo dedicado para todos os estilos CSS, substituindo estilos inline no HTML.
    - `script.js`: Arquivo dedicado para toda a lógica JavaScript (renderização da tabela, filtros, modal), substituindo scripts inline no HTML.
    - Classes CSS "Clean" (ex: `.status-badges`, `.table-container`, `.modal-overlay`) para melhor organização visual.
- **Backend (Python)**:
    - `server.py`: Servidor HTTP simples em Python para servir a página e aceitar requisições POST (salvamento de dados).
- **Persistência de Dados**:
    - Lógica no `apps_update.ps1` para ler o `apps_output.csv` existente antes de gerar um novo.
    - Preservação da coluna "Observacao" entre execuções do script (evita que anotações manuais sumam).
- **Notificação de Nova Versão**:
    - Implementada lógica no script PowerShell para detectar se a "Última Versão Disponível" mudou desde a execução anterior.
    - Adicionada coluna `IsNewVersion` no CSV.
    - Adicionado badge visual "NEW" (pulsante) na interface web ao lado da versão quando uma nova atualização é detectada.

### Alterado
- **Layout Fluido**: Interface ajustada para ocupar 98% da largura da tela, removendo a barra de rolagem horizontal desnecessária.
- **Tabela Ajustável**:
    - Definidas classes específicas para cada coluna (`.col-app`, `.col-version`, etc.) para controle preciso de largura.
    - Habilitada quebra de linha (wrapping) para a coluna "Aplicação" e outras colunas de texto, prevenindo estouro horizontal.
    - Definida largura de 25% para a coluna "Aplicação" para evitar que ocupe espaço excessivo quando a observação está vazia.
    - Removido `white-space: nowrap` global que forçava linhas infinitas.
    - **Cabeçalho Fixo (Sticky Header)**:
        - Movida a propriedade `position: sticky` do elemento `thead` para as células `th` individuais para maior compatibilidade.
        - Removido `overflow: hidden` da tabela para evitar conflitos com a fixação do cabeçalho.
        - Adicionado `z-index` e background opaco aos cabeçalhos para garantir que fiquem sempre sobrepostos ao conteúdo durante a rolagem.
- **Coluna "Observacao"**: 
    - Agora permite quebra de linha (text-wrap), evitando que textos longos forcem a rolagem horizontal da tabela.
    - Largura ajustada para ser automática (baseada no conteúdo ou título), removendo restrições de largura fixa.
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
- **Interface Web (HTML)**: Criação do `index.html` como interface principal (substituindo a visualização pura de CSV).
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
- **`apps_update.ps1`**: Script principal de automação e scraping.
- **`apps_output.csv`**: Arquivo de dados principal, gerado pelo PowerShell.
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
