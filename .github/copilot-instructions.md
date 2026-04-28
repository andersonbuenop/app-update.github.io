# AI Instructions for app-update

## Project Overview
Multi-tier application tracking software versions across inventories (CSV from SCCM export). Combines backend version scraping (PowerShell + 3rd-party APIs), frontend dashboard (HTML/JS/CSS), and edit/persist workflow. **Portuguese UI throughout**.

---

## Architecture & Data Flow

### 1. **Backend: Version Discovery** ([apps_update.ps1](../../apps_update.ps1))
- **Input**: `data/apps.csv` (SCCM export: `System_Name3`, `Version2` columns)
- **Config**: `data/appSources.json` (per-app scraping rules + fallback strategies)
- **Process**: For each app, attempts version fetch in this order:
  1. **RuckZuck API** (local Windows app catalog)
  2. **appSources config** (custom regex scraping from websites/GitHub/Chocolatey)
  3. **Fallback**: GitHub API, Chocolatey API, direct website scraping
- **Output**: `data/apps_output.csv` with 15 columns including: `AppName`, `appversion`, `LatestVersion`, `Status`, `IsNewVersion`, `Observacao`, `License`, `TipoApp`, `IsDeleted`
- **Key insight**: Preserves user-edited `Observacao` + `License` across executions; detects new versions since last run

#### RuckZuck API Behavior
- **First run**: Downloads full catalog (~10MB), stores in memory. May take 10-30s depending on network.
- **Subsequent runs**: Makes lightweight sync request. Much faster.
- **No disk cache**: Catalog is in-memory only. Each script execution re-initializes.
- **Matching logic**: Searches by exact `ShortName`, then contains-match on `ProductName`, sorted by download count.
- **Icon URLs**: Generated dynamically via `https://ruckzuck.tools/rest/v2/geticon?shortname={ShortName}`
- **When to bypass**: If RuckZuck is slow or unreliable, add entry to `appSources.json` with `Type: "Website"` or `"GitHub"` to use direct scraping instead.

### 2. **Frontend: Dashboard** ([index.html](../../index.html) + [assets/js/script.js](../../assets/js/script.js) + [assets/css/style.css](../../assets/css/style.css))
- **Data load**: `fetch('data/apps_output.csv')` → parsed via `parseCsv()` into `state.data` array
- **Additional metadata**: `data/appSources.json` (loaded for version pattern rules if needed client-side)
- **State management**: Single `state` object tracks:
  - `data`: Full dataset (all rows)
  - `filtered`: Current filtered/sorted view (respects status, license, search filters + view: main/deleted)
  - `sort`: `{key, dir}` for column sorting (persists across filter changes)
  - `statusFilter` / `licenseFilter`: Dropdown selections
  - `view`: `'main'` or `'deleted'` (rows with `IsDeleted='true'` hidden in main view)
  - `chart`: Chart.js doughnut chart instance (only counts `state.filtered`)

### 3. **Backend: HTTP Server** ([server.py](../../server.py))
- Serves `index.html` and static assets
- **POST `/run-update`**: Executes `apps_update.ps1` via PowerShell, returns JSON response `{status, output}`
- **Auto-reload**: Watches `apps_output.csv` for changes, restarts server using `os.execv()` (useful during scraping)

### 4. **UI State Sync**
- **Edit modal** (inline form): Loads/saves individual app rows via form submission
- **Filtering**: Status + License dropdowns + text search → updates `state.filtered` and chart
- **Modal form** preserves hidden fields (`appversion`, `LatestVersion`, `SourceKey`, `IsDeleted`) so CSV round-trips correctly
- **Export to XLSX**: Current filtered view exported via `XLSX.utils` library (separate sheets for main/deleted views)

---

## Critical Data Patterns

### CSV Field Mapping
Input CSV (SCCM):
```
System_Name3 → AppName (normalized lowercase for appSources.json matching)
Version2 → appversion
```

Output CSV (15 columns, order matters for modal form):
```
AppName, appversion, LatestVersion, Website, InstalledVersion, Status, License, SourceKey, SearchUrl, Observacao, IsNewVersion, SourceId, IconUrl, TipoApp, IsDeleted
```

**Key constraint**: Modal form must include **hidden inputs** for `appversion`, `LatestVersion`, `SourceKey`, `IsDeleted` so they preserve when user edits only visible fields (`Observacao`, `License`, `TipoApp`).

### appSources.json Structure
```json
{
  "app-name-key": {
    "Type": "Website|GitHub|Fixed|RuckZuck",
    "ScrapeUrl": "https://...",
    "VersionPattern": "regex-with-capture-group",
    "OutputUrl": "download-link",
    "Version": "hardcoded-version (for Type:Fixed)",
    "License": "Free|Licensed"
  }
}
```

**Design rationale**: Decoupled from app display name so SCCM normalization changes don't break scraping. Keys are lowercase, spaces replaced with `-`.

### Status Logic
- **Determined by**: Comparing `LatestVersion` vs `appversion` via `Compare-AppVersion()` function (PowerShell script, not browser)
- **Values**: `UpdateAvailable`, `UpToDate`, `Unknown`
- **Color coding**: CSS classes `.status-UpdateAvailable` (red), `.status-UpToDate` (green), `.status-Unknown` (blue)
- **⚠️ Important**: Browser-side `calculateStatus()` is a simplified heuristic and may differ from PowerShell logic. Manual editing of version fields via modal can cause discrepancies until next `apps_update.ps1` run.

---

## Version Normalization Rules (Critical)

PowerShell applies complex normalization in `Normalize-Version()` before comparison. Understanding these is essential:

### Year-based versions
```powershell
# 4-digit years: 2025 → 25 (but only if formatted like 20XX)
# Partial year replacement: 2025.1.21111 → 25.1.21111 (removes "20" prefix only if 2nd segment < 10)
# Exception: 2026.23.3.1 → stays 2026.23.3.1 (2nd segment ≥ 10, not a minor version)
```

### 3-part semantic versions with trailing zeros
```powershell
# 25.01.00.0 → 25.01 (strips .0.0 suffix)
# 25.1.0 → 25.01 (pads minor with leading zero if patch == 0)
# Reconciles Chocolatey (25.1.0) vs official releases (25.01)
```

### 7-Zip special case (app-specific normalization)
```powershell
# 7-Zip: 25.1 → 25.01 (pads minor only for this app)
# Reason: Official site publishes "25.01", Chocolatey packages as "25.1.0"
```

### Why it matters
- **Example**: Adobe Reader "25.001.21151" vs "25.1.21151" normalize to same value despite different input
- **GitHub vs Website scraping**: Different sources format versions differently; normalization makes them comparable
- **Gotcha**: Manual CSV edits bypass normalization. Always run PowerShell script to refresh official version discovery

---

## App Deduplication

When `apps_update.ps1` processes input CSV:
1. Normalizes each app name via `Get-NormalizedAppName()` (lowercase, removes extra spaces)
2. **Skips duplicates silently** (only first occurrence is processed)
3. Example: Both "Adobe Acrobat 11 Pro" and "adobe acrobat 11 pro" normalize to same key → second is skipped

**Implication**: Duplicate rows in source CSV can disappear without warning. Always check `apps_output.csv` row count matches expected.

---

## Common Tasks & Patterns

### Adding a New App Source
1. Add entry to `data/appSources.json` with lowercase app name as key (spaces → hyphens)
2. Choose scraping strategy: GitHub API (most reliable) > Website regex scraping (fragile) > Fixed version (manual)
3. Test regex pattern in PowerShell console before committing:
   ```powershell
   $html = (Invoke-WebRequest -Uri 'https://...').Content
   if ($html -match 'Version\s+([0-9.]+)') { $Matches[1] }
   ```
4. Next `apps_update.ps1` run will auto-discover version

### Adding UI Columns
1. Add `<th data-key="FieldName">Label</th>` to HTML table header
2. Add `<td>` cell in `renderTable()` function (around [line 248](../../assets/js/script.js#L248))
3. Add CSS width class (`.col-fieldname { width: Xpx; }`)
4. **If data from CSV**: Update modal form to include hidden input to preserve during edits

### Debugging Version Discovery
- Run manually with logging: `./apps_update.ps1 | Tee-Object -FilePath debug.log`
- Check `data/apps_output.csv` for empty `LatestVersion` (indicates scraping failed)
- Use `-Verbose` flag or add `Write-Host` statements to trace API attempts
- RuckZuck first run is slow (~30s); subsequent runs use lightweight sync

### Chart Updates
- Doughnut chart (`state.chart`) counts `state.filtered` rows (respects current filters)
- Update triggered by `updateChart()` after status/license filter/sort changes
- Custom title drawn in `afterDatasetsDraw` plugin (hardcoded "Status dos Apps")

---

## Workflows & Commands

### Local Development
```bash
# Terminal 1: Start Python server (auto-reloads on apps_output.csv change)
python server.py
# Access at http://localhost:8000

# Terminal 2: Edit HTML/CSS/JS, refresh browser after save
# Cache busting: Increment ?v=NN in index.html script/link tags
```

### Running Version Update
```powershell
# Manual (from project root)
./apps_update.ps1

# Via UI: Click "Atualizar Agora" button → POST /run-update → executes PowerShell
```

### Testing CSV Parsing
Modify `defaultCsv` string in [script.js (line ~30)](../../assets/js/script.js#L30) to test edge cases (quoted commas, escaped quotes, empty fields).

---

## Key Files & Responsibilities

| File | Purpose | When to Edit |
|------|---------|-------------|
| [index.html](../../index.html) | Table structure, modal form, controls | Add columns, reorganize UI |
| [assets/js/script.js](../../assets/js/script.js) | State, filtering, rendering, forms | Core business logic, new features |
| [assets/css/style.css](../../assets/css/style.css) | Dark theme, responsive layout, colors | Styling, theme changes |
| [apps_update.ps1](../../apps_update.ps1) | Version scraping, normalization, APIs | Scraping strategies, new sources |
| [server.py](../../server.py) | HTTP server, PowerShell execution | Port changes, route additions |
| [data/appSources.json](../../data/appSources.json) | Per-app scraping rules | Add/update scraping patterns |

---

## Conventions & Gotchas

- **Portuguese UI**: All user-facing text (labels, buttons, placeholders) must be in Portuguese
- **Lowercase app keys**: `appSources.json` keys must match normalized names (lowercase, spaces → hyphens)
- **Modal field order matters**: CSV column order must match form input order for proper round-tripping
- **Hidden form fields**: `appversion`, `LatestVersion`, `SourceKey`, `IsDeleted` must be preserved even if not displayed
- **Chart data**: Always operates on `state.filtered`, never `state.data` (reflects active filters)
- **No build step**: Direct file edits; browser cache bypassed via `?v=` query parameter
- **PowerShell v5.1+**: Required for RuckZuck API (.NET HTTP client); test on target OS
- **Version normalization is one-way**: Manual CSV edits skip normalization. Always re-run script for official discovery
- **Browser ≠ PowerShell**: Editing versions in modal uses simplified comparison; PowerShell uses robust Win32 parsing
- **Deduplication is silent**: No console warning for duplicate app names. Check output CSV row count
