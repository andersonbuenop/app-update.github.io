# Copilot Instructions for app-update

## Project Overview
A single-file HTML application for managing and visualizing application inventory. Displays CSV data showing application versions, available updates, and installation status. Supports client-side filtering, search, and sorting.

## Core Architecture
- **Single-file design**: All HTML, CSS, and JavaScript in [index.html](../index.html)
- **Data source**: CSV file ([apps.csv](../apps.csv)) loaded via fetch with embedded fallback
- **State management**: Simple object-based state (`state` object) tracking data, filtered results, and sort configuration
- **No external dependencies**: Vanilla JS, no frameworks or libraries

## CSV Structure & Data Model
```
AppName, appversion, LatestVersion, Website, InstalledVersion, Status
```
**Status values**: `UpdateAvailable`, `UpToDate`, `Unknown`
- Empty/missing values are treated as empty strings
- Website field contains URLs (wrapped in links in output)
- Version comparison logic happens on data load, not in UI

## Key Patterns

### CSV Parsing
Custom parser in `parseCsv()` handles quoted fields with escaped quotes (`""`). Essential for robustness:
- Splits by newline, processes character-by-character with quote tracking
- Strips surrounding quotes from all values
- Used both for initial load and file upload

### Filtering & Sorting
- **Filtering** (`applyFilters()`): Combines status dropdown + text search across all fields (case-insensitive)
- **Sorting** (`sortBy()`): Intelligently treats version numbers as floats, falls back to string comparison
- Sort state persists across filter changes

### Data Loading Strategy
```
1. Try fetch('apps.csv') from same directory
2. On failure, use embedded defaultCsv
3. File input triggers re-parsing and full state reset
```

## UI Components & Styling
- **Dark theme**: Slate/gray palette (#0f172a background, #e5e7eb text)
- **Status pills**: Color-coded (`UpdateAvailable`=red, `UpToDate`=green, `Unknown`=blue)
- **Responsive**: Hides columns 2, 3, 5 on mobile (<768px)
- **Table interactions**: Sortable headers (click to toggle direction), hoverable rows

## Common Tasks

### Adding New Features
- **New filters**: Add `<select>` in `.controls` div, call `applyFilters()` on change
- **New status types**: Add CSS class `.status-{StatusValue}` with bg/border colors
- **New columns**: Add `<th data-key="FieldName">` and update CSV parsing to include field

### Modifying Filtering Logic
All filter logic in `applyFilters()`. Current approach:
- Matches **both** status AND search term
- Search term checked against concatenated lowercase string of all row values
- Reapplies sort after filtering

### Debugging
- Check `state` object in console to inspect data and filtered results
- `parseCsv()` output includes `headers` array—verify expected field names match CSV
- Mobile viewport hides columns; inspect element to verify expected columns

## Conventions
- **Portuguese UI**: Interface text, placeholders, and comments in Portuguese
- **Camel case**: JS variables (`statusFilter`, `searchInput`, `applyFilters`)
- **Event delegation**: Click handlers on table header `<th>` elements using `dataset.key`
- **No build step**: Direct file editing; test by opening in browser
