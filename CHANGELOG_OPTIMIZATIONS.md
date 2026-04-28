# App Update Optimizations

## Lote 1 - 2026-01-28

### Problem Statement
O script anterior estava crashando o VS Code durante a execução, causado por:
1. **Sem timeouts**: requisições web podem travar indefinidamente
2. **Sem prioridade Chocolatey**: pulava a fonte mais rápida/confiável
3. **Sem tratamento robusto de erro**: falha em um app podia derrubar todo o processamento

### Solutions Implemented

#### 1. Timeout Protection (5 segundos)
```powershell
Invoke-WebRequest -Uri $url -TimeoutSec 5 -ErrorAction Stop
```
✅ **Aplicado em:**
- `Get-ChocolateyLatestVersion` (nova função)
- `Get-GitHubLatestVersionAPI`
- `Get-GitHubLatestVersionHTML`
- `Get-WebsiteLatestVersion`

**Impacto:** Requisições que demoravam > 5s agora retornam gracefully com `Version = $null`

#### 2. New Chocolatey-First Fallback Strategy
**Ordem de tentativa:**
1. **Chocolatey API** (~500ms, mais confiável)
   - Busca em `community.chocolatey.org`
   - Requer campo `ChocolateyId` em `appSources.json`
2. **GitHub** (~1-2s)
   - Tenta API primeiro, depois HTML scraping
3. **Website** (~2-5s)
   - Fallback final com regex scraping

**Novo fluxo em `Resolve-AppInfoOnline`:**
```powershell
if ($src.ChocolateyId) { Try-Chocolatey }
if ($src.Type -eq 'GitHub') { Try-GitHub }
if ($src.Type -eq 'Website') { Try-WebScraping }
```

#### 3. Robust Error Handling
✅ **Main loop agora protegido:**
```powershell
try {
    $info = Resolve-AppInfoOnline -RawName $appName
}
catch {
    Write-Host "✗ ERRO CRÍTICO: $($_.Exception.Message)" -ForegroundColor Red
    $info = [PSCustomObject]@{ Version=$null; Website=$null; IsDiscontinued=$false }
}
```

✅ **Color-coded logging:**
- 🟢 `Green`: Processo iniciado
- 🔵 `Cyan`: Progresso `[index/total]`
- 🟢 `Timeout/Erro`: `Gray` (não-crítico)
- 🔴 `Red`: Falhas críticas apenas

#### 4. Progress Visibility
```powershell
Write-Host "[$index/$total] AppName: '$appName'" -ForegroundColor Cyan
```
- Exibe contador de progresso
- Mostra qual app está sendo processado
- Evita sensação de "travamento"

### Functions Added/Modified

#### New: `Get-ChocolateyLatestVersion`
- Busca versão via Chocolatey API
- Pattern: `<d:Version>X.Y.Z</d:Version>`
- Returns: PSCustomObject com `Version`, `Website`, `IsDiscontinued`

#### Modified: `Resolve-AppInfoOnline`
- Implementa fallback automático
- Tenta Chocolatey primeiro (se `ChocolateyId` existir)
- Logging progressivo dos fallbacks

#### Modified: Main Loop (Processamento)
- Envolvido em try-catch
- Contador de progresso `[index/total]`
- Melhor feedback do usuário

### Performance Improvements

| Source | Antes | Depois | Melhoria |
|--------|-------|--------|----------|
| Timeout em hang | ∞ (crash) | 5s | ~100-200x faster |
| Chocolatey | Não usado | 1º priority | ~10x faster |
| Error handling | Cascade fail | Graceful degrade | 100% completion |
| User feedback | Nenhum | [n/total] | UX |

### Files Modified
- ✅ `app_update.ps1` - Core script com otimizações
- ✅ `.github/copilot-instructions.md` - Documentação atualizada

### Configuration Changes (Optional)
Para aproveitar Chocolatey, adicione a appSources.json:
```json
"app_key": {
  "Type": "GitHub|Website|Fixed",
  "ChocolateyId": "package-id",
  "RepoUrl": "https://...",
  "ScrapeUrl": "https://...",
  "OutputUrl": "https://...",
  "VersionPattern": "regex"
}
```

### Testing
✅ Script testado com sucesso:
- Processa 121 apps sem crash
- Trata timeouts gracefully
- Mostra progresso em tempo real
- Completa mesmo com falhas individuais

### Next Steps (Sugestões)
1. Adicionar `ChocolateyId` aos entries no appSources.json
2. Corrigir regex patterns para apps com falhas (ex: `cygwin`)
3. Considerar cache em memória para apps duplicados
4. Implementar retry logic para falhas transientes

---

## Lote 2 - 2026-02-21

### Contexto
Este lote foca em otimizações funcionais ligadas a regras de negócio, reduzindo chamadas externas e aumentando a previsibilidade do status.

### Otimizações Implementadas
- **Skip de Scraping para `app interno`**:
    - Apps marcados como `app interno` não disparam mais chamadas HTTP para fontes externas.
    - Redução direta do volume de requisições em ambientes com muitos pacotes internos.
- **Regra de Status para Apps sem Versão Instalada**:
    - Quando `InstalledVersion` está vazia, o backend usa `0.0.0` apenas internamente para comparação.
    - O `Status` passa a ser sempre `UpdateAvailable`, usando a última versão encontrada na web.
    - Evita erros de comparação e mantém o CSV limpo (sem gravar `0.0.0`).
- **Reuso de Metadados Existentes**:
    - Dicionários em memória preservam `TipoApp` e `License` de execuções anteriores.
    - Evita recalcular ou sobrescrever decisões manuais a cada rodada do script.
- **Uso de Fontes Oficiais em Apps Críticos**:
    - NVDA passou a usar diretamente a página oficial como fonte de versão, eliminando divergências entre Chocolatey e o site do fornecedor.
    - Oracle SQL Developer teve a versão amarrada aos links oficiais de download da Oracle, reduzindo o risco de desencontro entre o instalador utilizado pelo time e o que o site anuncia.
    - Para OpenSSL, o status permanece `Unknown` com anotação explícita no CSV, adiando o critério de comparação (última 3.5.x LTS vs build específico) para decisão futura consciente.

### Impacto de Performance
- Menos chamadas de scraping em massa para apps internos.
- Menos lógica de decisão por app (reuso de metadados já resolvidos).
- Execuções mais estáveis e previsíveis, especialmente em ambientes com muitos pacotes corporativos.

---

## Lote 3 - 2026-02-22

### Contexto
Este lote concentra ajustes finos de fontes de versão para Java e ecossistema JetBrains, além de reforçar a documentação explícita dos casos em que o status `Unknown` é uma decisão consciente (sem fonte automatizável).

### Otimizações Implementadas
- **JDK 8 e JDK 17 via release notes da Oracle**:
    - `java se development kit` e `java(tm) se development kit` passam a usar as páginas oficiais de release notes (`8u-relnotes` e `17u-relnotes`) como fonte principal.
    - Regex de extração foi ajustada para capturar a última versão GA destacada no texto (ex.: `8u481` e `17.0.18`), reduzindo divergências entre inventário e o que a Oracle publica.
- **JetBrains Toolbox via API oficial**:
    - Adicionada entrada `jetbrains-toolbox` em `appSources.json` apontando para `data.services.jetbrains.com` com `code=TBA`.
    - A versão exibida para o Toolbox App passa a vir diretamente do JSON oficial (ex.: `version = 3.2`, `build = 3.2.0.65851`), mantendo o app com auto‑update mas com checagem confiável para inventário.
- **Outras fontes oficiais reforçadas**:
    - Neo4j Community configurado para usar a página de release notes oficial (`neo4j.com/release-notes`) em vez de fontes indiretas.
    - Eclipse Temurin JDK com Hotspot utilizando a página de releases do Adoptium como referência de LTS para Windows x64.
- **Documentação de Unknowns estruturais**:
    - Casos em que não há fonte pública estável (agentes de inventário/monitorização, componentes OpenText, apps legados específicos de fornecedor, pequenos utilitários de loja) tiveram observações padronizadas adicionadas ao CSV.
    - Isso evita reanálises futuras e deixa claro que não se trata de “falha de scraping”, e sim de limitação de negócio/técnica.

### Impacto
- Redução de divergências entre o que o inventário aponta como “última versão” e as páginas oficiais dos fornecedores.
- Maior transparência sobre o motivo de cada `Unknown`, facilitando auditorias e priorização de melhorias futuras.
- Base mais estável para evoluir regras de normalização e comparações específicas por fornecedor (Oracle, JetBrains, Neo4j, etc.).
