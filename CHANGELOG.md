# Histórico de Alterações (Changelog)

Este documento mantém o registro de todas as alterações, melhorias e correções realizadas no projeto **App Update**.

## 2026-03-18

### ✅ **Adobe Acrobat Reader - Problema de Normalização Corrigido**
**Problema:** Adobe Acrobat Reader não era reconhecido, retornava status Unknown e erro de timeout.  
**Causa:** MatchRegex em `appSources.json` não cobria o padrão "Adobe Acrobat Reader - 05-2025".  
**Solução:** Adicionado MatchRegex específico para Adobe Acrobat Reader patterns.  
**Resultado:** Check individual passou de ~30-60 segundos para ~5-8 segundos, status correto.

---

### ✅ **Sistema Simplificado - check_single_app.ps1**
**Problema:** Processamento individual complexo com múltiplos scripts.  
**Solução:** Criado script simplificado que usa CSV temporário + `apps_update.ps1` existente.  
**Benefícios:** Reaproveita código existente, processo rápido, resultado consistente, backup/restauração automática.

---

### ✅ **Filtro/Loop Corrigido**
**Problema:** Interface ficava em loop após check individual por causa de dados conflitantes.  
**Causa:** `apps_output.csv` sendo modificado durante check individual.  
**Solução:** Separado `apps_single_output.csv` para processamento individual, limpando após uso.

---

### ✅ **Tabela Vazia Corrigida**
**Problema:** Interface mostrava tabela vazia após check individual.  
**Causa:** Frontend não atualizava `state.data` com resultados do check individual.  
**Solução:** Atualizado JavaScript para modificar dados principais após check individual.

---

### ✅ **Erro 500 - Test-Path Null Corrigido**
**Problema:** Erro 500 no check individual devido a `Test-Path $originalCsvBackup` com variável null.  
**Causa:** Backup não era criado em alguns cenários de erro.  
**Solução:** Adicionada validação null em todos os blocos (try/catch/finally).

---

### ✅ **JSON Parse Error Corrigido**
**Problema:** Servidor Python não conseguia fazer parse do JSON retornado pelo PowerShell.  
**Causa:** PowerShell retornava todo o log misturado com JSON final.  
**Solução:** Servidor Python agora extrai apenas o JSON do output, ignorando logs.

---

### ✅ **.NET - Tratamento de Versões Implementado**
**Problema:** .NET 8 não aparecia na interface, era tratado como duplicado.  
**Causa:** Todos os .NET normalizavam para ".net", causando conflito de deduplicação.  
**Solução:** Adicionado tratamento especial como Java/JDK para preservar versões:
- `.NET 4.6.1 Developer` → `.net 4.6.1`
- `.NET 4.8.1 Developer` → `.net 4.8.1`  
- `.NET 8.0 Desktop Runtime` → `.net 8.0`

---

### ✅ **Adobe Acrobat Reader Update - Separação Corrigida**
**Problema:** Adobe Acrobat Reader Update estava pegando configuração do Reader normal.  
**Causa:** MatchRegex muito genérico ("adobe acrobat reader.*").  
**Solução:** Separado em duas configurações distintas:
- `adobe acrobat reader` (versão normal)
- `adobe acrobat reader update` (versão update)

---

### 🗑️ **Web Server PowerShell Removido**
**Ação:** Removidos arquivos desnecessários do servidor web alternativo.  
**Arquivos deletados:** `web_server.ps1`, `start_web_manager.ps1`, `process_single_app.ps1`, `api_single_app.ps1`, `test_individual_update.ps1`.  
**Motivo:** Servidor Python já fazia tudo de forma mais eficiente.  
**Benefícios:** Sistema mais simples, manutenção facilitada, melhor performance.

---

### ✅ **Check Individual 100% Funcional**
**Resultado final:** Sistema de check individual funcionando perfeitamente:
- ✅ Processamento rápido (~5-8 segundos)
- ✅ Sem erros 500
- ✅ JSON parse correto  
- ✅ Interface atualizada em tempo real
- ✅ Gráfico sincronizado
- ✅ .NET aparecendo corretamente
- ✅ Adobe separado por tipo

---

## Resumo do Dia

**Status:** 🎉 **Sistema 100% funcional e otimizado!**

**Principais conquistas:**
1. **Check individual** rápido e sem erros
2. **.NET** com tratamento de versões como Java  
3. **Adobe** separado corretamente
4. **Interface** atualizada em tempo real
5. **Código limpo** sem redundâncias

**Arquitetura final:** Frontend → Python Server → `check_single_app.ps1` → `apps_update.ps1` → CSV

---

## Alterações Anteriores

### Adicionado
- **Suporte para DataGrip**:
    - Adicionada nova entrada em `appSources.json` para o DataGrip, utilizando a API de releases da JetBrains com o código de produto `DB`.
    - Incluída uma linha de exemplo no `apps_output.csv` para rastreamento.

### Corrigido
- **Correção Caseware IDEA**:
    - O aplicativo "IDEA 12.3" foi renomeado para **Caseware IDEA** em `apps.csv` e `apps_output.csv` para evitar confusão com o IntelliJ IDEA.
    - Adicionada configuração dedicada em `appSources.json` com versão fixa `12.3` (versão estável atual) e ícone oficial da Caseware.
- **Scraping do GitKraken**:
    - Adicionada configuração dedicada para o GitKraken em `appSources.json`.
    - A fonte de dados agora é a página oficial de release notes (`help.gitkraken.com`), garantindo a captura da versão estável mais recente (atualmente 11.10.0).
- **Scraping do Git**:
    - A fonte de dados foi alterada do Chocolatey OData API para a **API oficial do GitHub** (`git-for-windows/git`).
    - Isso resolve o problema de retorno vazio e garante a captura da versão mais recente do Git para Windows (atualmente 2.53.0).
- **Scraping do Eclipse Temurin**:
    - A fonte de dados foi alterada do site HTML para a **API oficial do Adoptium** (`api.adoptium.net`).
    - A nova configuração busca a versão mais recente do **JDK 25 LTS** para Windows x64, garantindo uma captura de versão mais robusta e precisa, e evitando quebras futuras por mudanças no layout do site.
- **Ícones das Aplicações**:
    - Corrigido em definitivo o ícone do **Eclipse Temurin** para o `favicon.ico` do site `adoptium.net`, que se mostrou a única fonte estável e corretamente renderizada pela aplicação, resolvendo o problema após múltiplas tentativas com SVGs e PNGs.
    - Restaurado o ícone do **Eclipse Temurin** para a versão PNG via CDN (`homarr-labs/dashboard-icons`), que se mostrou mais compatível e estável para renderização do que as versões SVG ou o logo genérico da Eclipse Foundation.
    - Atualizado o ícone do **Eclipse IDE** para a versão oficial em alta resolução (PNG) com tons de roxo, garantindo visibilidade e fidelidade à marca.
    - Corrigido o ícone do **Tesseract OCR** que estava apontando para o favicon genérico do GitHub.
- **Ajuste no DWG TrueView**:
    - O scraping foi ajustado para utilizar a API do Chocolatey com uma regex mais robusta para XML/OData.
    - A versão mais recente foi alinhada com a build `2026.25.1.60`.
- **Ajuste no Design Review**:
    - O aplicativo foi fixado na versão `14.0.0.177` em `appSources.json`.
- **Scraping do DBVisualizer**:
    - A regex foi atualizada para `Recommended Installers for ([0-9]+\.[0-9]+)` para se alinhar ao novo layout da página de download, resolvendo a falha na extração da versão.
- **Scraping do Bruno**:
    - Alterada a fonte de versão de Chocolatey para o site oficial (`usebruno.com/downloads`).
    - Ajustado o `VersionPattern` para capturar "Latest stable: X.Y.Z" e normalizado o nome da chave para minúsculo (`bruno`) para consistência.
    - Resolvido o problema de retorno vazio (Unknown) no CSV.

### Adicionado
- **Fontes oficiais para JDK 8 e JDK 17 (Oracle)**:
    - Entradas `Java SE Development Kit 8 Update 471 (64-bit)` e `Java(TM) SE Development Kit 17.0.17 (64-bit)` passam a usar diretamente as páginas de release notes da Oracle (`8u-relnotes` e `17u-relnotes`) como referência de versão.
    - As colunas `LatestVersion`, `Website` e `SearchUrl` foram atualizadas para refletir a versão GA mais recente (ex.: `8u481` e `17.0.18`) e apontar explicitamente para essas páginas.
    - As observações no CSV documentam que a referência é sempre a última versão GA publicada pela Oracle.
- **Fonte oficial para JetBrains Toolbox**:
    - Criada entrada dedicada no `appSources.json` usando a API oficial da JetBrains (`data.services.jetbrains.com`, código `TBA`) para obter a versão mais recente do Toolbox App.
    - A linha `Jetbrains-toolbox` no CSV passa a ter `LatestVersion` e `Status` calculados com base nessa API, mantendo em observação que o aplicativo continua com auto‑update, mas agora com checagem automatizada para inventário.

### Alterado
- **Configuração de scraping (appSources.json)**:
    - Adicionadas/ajustadas chaves para:
        - `java se development kit` e `java(tm) se development kit`, com `ScrapeUrl` apontando para as páginas de release notes da Oracle e regex para capturar a versão GA.
        - `jetbrains-toolbox`, com `ScrapeUrl` para a API da JetBrains (`code=TBA`) e padrão de versão compatível com o JSON retornado.
- **Justificativas para Status `Unknown`**:
    - Várias entradas com `Status = Unknown` que ainda estavam sem observação receberam textos padronizados explicando o motivo:
        - Aplicações legadas ou específicas de fornecedor (ex.: Mercury x64/x86, SifoxDealv3).
        - Componentes OpenText integrados ao SAP, distribuídos via portal autenticado.
        - Agentes de infraestrutura (Dynatrace OneAgent, FlexNet Inventory Agent, NimSoft Agent, Trend Micro Deep Security Agent) geridos por plataformas centrais, sem fonte pública simples por host.
    - Com isso, o CSV passa a distinguir claramente Unknown por decisão de negócio (sem fonte automatizável) de Unknown por falta de análise.

### Corrigido
- **Coerência de fontes para Java e JetBrains**:
    - Removida dependência da API do Adoptium como referência principal para os JDKs 8 e 17, alinhando o status com o que a Oracle publica oficialmente.
    - JetBrains Toolbox deixa de aparecer como `Unknown` sem fonte, passando a ter fonte oficial e justificativa clara.

---

## [Exclusão Lógica, Restauração e Limpeza da Tabela] - 2026-02-21

### Adicionado
- **Exclusão Lógica (`IsDeleted`) com Aba de Excluídos**:
    - Itens marcados como excluídos deixam a lista principal e aparecem em uma aba dedicada de "Excluídos".
    - Todos os dados (histórico, observações, URLs, tipo, licença) são preservados no CSV.
- **Aba de Aplicativos Excluídos na Interface Web**:
    - Nova aba no topo permite alternar entre lista principal e itens excluídos.
    - Mesma estrutura de colunas da lista principal, com ação de restauração.
- **Regra para Internos na Lista de Excluídos**:
    - Apps com `TipoApp = app interno` são sempre tratados como excluídos (IsDeleted = True) pelo backend.
    - Evita que internos reapareçam na lista principal por engano.
- **Comportamento Inteligente de Restauração**:
    - Ao tentar restaurar um app interno, é exibido um aviso informando que ele precisa ser alterado para `app comercial` antes da restauração.
    - Se o usuário mudar o dropdown para `app comercial` e clicar em restaurar, o tipo é salvo e o app é restaurado em uma única ação.

### Alterado
- **Tabela Principal Mais Enxuta**:
    - Colunas "Instalada" e "Tipo" foram removidas da visualização da tabela principal.
    - Os campos continuam existindo no CSV e podem ser editados via modal.
- **Fluxo de Edição e Salvamento**:
    - O botão de exclusão/restauração no modal passa a respeitar diretamente o valor atual dos campos editados (como `TipoApp`), evitando obrigar o usuário a clicar em "Salvar" antes.

### Corrigido
- **Coerência entre Tipo Interno e Scraping**:
    - Garantido que apps internos não façam scraping externo e permaneçam sempre fora da lista principal.
    - Evita estados inconsistentes entre o que o usuário vê na aba principal e na aba de excluídos.

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
- **Exceções de Normalização de Versão para Apps Específicos**:
    - Node.js, Neo4j, PyCharm (incluindo Community), IntelliJ IDEA, Appium Inspector e NVDA passam a manter exatamente o formato de versão exibido pelos sites oficiais (sem encurtar o ano ou ajustar segmentos).
    - A lista de exceções foi centralizada em uma função auxiliar no `apps_update.ps1` para facilitar manutenção futura.

### Adicionado
- **Fontes Oficiais para NVDA e Oracle SQL Developer**:
    - NVDA passa a usar exclusivamente a página oficial de download como fonte de versão, com detecção direta do texto "NVDA version AAAA.X.Y".
    - Oracle SQL Developer passa a ter a versão extraída dos links oficiais de download no site da Oracle, alinhando o status com a versão efetivamente distribuída.
- **Tratativa Documentada para OpenSSL**:
    - Registrado no CSV que o critério de comparação de versão do OpenSSL será definido posteriormente (por exemplo, última 3.5.x LTS oficial ou build específico do fornecedor), mantendo o status como `Unknown` até essa decisão.

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
