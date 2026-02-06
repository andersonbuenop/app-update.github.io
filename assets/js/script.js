function initFromText(text) {
  const { data } = parseCsv(text);
  state.data = data;
  state.filtered = [...state.data];
  renderTable();
  updateChart(); // Atualiza gráfico ao carregar dados
}

// Inicializa gráfico logo após carregar DOM
document.addEventListener('DOMContentLoaded', initChart);

// Carrega appSources.json (configurações extras)
fetch('data/appSources.json')
  .then(r => r.ok ? r.json() : {})
  .then(json => {
    state.appSources = json;
    console.log('appSources carregado', Object.keys(json).length);
  })
  .catch(err => console.warn('Erro ao carregar appSources.json', err));

// tenta carregar apps.csv do mesmo diretório
fetch('data/apps.csv')
  .then(r => r.ok ? r.text() : Promise.reject())
  .then(text => initFromText(text))
  .catch(() => {
    // fallback para o CSV embutido
    initFromText(defaultCsv);
  });

// CSV embutido como fallback (caso não carregues um ficheiro)
const defaultCsv = `"AppName","appversion","LatestVersion","Website","InstalledVersion","Status"
"7zip 25",,"25.01","https://www.7-zip.org/","25","UpdateAvailable"
"notepad++","8.9","8.9.1","https://notepad-plus-plus.org/downloads/","8.9","UpdateAvailable"
"google chrome","138.3.3.3","144.0.7559.109","https://chromeenterprise.google/intl/pt_br/download/?modal-id=download-chrome","138.3.3.3","UpdateAvailable"
"adobe acrobat reader update","-2345","25.1.21111","https://www.adobe.com/devnet-docs/acrobatetk/tools/ReleaseNotesDC/index.html","2345","UpdateAvailable"
"adobe acrobat 11 pro",,,,"Unknown"
"apache directory studio",,,,"https://directory.apache.org/studio/download/",,"Unknown"
"apache cxf",,,,"https://cxf.apache.org/download.html",,"Unknown"
"apache jmeter",,"5.6","https://jmeter.apache.org/download_jmeter.cgi","5.6","UpToDate"
"apache maven",,"3.9.12","https://maven.apache.org/download.cgi","3.9.12","UpToDate"
"ide netbeans",,,,"https://netbeans.apache.org/download/index.html",,"Unknown"`;

// Parser CSV simples, suficiente para este caso
function parseCsv(text) {
  const lines = text.replace(/\r\n/g, '\n').split('\n').filter(l => l.trim() !== '');
  const rows = lines.map(line => {
    const result = [];
    let current = '';
    let inQuotes = false;

    for (let i = 0; i < line.length; i++) {
      const c = line[i];
      if (c === '"') {
        if (inQuotes && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c === ',' && !inQuotes) {
        result.push(current);
        current = '';
      } else {
        current += c;
      }
    }
    result.push(current);
    return result;
  });

  const headers = rows[0].map(h => h.replace(/^"|"$/g, ''));
  const data = rows.slice(1).map((row, rowIndex) => {
    const obj = { _originalIndex: rowIndex + 1 };
    headers.forEach((h, idx) => {
      obj[h] = (row[idx] || '').replace(/^"|"$/g, '');
    });
    // Calcula versão mesclada para sorting
    const installedVer = parseFloat((obj.InstalledVersion || '0').replace(/[^0-9.]/g, '')) || 0;
    const appVer = parseFloat((obj.appversion || '0').replace(/[^0-9.]/g, '')) || 0;
    const maxVersion = Math.max(installedVer, appVer);
    obj.MergedVersion = maxVersion > 0 ? (obj.InstalledVersion || obj.appversion || '') : '';
    return obj;
  });
  return { headers, data };
}

const state = {
  data: [],
  filtered: [],
  appSources: {},
  sort: { key: null, dir: 1 },
  statusFilter: null,
  statusDir: 1,
  chart: null // Instância do Chart.js
};

const tableBody = document.querySelector('#appsTable tbody');
const searchInput = document.getElementById('searchInput');

// Botão de Atualizar Agora
document.getElementById('updateBtn').addEventListener('click', () => {
  const btn = document.getElementById('updateBtn');
  // const feedback = document.getElementById('updateFeedback'); // Removido conforme solicitado
  const originalText = 'Atualizar Agora';
  
  btn.disabled = true;
  btn.innerText = 'Atualizando...';
  
  // Sem feedback externo
  
  fetch('/run-update', { method: 'POST' })
    .then(r => r.json())
    .then(data => {
      if (data.status === 'success') {
        // Sucesso: Atualiza dados e restaura botão
        if (window.loadData) {
            window.loadData();
        } else {
            location.reload(); // Fallback
        }
      } else {
        console.error(data.output);
        alert('Erro na atualização.');
      }
    })
    .catch(err => {
      console.error(err);
      alert('Erro de conexão.');
    })
    .finally(() => {
      // Sempre restaura o estado do botão
      btn.disabled = false;
      btn.innerText = originalText;
    });
});

// Inicializa o gráfico
function initChart() {
  // Registra o plugin de datalabels se estiver disponível
  if (typeof ChartDataLabels !== 'undefined') {
    Chart.register(ChartDataLabels);
  }

  const ctx = document.getElementById('statusChart').getContext('2d');
  state.chart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: ['UpdateAvailable', 'UpToDate', 'Unknown'],
      datasets: [{
        data: [0, 0, 0],
        backgroundColor: [
          '#f55353', // UpdateAvailable (Vermelho)
          '#10b981', // UpToDate (Verde)
          '#ffc107'  // Unknown (Amarelo)
        ],
        borderWidth: 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      layout: {
        padding: {
          top: 40
        }
      },
      plugins: {
        legend: {
          position: 'right',
          labels: {
            color: '#c2c2c2',
            font: { size: 11 },
            boxWidth: 12,
            padding: 15
          }
        },
        title: {
          display: false // Desativa título nativo para usar o customizado
        },
        datalabels: {
          color: '#ffffff',
          font: {
            weight: 'bold',
            size: 14
          },
          formatter: (value, ctx) => {
            if (value === 0) return ''; // Não mostra zero
            return value;
          }
        }
      }
    },
    plugins: [{
      id: 'customTitle',
      afterDraw: (chart) => {
        const { ctx, chartArea } = chart;
        if (!chartArea) return;
        
        const { left, right } = chartArea;
        const x = (left + right) / 2;
        const y = 20; // Posição vertical no topo (dentro do padding)
        
        ctx.save();
        ctx.fillStyle = '#f0f0f0'; // Mesma cor do título original
        ctx.font = 'bold 14px "Segoe UI", sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('Status dos Apps', x, y);
        ctx.restore();
      }
    }]
  });
}

// Atualiza os dados do gráfico
function updateChart() {
  if (!state.chart) return;

  const counts = {
    UpdateAvailable: 0,
    UpToDate: 0,
    Unknown: 0
  };

  // Conta status dos dados FILTRADOS
  state.filtered.forEach(row => {
    const s = row.Status || 'Unknown';
    if (counts[s] !== undefined) {
      counts[s]++;
    } else {
      counts.Unknown++;
    }
  });

  state.chart.data.datasets[0].data = [
    counts.UpdateAvailable,
    counts.UpToDate,
    counts.Unknown
  ];
  state.chart.update();
}

function statusClass(status) {
  if (!status) return 'status-Unknown';
  return 'status-' + status.replace(/\s+/g, '');
}

function toTitleCase(str) {
  return str.replace(/\b\w/g, char => char.toUpperCase());
}

function renderTable() {
  tableBody.innerHTML = '';
  state.filtered.forEach((row, index) => {
    const tr = document.createElement('tr');

    // Pega a maior versão entre InstalledVersion e appversion
    const installedVer = parseFloat((row.InstalledVersion || '0').replace(/[^0-9.]/g, '')) || 0;
    const appVer = parseFloat((row.appversion || '0').replace(/[^0-9.]/g, '')) || 0;
    const maxVersion = Math.max(installedVer, appVer);
    const mergedVersion = maxVersion > 0 ? (row.InstalledVersion || row.appversion || '') : '';

    // Status como botão com link para website
    let statusButton = `<span class="status-pill ${statusClass(row.Status)}">${row.Status || 'Unknown'}</span>`;
    if (row.Website) {
      statusButton = `<a href="${row.Website}" target="_blank" rel="noopener noreferrer" class="status-button ${statusClass(row.Status)}">${row.Status || 'Unknown'}</a>`;
    }
    
    // Badge de NOVA Versão
    let latestVersionHtml = row.LatestVersion || '';
    if (row.IsNewVersion && row.IsNewVersion.toLowerCase() === 'true') {
        latestVersionHtml += ' <span class="badge-new">NEW</span>';
    }

    tr.innerHTML = `
      <td class="col-num text-center text-white">${index + 1}</td>
      <td class="col-icon text-center">
        <img src="${row.IconUrl || 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNjMmMyYzIiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cmVjdCB4PSIyIiB5PSIyIiB3aWR0aD0iMjAiIGhlaWdodD0iMjAiIHJ4PSI1IiByeT0iNSIvPjxwYXRoIGQ9Ik0xNiAxMS4zN0ExLjQgMS40IDAgMTE1IDEzYTEuNCAxLjQgMCAwMSAxLTEuNjN6bTAtMy43N2ExLjQgMS40IDAgMTEuMzMgMS4zM0ExLjQgMS40IDAgMDExNiA3LjZ6TTcuNDEgMTAuODhBMS41IDEuNSAwIDExNiAxMi41YTEuNSAxLjUgMCAwMSAxLjQxLTEuNjJ6bS0uMjUgMy43NkExLjUgMS41IDAgMTE1Ljg0IDE2YTEuNSAxLjUgMCAwMSAxLjMzLTEuMzZ6IiBmaWxsPSJjdXJyZW50Q29sb3IiIG9wYWNpdHk9IjAuNSIvPjwvc3ZnPg=='}" 
             class="app-icon" 
             alt="icon" 
             onerror="this.src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IiNjMmMyYzIiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIj48cmVjdCB4PSIyIiB5PSIyIiB3aWR0aD0iMjAiIGhlaWdodD0iMjAiIHJ4PSI1IiByeT0iNSIvPjxwYXRoIGQ9Ik0xMiA4djhNMCAxMmgyNCIgc3Ryb2tlPSIjZmZmIiBvcGFjaXR5PSIwLjIiLz48L3N2Zz4='">
      </td>
      <td class="col-app">${toTitleCase(row.AppName || '')}</td>
      <td class="col-version">${row.appversion || ''}</td>
      <td class="col-version">${row.InstalledVersion || ''}</td>
      <td class="col-version">${latestVersionHtml}</td>
      <td class="col-status">${statusButton}</td>
      <td class="col-license">${toTitleCase(row.License || '')}</td>
      <td class="col-obs">${row.Observacao || ''}</td>
      <td class="col-actions">
        <button onclick="openEditModal(${index})" class="btn btn-primary btn-sm">Editar</button>
      </td>
    `;
    tableBody.appendChild(tr);
  });
}

function openEditModal(index) {
  // Encontra o item original nos dados filtrados
  const item = state.filtered[index];
  if (!item) return;

  // Preenche o formulário
  document.getElementById('editIndex').value = item._originalIndex; // Index global
  document.getElementById('editAppName').value = item.AppName || '';
  document.getElementById('editAppVersion').value = item.appversion || '';
  document.getElementById('editInstalledVersion').value = item.InstalledVersion || '';
  document.getElementById('editLatestVersion').value = item.LatestVersion || '';
  // Status removido da edição, calculado automaticamente ou mantido
  let licVal = item.License || 'Free';
  // Normaliza para Title Case para bater com o <select> (ex: "free" -> "Free")
  if (licVal) {
      licVal = licVal.charAt(0).toUpperCase() + licVal.slice(1).toLowerCase();
  }
  document.getElementById('editLicense').value = licVal;
  
  document.getElementById('editObservacao').value = item.Observacao || '';
  
  // Campos de URL
  document.getElementById('editSourceKey').value = item.SourceKey || '';
  document.getElementById('editSearchUrl').value = item.SearchUrl || '';
  document.getElementById('editOutputUrl').value = item.Website || ''; // Website é o OutputUrl no CSV

  // Habilita edição de URLs para todos (mesmo sem chave JSON, salva no CSV)
  document.getElementById('editSearchUrl').placeholder = "URL de Busca";
  document.getElementById('editOutputUrl').placeholder = "URL de Saída";
  
  // Mostra modal
  const modal = document.getElementById('editModal');
  modal.style.display = 'flex';
}

function closeModal() {
  document.getElementById('editModal').style.display = 'none';
}

function calculateStatus(installed, latest) {
    if (!installed || !latest) return 'Unknown';
    
    // Remove caracteres não numéricos (mantém pontos) para comparação simples
    const cleanInst = installed.replace(/[^0-9.]/g, '');
    const cleanLatest = latest.replace(/[^0-9.]/g, '');
    
    if (!cleanInst || !cleanLatest) return 'Unknown';

    // Comparação simples de versões (ex: 1.2.3 vs 1.2.4)
    const v1Parts = cleanInst.split('.').map(Number);
    const v2Parts = cleanLatest.split('.').map(Number);
    
    for (let i = 0; i < Math.max(v1Parts.length, v2Parts.length); i++) {
        const v1 = v1Parts[i] || 0;
        const v2 = v2Parts[i] || 0;
        
        if (v1 > v2) return 'UpToDate'; // Instalada maior que a última (dev/beta?)
        if (v1 < v2) return 'UpdateAvailable';
    }
    
    return 'UpToDate';
}

// Manipulador do formulário de edição
document.getElementById('editForm').addEventListener('submit', function(e) {
  e.preventDefault();
  
  const originalIndex = parseInt(document.getElementById('editIndex').value);
  const row = state.data.find(r => r._originalIndex === originalIndex);
  
  if (row) {
    row.AppName = document.getElementById('editAppName').value;
    row.appversion = document.getElementById('editAppVersion').value;
    row.InstalledVersion = document.getElementById('editInstalledVersion').value;
    row.LatestVersion = document.getElementById('editLatestVersion').value;
    // Status não editável diretamente
    row.License = document.getElementById('editLicense').value;
    row.Observacao = document.getElementById('editObservacao').value;
    
    // Atualiza URLs no objeto row (CSV)
    const newSearchUrl = document.getElementById('editSearchUrl').value;
    const newOutputUrl = document.getElementById('editOutputUrl').value;
    
    row.SearchUrl = newSearchUrl;
    row.Website = newOutputUrl;

    // Atualiza JSON se tiver chave
    const sourceKey = document.getElementById('editSourceKey').value;
    if (sourceKey && state.appSources[sourceKey]) {
        const src = state.appSources[sourceKey];
        src.OutputUrl = newOutputUrl;
        
        // Atualiza ScrapeUrl ou RepoUrl dependendo do que existir ou do Type
        if (src.RepoUrl) {
            src.RepoUrl = newSearchUrl;
        } else {
            src.ScrapeUrl = newSearchUrl;
        }
        
        // Atualiza Licença (sempre Title Case)
        src.License = document.getElementById('editLicense').value;
    }
    
    // Recalcula campos derivados se necessário
    const installedVer = parseFloat((row.InstalledVersion || '0').replace(/[^0-9.]/g, '')) || 0;
    const appVer = parseFloat((row.appversion || '0').replace(/[^0-9.]/g, '')) || 0;
    const maxVersion = Math.max(installedVer, appVer);
    row.MergedVersion = maxVersion > 0 ? (row.InstalledVersion || row.appversion || '') : '';
    
    // Atualiza Status dinamicamente
    row.Status = calculateStatus(row.InstalledVersion, row.LatestVersion);

    // Atualiza tabela
    renderTable();
    updateChart(); // Atualiza gráfico imediatamente
    
    // Salva no servidor com feedback visual
    const saveBtn = document.getElementById('saveEditBtn');
    const originalText = saveBtn ? saveBtn.textContent : 'Salvar';
    if (saveBtn) {
        saveBtn.textContent = 'Salvando...';
        saveBtn.disabled = true;
    }

    saveDataToServer()
        .then(() => {
            closeModal();
        })
        .finally(() => {
            if (saveBtn) {
                saveBtn.textContent = originalText;
                saveBtn.disabled = false;
            }
        });
  }
});

function saveDataToServer() {
  // 1. Salvar CSV
  const headers = ['AppName', 'appversion', 'LatestVersion', 'Website', 'InstalledVersion', 'Status', 'License', 'SourceKey', 'SearchUrl', 'Observacao', 'IsNewVersion', 'SourceId', 'IconUrl'];
  
  let csvContent = headers.map(h => `"${h}"`).join(',') + '\n';
  
  state.data.forEach(row => {
    const line = headers.map(h => {
        const val = row[h] || '';
        return `"${String(val).replace(/"/g, '""')}"`;
    }).join(',');
    csvContent += line + '\n';
  });
  
  // Promise para salvar CSV
  const saveCsv = fetch('/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        filename: 'apps_output.csv',
        content: csvContent
    })
  }).then(async r => {
      const res = await r.json();
      if (!r.ok) throw new Error(res.error || 'Erro ao salvar CSV');
      return res;
  });

  // 2. Salvar JSON (se houver dados carregados)
  let saveJson = Promise.resolve();
  if (Object.keys(state.appSources).length > 0) {
      saveJson = fetch('/save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            filename: 'appSources.json',
            content: JSON.stringify(state.appSources, null, 2)
        })
      }).then(async r => {
          const res = await r.json();
          if (!r.ok) throw new Error(res.error || 'Erro ao salvar JSON');
          return res;
      });
  }

  return Promise.all([saveCsv, saveJson])
  .then(results => {
      console.log('Salvo com sucesso:', results);
      state.lastCsvText = csvContent;
      return results;
  })
  .catch(err => {
      console.error('Erro ao salvar:', err);
      alert('Erro ao salvar alterações no servidor.');
      throw err;
  });
}

function applyFilters() {
  const term = searchInput.value.trim().toLowerCase();
  const status = state.statusFilter;

  state.filtered = state.data.filter(row => {
    const matchesStatus = !status || (row.Status || '') === status;
    const text = (
      (row.AppName || '') + ' ' +
      (row.appversion || '') + ' ' +
      (row.LatestVersion || '') + ' ' +
      (row.Website || '') + ' ' +
      (row.InstalledVersion || '') + ' ' +
      (row.Status || '') + ' ' +
      (row.License || '')
    ).toLowerCase();
    const matchesTerm = !term || text.includes(term);
    return matchesStatus && matchesTerm;
  });

  if (state.sort.key) {
    sortBy(state.sort.key, false);
  } else {
    renderTable();
  }
  
  // Atualiza o gráfico para refletir o filtro aplicado
  updateChart();
}

// Evento do botão cancelar
const cancelBtn = document.getElementById('cancelEdit');
if (cancelBtn) {
    cancelBtn.addEventListener('click', closeModal);
}

// Fechar modal ao clicar fora
const modal = document.getElementById('editModal');
if (modal) {
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            closeModal();
        }
    });
}

function sortBy(key, toggleDir = true) {
  if (toggleDir) {
    if (state.sort.key === key) {
      state.sort.dir *= -1;
    } else {
      state.sort.key = key;
      state.sort.dir = 1;
    }
  }

  const dir = state.sort.dir;
  state.filtered.sort((a, b) => {
    const va = (a[key] || '').toString().toLowerCase();
    const vb = (b[key] || '').toString().toLowerCase();

    // tenta comparar como número se fizer sentido
    const na = parseFloat(va.replace(/[^0-9.]/g, ''));
    const nb = parseFloat(vb.replace(/[^0-9.]/g, ''));
    const bothNumeric = !isNaN(na) && !isNaN(nb);

    if (bothNumeric) {
      return (na - nb) * dir;
    }
    if (va < vb) return -1 * dir;
    if (va > vb) return 1 * dir;
    return 0;
  });

  renderTable();
}

// Eventos
document.getElementById('fileInput').addEventListener('change', e => {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = ev => {
    const { data } = parseCsv(ev.target.result);
    state.data = data;
    state.filtered = [...state.data];
    state.sort = { key: null, dir: 1 };
    state.statusFilter = null;
    state.statusDir = 1;
    updateBadgeStyles();
    renderTable();
  };
  reader.readAsText(file, 'utf-8');
});

searchInput.addEventListener('input', applyFilters);

// Botão de salvar manual (removido)
// const saveBtn = document.getElementById('saveBtn');
// if (saveBtn) { ... }

// Badge filter events
document.querySelectorAll('#statusBadges .badge').forEach(badge => {
  badge.addEventListener('click', () => {
    const status = badge.dataset.status;
    
    // Ciclo: neutro -> crescente -> decrescente -> neutro
    if (state.statusFilter === status) {
      if (state.statusDir === 1) {
        state.statusDir = -1;
      } else {
        state.statusFilter = null;
        state.statusDir = 1;
      }
    } else {
      state.statusFilter = status;
      state.statusDir = 1;
    }
    
    updateBadgeStyles();
    applyFilters();
  });
});

function updateBadgeStyles() {
  document.querySelectorAll('#statusBadges .badge').forEach(badge => {
    badge.style.opacity = '0.6';
    badge.innerHTML = badge.innerHTML.replace(' ↓', '').replace(' ↑', '');
    
    if (state.statusFilter === badge.dataset.status) {
      badge.style.opacity = '1';
      const arrow = state.statusDir === 1 ? ' ↓' : ' ↑';
      badge.innerHTML += arrow;
    }
  });
}

document.querySelectorAll('#appsTable thead th').forEach(th => {
  th.addEventListener('click', () => {
    const key = th.dataset.key;
    if (!key) return;
    sortBy(key, true);
  });
});

// Inicializa tentando carregar apps_output.csv, com fallback para defaultCsv
  window.loadData = () => {
    // Carrega Metadados (Timestamp)
    fetch('data/metadata.json?t=' + Date.now())
        .then(r => r.ok ? r.json() : {})
        .then(meta => {
            if (meta.lastRun) {
                document.getElementById('lastUpdate').textContent = 'Última Verificação: ' + meta.lastRun;
            }
        })
        .catch(() => console.log('Sem metadados'));

    fetch('data/apps_output.csv?t=' + Date.now()) // timestamp para evitar cache
      .then(r => r.ok ? r.text() : Promise.reject())
      .then(text => {
        // Verifica se houve mudança para evitar re-renderizar sem necessidade (opcional, mas bom para UX)
        if (state.lastCsvText !== text) {
            state.lastCsvText = text;
            initFromText(text);
        }
      })
      .catch(() => {
        // Se falhar e ainda não tiver dados carregados, usa o fallback
        if (!state.data || state.data.length === 0) {
            initFromText(defaultCsv);
        }
      });
  };

  (function init() {
  // Carrega appSources.json
  fetch('appSources.json')
      .then(r => r.ok ? r.json() : {})
      .then(json => {
          state.appSources = json;
          console.log('appSources carregado:', Object.keys(json).length);
      })
      .catch(err => console.error('Erro ao carregar appSources.json:', err));

  // Carrega a primeira vez
  window.loadData();

  // Polling a cada 5 segundos
  setInterval(window.loadData, 5000);
})();