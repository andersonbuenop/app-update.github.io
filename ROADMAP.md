# Roadmap do Projeto SCCM Application Status

Este documento registra as melhorias planejadas e ideias técnicas para implementação futura, visando tornar o sistema mais robusto e independente de fontes únicas.

## 1. Integração com Scoop (Prioridade Alta)
Aproveitar a arquitetura "machine-friendly" do Scoop (arquivos JSON no GitHub) para obter versões de apps de desenvolvimento.
- **Fonte:** Repositórios `Main` e `Extras` do Scoop.
- **Método:** Leitura direta de JSON (sem necessidade de instalar o binário do Scoop).
- **Vantagem:** Rápido, confiável para ferramentas como Git, Node, Python, 7-Zip.

## 2. Estratégia Multi-Source (Fallback)
Implementar lógica de redundância para busca de versões.
- **Funcionamento:** Se a fonte principal falhar (ex: RuckZuck fora do ar), tentar a próxima da lista.
- **Ordem sugerida:**
  1. RuckZuck (API Rápida)
  2. Scoop (JSON GitHub)
  3. Chocolatey (API OData - mais lenta)
  4. GitHub Releases (Específico por repo)
  5. Web Scraping (Último recurso)

## 3. Identificador Canônico (Canonical ID)
Resolver o problema de nomes diferentes para o mesmo software entre fontes.
- **Conceito:** Criar um ID interno único (ex: `google-chrome`).
- **Mapeamento:**
  ```json
  "google-chrome": {
      "winget": "Google.Chrome",
      "choco": "googlechrome",
      "ruckzuck": "Google Chrome",
      "scoop": "googlechrome"
  }
  ```

## 4. Winget (Leitura de Manifesto)
Considerar leitura passiva do repositório `microsoft/winget-pkgs`.
- **Restrição:** Não executar `winget.exe` (bloqueado).
- **Abordagem:** Parsear arquivos YAML do repositório oficial no GitHub se necessário.

## 5. Interface Web - Botão "Forçar Atualização"
Permitir execução do script `apps_update.ps1` diretamente pelo navegador.
- **Backend:** Evoluir `server.py` para interceptar uma rota de API (ex: `/api/update`).
- **Segurança:** O backend executa apenas o comando pré-definido via `subprocess`.
- **Feedback:** O frontend exibe um spinner/loading enquanto o script roda e recarrega a tabela ao finalizar.

## 6. Classificação de Aplicações (Comercial vs Interno)
Aproveitar a nova coluna `TipoApp` (`app comercial` / `app interno`) para evoluir o comportamento do sistema.
- **Visão:** Tratar aplicações internas como primeiro‑classe no fluxo (sem scraping externo).
- **Melhorias futuras:**
  - Filtros dedicados na interface web para TipoApp.
  - Relatórios separados para apps internos, com foco em conformidade e governança.
  - Possibilidade de importar/exportar listas de apps internos por área/equipe.

## 7. Gestão de Licenças (Free vs Licensed)
Aproveitar o campo de licença totalmente manual (`Free` / `Licensed`) para próximos passos.
- **Ideias:**
  - Painel de resumo mostrando % de apps licenciados vs free.
  - Exportação de CSV filtrando apenas apps `Licensed` para análise financeira.
  - Regras opcionais de alerta quando um app licenciado está `UpdateAvailable`.

## 8. Otimização de Scraping e Performance
Reduzir chamadas desnecessárias a sites externos e tornar as execuções mais previsíveis.
- **Direções futuras:**
  - Cache de resultados de scraping por execução (evitar chamadas repetidas para duplicados).
  - Métricas simples (tempo total, quantidade de apps por fonte, quantidade de timeouts).
  - Estratégias automáticas de backoff quando uma fonte estiver instável.
