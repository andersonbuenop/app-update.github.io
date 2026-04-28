# Gerenciador de Atualizações Individual de Apps

## 🎯 Objetivo
Sistema para atualizar aplicativos individualmente, ideal para testes rápidos e atualizações específicas sem precisar rodar o script completo para todos os apps.

## 📁 Arquivos Criados

### Scripts Principais
- **`process_single_app.ps1`** - Processamento individual de apps com todas as funcionalidades
- **`web_server.ps1`** - Servidor web com interface completa
- **`start_web_manager.ps1`** - Script de inicialização do servidor
- **`test_individual_update.ps1`** - Teste rápido da funcionalidade

### Scripts Modificados
- **`apps_update.ps1`** - Adicionado suporte para Java 8u, 17, 21 sem duplicação

## 🚀 Como Usar

### 1. Via Interface Web (Recomendado)

```powershell
powershell -ExecutionPolicy Bypass -File '.\start_web_manager.ps1'
```

Acesse: http://localhost:8080

**Funcionalidades:**
- 📋 Lista completa de apps do CSV
- 🔄 Botão "Atualizar" para cada app individual
- 📝 Botão "Editar" (em desenvolvimento)
- 📊 Modal com resultado da atualização
- ⏱️ Loading states e feedback visual

### 2. Via Linha de Comando

```powershell
# Processamento básico
powershell -ExecutionPolicy Bypass -File '.\process_single_app.ps1' -SingleAppName "7-Zip 25.01 (x64 edition)"

# Processamento completo com scraping
powershell -ExecutionPolicy Bypass -File '.\process_single_app.ps1' -SingleAppName "7-Zip 25.01 (x64 edition)" -FullProcessing

# Modo silencioso (para API)
powershell -ExecutionPolicy Bypass -File '.\process_single_app.ps1' -SingleAppName "7-Zip 25.01 (x64 edition)" -Quiet
```

## 🎨 Interface Web

### Características
- **Design Responsivo**: Funciona em desktop e mobile
- **Moderno**: Tailwind CSS + Font Awesome
- **Intuitivo**: Cores e ícones para feedback visual
- **Rápido**: AJAX para atualizações sem reload

### Fluxo de Uso
1. 📱 Acesse http://localhost:8080
2. 📋 Visualize lista de apps com versões instaladas
3. 🔄 Clique em "Atualizar" no app desejado
4. ⏳ Aguarde o processamento (loading state)
5. 📊 Veja resultado no modal
6. ✅ Status: UpToDate, UpdateAvailable ou Error

## 🔧 Parâmetros do Script Individual

### `process_single_app.ps1`
- **`-SingleAppName`** (obrigatório) - Nome exato do app no CSV
- **`-FullProcessing`** - Faz scraping completo vs. info básica
- **`-Quiet`** - Modo silencioso para API

### Retorno JSON (API)
```json
{
  "success": true,
  "app": {
    "AppName": "7-Zip 25.01 (x64 edition)",
    "NormalizedName": "7-zip",
    "InstalledVersion": "25.01",
    "LatestVersion": "26.00",
    "Status": "UpdateAvailable",
    "Website": "http://www.7-zip.org/",
    "ProcessingTime": "2026-03-18 11:43:24"
  }
}
```

## 🐛 Correções Implementadas

### Java Duplication Fix ✅
- **Problema**: Java SE 8u, 17, 21 eram tratados como duplicados
- **Solução**: Normalização específica que preserva números das versões
- **Resultado**: Cada versão Java agora é processada individualmente

### Exemplos de Nomes Normalizados
- `Java SE Development Kit 8u341` → `java se development kit 8`
- `Java SE Development Kit 17.0.8` → `java se development kit 17`
- `JDK 8u341` → `jdk 8u` (redirect para Java SE 8)
- `Java 17` → `java 17` (redirect para Java SE 17)

## 📊 Estrutura do Projeto

```
app-update.github.io/
├── apps_update.ps1              # Script principal (modificado)
├── process_single_app.ps1        # Processamento individual
├── web_server.ps1              # Servidor web
├── start_web_manager.ps1        # Inicialização
├── test_individual_update.ps1    # Teste rápido
├── data/
│   ├── apps.csv               # Lista de apps
│   └── appSources.json        # Configurações (atualizado)
└── README_individual.md        # Este arquivo
```

## 🎯 Benefícios

### Para Testes
- ⚡ Rapidez: Teste um app em segundos vs. minutos para todos
- 🎯 Precisão: Valide configurações de app específico
- 🐛 Debug: Isolamento facilita identificação de problemas

### Para Produção
- 📈 Eficiência: Atualize apenas apps necessários
- 🕐 Flexibilidade: Execute em horários específicos
- 📱 Controle: Interface amigável para operadores

## 🔮 Próximos Passos

### Funcionalidades Futuras
- [ ] Botão "Editar" para configurações de app
- [ ] Atualização em lote (seleção múltipla)
- [ ] Histórico de atualizações
- [ ] Agendamento de atualizações
- [ ] Exportação de relatórios
- [ ] Integração com notificações

### Melhorias Técnicas
- [ ] Cache de resultados para performance
- [ ] Sistema de retry para falhas de rede
- [ ] Validação de configurações
- [ ] Logs detalhados por app

## 🚨 Troubleshooting

### Problemas Comuns

**Porta 8080 em uso:**
```powershell
# Use outra porta
powershell -ExecutionPolicy Bypass -File '.\start_web_manager.ps1' -Port 8081
```

**App não encontrado:**
- Verifique nome exato no CSV
- Use aspas para nomes com espaços
- Exemplo: `"7-Zip 25.01 (x64 edition)"`

**Erro de permissão:**
```powershell
# Execute como administrador
Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File '.\start_web_manager.ps1'"
```

## 📞 Suporte

Se encontrar problemas:
1. Verifique os logs no console do servidor
2. Teste via linha de comando primeiro
3. Confirme arquivos necessários existem
4. Execute o script de teste: `test_individual_update.ps1`

---

**🎉 Sistema pronto para uso!** 
**Desenvolvido para melhorar eficiência no gerenciamento de atualizações de aplicações.**
