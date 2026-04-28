# Como Testar a Funcionalidade de Atualização Individual

## 🎯 O que foi implementado

Adicionei um botão **"Atualizar App"** na coluna de ações da sua tabela existente, permitindo atualizar cada aplicativo individualmente.

## 📁 Arquivos Modificados

### 1. JavaScript (assets/js/script.js)
- ✅ Botão "Atualizar App" adicionado na coluna de ações
- ✅ Função `updateSingleApp()` para processar atualizações individuais
- ✅ Loading states e feedback visual

### 2. CSS (assets/css/style.css)
- ✅ Estilo `.btn-loading` com animação de spinner
- ✅ Estados visuais para botão em processamento

### 3. Backend (server.py)
- ✅ Endpoint `/update-single-app` para atualizações individuais
- ✅ Integração com script `process_single_app.ps1`
- ✅ Tratamento de erros e respostas JSON

## 🚀 Como Usar

### 1. Inicie o servidor Python (como você já faz)
```bash
python server.py
```

### 2. Abra a interface web
Acesse: http://localhost:8000

### 3. Teste a funcionalidade
1. Na tabela, localize qualquer app (ex: 7-Zip)
2. Clique no botão **"Atualizar App"** ao lado do botão "Editar"
3. Aguarde o processo (botão ficará com loading)
4. Veja o resultado no alerta e na tabela atualizada

## 🎨 Características da Implementação

### Botão Individual
- **Nome**: "Atualizar App"
- **Estilo**: Botão secundário pequeno (btn-secondary btn-sm)
- **ID**: `updateBtn-{index}` para controle individual
- **Loading**: Animação spinner com texto "Atualizando..."

### Feedback Visual
- **Loading**: Botão desabilitado com spinner animado
- **Sucesso**: Alerta verde e atualização da tabela
- **Erro**: Alerta vermelho com mensagem detalhada

### Backend Integration
- **Endpoint**: `POST /update-single-app`
- **Script**: `process_single_app.ps1` com parâmetros
- **Resposta**: JSON com sucesso/erro e dados atualizados

## 🧪 Teste Rápido

Para verificar se está funcionando:

1. **Verifique o botão**: Deve aparecer "Atualizar App" ao lado de "Editar"
2. **Clique no botão**: Deve mostrar "Atualizando..." com loading
3. **Agude o processo**: O PowerShell executará em background
4. **Confirme o resultado**: Alerta e tabela devem atualizar

## 🐛 Troubleshooting

### Se o botão não aparecer:
- Verifique o console do navegador (F12) por erros JavaScript
- Confirme se os arquivos foram salvos corretamente

### Se a atualização falhar:
- Verifique o console do servidor Python
- Confirme se `process_single_app.ps1` existe
- Teste manualmente: `powershell -ExecutionPolicy Bypass -File .\process_single_app.ps1 -SingleAppName "7-Zip 25.01 (x64 edition)"`

### Se não atualizar a tabela:
- Verifique se a resposta JSON contém os campos esperados
- Confirme se a função `renderTable()` está sendo chamada

## 🎉 Benefícios

- ⚡ **Testes Rápidos**: Atualize um app específico em segundos
- 🎯 **Debug Isolado**: Identifique problemas em apps específicos
- 📱 **Interface Amigável**: Operadores podem usar facilmente
- 🔧 **Não Invasivo**: Funciona junto com seu sistema atual

---

**Pronto para uso!** Execute `python server.py` e teste o novo botão "Atualizar App".
