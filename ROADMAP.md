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
