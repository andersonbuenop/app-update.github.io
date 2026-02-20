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
- **Output**: `data/apps_output.csv` with columns: `AppName`, `appversion`, `LatestVersion`, `Status`, `IsNewVersion`, `Observacao` (persisted from previous run)
- **Key insight**: Preserves user-edited "Observacao" across executions; detects new versions since last run (badge in UI)

#### RuckZuck API Behavior
- **First run**: Downloads full catalog (~10MB), stores in memory. May take 10-30s depending on network.
- **Subsequent runs**: Makes lightweight sync request. Much faster.
- **No disk cache**: Catalog is in-memory only. Each script execution re-initializes.
- **Matching logic**: Searches by exact `ShortName`, then contains-match on `ProductName`, sorted by download count.
- **Icon URLs**: Generated dynamically via `https://ruckzuck.tools/rest/v2/geticon?shortname={ShortName}`
- **When to bypass**: If RuckZuck is slow or unreliable, add entry to `appSources.json` with `Type: "Website"` or `"GitHub"` to use direct scraping instead.

### 2. **Frontend: Dashboard** ([index.html](../../index.html) + [assets/js/script.js](../../assets/js/script.js) + [assets/css/style.css](../../assets/css/style.css))
- **Data load**: `fetch('data/apps_output.csv')` → parsed into `state.data` array
- **Additional metadata**: `data/appSources.json` (loaded for version pattern rules if needed client-side)
- **State management**: Single `state` object tracks:
  - `data`: Full dataset
  - `filtered`: Current filtered/sorted view
  - `sort`: `{key, dir}` for column sorting (persists across filter changes)
  - `statusFilter`: Dropdown selection (UpdateAvailable/UpToDate/Unknown)
  - `chart`: Chart.js doughnut chart instance

### 3. **Backend: HTTP Server** ([server.py](../../server.py))
- Serves `index.html` and static assets
- **POST `/run-update`**: Executes `apps_update.ps1` via PowerShell, returns JSON response
- **Auto-reload**: Watches `apps_output.csv` for changes, restarts server (useful during scraping)

### 4. **UI State Sync**
- **Edit modal** (inline form): Loads/saves individual app rows via form submission
- **Filtering**: Status dropdown + text search → updates `state.filtered` and chart
- **Modal form** preserves hidden fields (`appversion`, `LatestVersion`, `SourceKey`) so CSV round-trips correctly

---

## Critical Data Patterns

### CSV Field Mapping
Input CSV (SCCM):
```
System_Name3 → AppName (normalized lowercase for appSources.json matching)
Version2 → appversion
```

Output CSV contains:
```
AppName, appversion, LatestVersion, Status, License, Observacao, IconUrl, SourceId, IsNewVersion, OutputUrl, SearchUrl
```

**Key constraint**: Modal must preserve all fields when editing (including hidden ones).

### appSources.json Structure
```json
{
  "app-name-key": {
    "Type": "Website|GitHub|Fixed|RuckZuck",
    "ScrapeUrl": "https://...",
    "VersionPattern": "regex-with-capture-group",
    "OutputUrl": "download-link",
    "Version": "hardcoded-version (for Type:Fixed)"
  }
}
```

**Design rationale**: Decoupled from app display name so SCCM normalization changes don't break scraping.

### Status Logic
- **Determined by**: Comparing `LatestVersion` vs `InstalledVersion` via `Compare-AppVersion()` function (PowerShell script, not browser)
- **Values**: `UpdateAvailable`, `UpToDate`, `Unknown`
- **Color coding**: CSS classes `.status-UpdateAvailable` (red), `.status-UpToDate` (green), `.status-Unknown` (blue)
- **⚠️ Important**: Browser-side `calculateStatus()` is a simplified heuristic and may differ from PowerShell logic. Manual editing of version fields via modal can cause discrepancies until next `apps_update.ps1` run.

---

## Version Normalization Rules (Critical)

PowerShell script applies complex normalization before comparison. Understanding these is essential to debug "wrong status" issues:

### Year-based versions
```powershell
# 4-digit years: 2025 → 25 (but only if formatted like 20XX)
# Partial year replacement: 2025.1.21111 → 25.1.21111 (removes "20" prefix)
# ExFixing Duplicate Apps (Data Loss Prevention)
**Symptom**: App count decreased after running script, or expected app is missing from output.

1. **Diagnosis**: Open `data/apps_output.csv` and check row count vs `apps.csv`
2. **Root cause**: Two rows normalize to same app name (e.g., "Visual Studio 2022" vs "visual studio 2022")
3. **Solution**:
   - Edit `apps.csv` to ensure unique normalized names (or remove deliberate duplicates)
   - Re-run `apps_update.ps1`
   - Verify deduplication message in console output

### Handling Failed Website Scraping
**Symptom**: App status is `Unknown`, `LatestVersion` is empty.

1. **Check appSources.json**: Does the app have an entry? Is the regex pattern still valid?
2. **Test regex**: Open PowerShell console, run:
   ```powershell
   $url = 'https://example.com/download'
   $html = (Invoke-WebRequest -Uri $url).Content
   if ($html -match 'Version\s+([0-9.]+)') { Write-Host $Matches[1] }
   ```
3. **If no match**: Update regex in `appSources.json` or switch to GitHub API (`Type: "GitHub"`, add `RepoUrl`)
4. **If GitHub**: Preferred fallback; requires valid repo URL (e.g., `https://github.com/owner/repo/releases/latest`)
5. **Re-run**: `./apps_update.ps1` will use updated config

### Correcting Manual Version Edits
**Symptom**: Edited app version via modal, but status shows wrong value after page reload.

**Why**: Modal uses browser-side `calculateStatus()` (heuristic), PowerShell uses `Compare-AppVersion()` (accurate). They can differ.

**Solution**:
- Edit via modal is **temporary** until next PowerShell run
- For permanent changes, either:
  1. Re-run `./apps_update.ps1` (official version detection)
  2. Or edit `data/apps_output.csv` directly **and** modify `appSources.json` for consistency
- Prefer: Let PowerShell scrape the version; edit only `Observacao` and `License` via modal

### ception: 2026.23.3.1 → stays 2026.23.3.1 (second segment ≥ 10, not a minor version)
```

### 3-part semantic versions with trailing zeros
```powershell
# 25.01.00.0 → 25.01 (strips .0.0 suffix)
# 25.1.0 → 25.01 (pads minor with leading zero if patch == 0)
# This reconciles Chocolatey (25.1.0) vs official releases (25.01)
```

### Why it matters
- **7-Zip example**: Official site publishes "25.01", Chocolatey packages as "25.1.0". Without normalization, both would look like different apps.
- **GitHub vs Website scraping**: Different sources format versions differently; normalization makes them comparable.
- **Gotcha**: Manual CSV edits bypassing normalization can cause status mismatches. Always run the PowerShell script to refresh.

---

## App Deduplication

When `apps_update.ps1` processes input CSV:
1. Normalizes each app name via `Get-NormalizedAppName()` (lowercase, removes extra spaces/numbers)
2. **Skips duplicates silently** (only first occurrence is processed)
3. Example: Both "Adobe Acrobat 11 Pro" and "adobe acrobat 11 pro" normalize to same key → second is ignored

**Implication**: Duplicate rows in source CSV can disappear without warning. Check `apps_output.csv` matches expected app count.

---

## Common Tasks & Patterns

### Adding a New App Source
1. Add entry to `data/appSources.json` with lowercase app name as key
2. Choose scraping strategy (GitHub API is most reliable; website scraping fragile)
3. Test regex pattern against target website in PowerShell console
4. Next `apps_update.ps1` run will auto-discover the version

### Adding UI Columns
1. Add `<th data-key="FieldName">` to HTML table header
2. Add `<td>` rendering in `renderTable()` function (around line 248)
3. Add CSS class for column width (`.col-fieldname`)
4. **Important**: If data comes from CSV, update modal form to include hidden input for preservation

### Debugging Version Discovery
- Run `apps_update.ps1` manually: `./apps_update.ps1 | Tee-Object -FilePath debug.log`
- Check `data/apps_output.csv` for missing `LatestVersion` values (indicates scraping failure)
- Enable `Write-Host` statements in PowerShell for tracing which API succeeded
- RuckZuck delays first-run API response; subsequent runs cache catalog

### Chart Updates
- Doughnut chart (`state.chart`) counts `state.filtered` rows, not all data
- Update triggered by `updateChart()` after filter/sort changes
- Custom title drawn in `afterDatasetsDraw` plugin (hardcoded "Status dos Apps")

---

## Workflows & Commands

### Development Workflow
```bash
# Terminal 1: Python server (auto-reloads on CSV change)
python server.py

# Terminal 2: Edit HTML/CSS/JS, refresh browser after each save
# Cache busting: Increment version in index.html script/link tags (?v=XX)
- **Version normalization is one-way**: Manual CSV edits skip normalization logic. Always re-run script for official version discovery.
- **Browser ≠ PowerShell logic**: Editing versions in modal uses simplified comparison; PowerShell uses robust Win32 version parsing. Expect discrepancies.
- **Deduplication is silent**: Duplicate normalized names are skipped without console warning. Check output CSV row count.
- **Preserve Observacao manually**: If you edit appSources.json directly (not via modal), ensure you don't lose existing observations from previous runs.
```

### Running Version Update
```powershell
# Manual update (from project root)
./apps_update.ps1

# Or via UI: Click "Atualizar Agora" button → POST /run-update → PowerShell runs script
```

### Testing CSV Parsing
Modify sample `defaultCsv` string in `script.js` (line ~30) to test edge cases (quoted commas, escaped quotes).

---

## Key Files & Responsibilities

| File | Purpose | When to Edit |
|------|---------|-------------|
| `index.html` | Table structure, modal form, control layout | Add columns, reorganize controls |
| `assets/js/script.js` | State, filtering, rendering, form handling | Core business logic, new features |
| `assets/css/style.css` | Dark theme, responsive layout, status colors | Styling, theme changes |
| `apps_update.ps1` | Version scraping logic, API fallbacks | Scraping strategies, new data sources |
| `server.py` | HTTP + script execution | Port changes, route additions |
| `data/appSources.json` | Per-app scraping rules | Add/update scraping patterns |

---

## Conventions & Gotchas

- **Portuguese UI**: All user-facing text (labels, placeholders, console messages) in Portuguese
- **Lowercase app keys**: appSources.json keys must match normalized app names (lowercase, spaces as `-`)
- **Modal persistence**: Form must include hidden inputs for all CSV fields, even if not displayed
- **Chart data**: Always operates on `state.filtered`, not `state.data` (reflects current filters)
- **No build step**: Direct file edits; version queries cached by `?v=` parameter
- **PowerShell v5.1+**: RuckZuck API requires .NET HTTP client; test on target OS
