function initFromText(text) {
  const { data } = parseCsv(text);
  state.data = data;
  state.filtered = [...state.data];
  renderTable();
}

// Carrega appSources.json (configurações extras)
fetch('appSources.json')
  .then(r => r.ok ? r.json() : {})
  .then(json => {
    state.appSources = json;
    console.log('appSources carregado', Object.keys(json).length);
  })
  .catch(err => console.warn('Erro ao carregar appSources.json', err));

// tenta carregar apps.csv do mesmo diretório
fetch('apps.csv')
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
"adobe acrobat 11 pro",,,,,,"Unknown"
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
  statusDir: 1
};

const tableBody = document.querySelector('#appsTable tbody');
const searchInput = document.getElementById('searchInput');

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
      <td class="col-app">${toTitleCase(row.AppName || '')}</td>
      <td class="col-version">${mergedVersion}</td>
      <td class="col-version">${latestVersionHtml}</td>
      <td class="col-status">${statusButton}</td>
      <td class="col-license">${toTitleCase(row.License || '')}</td>
      <td class="col-obs">${row.Observacao || ''}</td>
      <td class="col-actions text-center">
        <button onclick="openEditModal(${index})" class="btn-edit">Editar</button>
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

  // Se não tiver chave no JSON, avisa ou desabilita? Por enquanto deixa editar mas só vai salvar no CSV se não tiver key
  const hasKey = !!item.SourceKey;
  document.getElementById('editSearchUrl').disabled = !hasKey;
  document.getElementById('editOutputUrl').disabled = !hasKey;
  if (!hasKey) {
      document.getElementById('editSearchUrl').placeholder = "Sem configuração no JSON";
      document.getElementById('editOutputUrl').placeholder = "Sem configuração no JSON";
  } else {
      document.getElementById('editSearchUrl').placeholder = "URL de Busca";
      document.getElementById('editOutputUrl').placeholder = "URL de Saída";
  }
  
  // Mostra modal
  const modal = document.getElementById('editModal');
  modal.style.display = 'flex';
}

function closeModal() {
  document.getElementById('editModal').style.display = 'none';
}

// Manipulador do formulário de edição
document.getElementById('editForm').addEventListener('submit', function(e) {
  e.preventDefault();
  
  const originalIndex = parseInt(document.getElementById('editIndex').value);
  const row = state.data.find(r => r._originalIndex === originalIndex);
  
  if (row) {
    //row.AppName = document.getElementById('editAppName').value; // Readonly
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
    
    // Atualiza tabela
    renderTable();
    closeModal();
    
    // Salva no servidor
    saveDataToServer();
  }
});

function saveDataToServer() {
  // 1. Salvar CSV
  const headers = ['AppName', 'appversion', 'LatestVersion', 'Website', 'InstalledVersion', 'Status', 'License', 'SourceKey', 'SearchUrl', 'Observacao'];
  
  let csvContent = headers.map(h => `"${h}"`).join(',') + '\n';
  
  state.data.forEach(row => {
    const line = headers.map(h => {
        const val = row[h] || '';
        return `"${val.replace(/"/g, '""')}"`;
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

  Promise.all([saveCsv, saveJson])
  .then(results => {
      console.log('Salvo com sucesso:', results);
      state.lastCsvText = csvContent;
      alert('Alterações salvas (CSV e JSON)!');
  })
  .catch(err => {
      console.error('Erro ao salvar:', err);
      alert('Erro ao salvar alterações no servidor.');
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
(function init() {
  // Carrega appSources.json
  fetch('appSources.json')
      .then(r => r.ok ? r.json() : {})
      .then(json => {
          state.appSources = json;
          console.log('appSources carregado:', Object.keys(json).length);
      })
      .catch(err => console.error('Erro ao carregar appSources.json:', err));

  const loadData = () => {
    fetch('apps_output.csv?t=' + Date.now()) // timestamp para evitar cache
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

  // Carrega a primeira vez
  loadData();

  // Polling a cada 5 segundos
  setInterval(loadData, 5000);
})();
