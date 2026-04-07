# Interactive STEM Curriculum Explorer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a mobile-first GitHub Pages site where ASEE conference attendees scan a QR code and interactively explore similarity matrices between STEM programs.

**Architecture:** Single `index.html` page with inline CSS and JS. Four JSON data files loaded via fetch. CSS Grid heatmap, bottom drawer for controls, overlay detail panel on cell tap. No build step, no dependencies.

**Tech Stack:** Vanilla HTML/CSS/JS, GitHub Pages, viridis colorscale (embedded lookup table)

---

## File Structure

```
site/                          # GitHub Pages source directory
  index.html                   # Entire app — HTML structure, inline <style>, inline <script>
  data/
    computing.json             # Copy of similarity_metrics_computing.json
    engineering.json           # Copy of similarity_metrics_engineering.json
    sciences.json              # Copy of similarity_metrics_sciences.json
    interdisciplinary.json     # Copy of similarity_metrics_interdisciplinary.json
```

All app code lives in `site/index.html`. The JSON files are verbatim copies of the existing `similarity_metrics_{domain}.json` files (renamed for cleaner URLs). No test framework — this is a static page tested by opening it in a browser and verifying visually.

**Data shape reminder** (each JSON file):
```json
{
  "metadata": { "mode": "computing", "top_limit": null, ... },
  "labels": { "110701": "Computer Science", "141901": "Mechanical Engineering", ... },
  "matrices": {
    "jaccard": [[100, 21.37, ...], [21.37, 100, ...], ...],
    "tfidf": [[100, 4.4, ...], ...],
    "overlap": [...], "pmi": [...], "max_scaled": [...], "dice": [...], "kulczynski": [...]
  }
}
```
- `labels` is an object mapping CIP code strings to human-readable major names (one empty: CIP 110801 → use fallback "Web/Multimedia Management")
- Each matrix is a 2D array of floats in 0–100 range, indexed by label order
- Sizes: computing=10, engineering=25, sciences=25, interdisciplinary=6

---

### Task 1: Set Up Data Files

**Files:**
- Create: `site/data/computing.json`
- Create: `site/data/engineering.json`
- Create: `site/data/sciences.json`
- Create: `site/data/interdisciplinary.json`

- [ ] **Step 1: Create site/data directory and copy JSON files**

```bash
mkdir -p site/data
cp similarity_metrics_computing.json site/data/computing.json
cp similarity_metrics_engineering.json site/data/engineering.json
cp similarity_metrics_sciences.json site/data/sciences.json
cp similarity_metrics_interdisciplinary.json site/data/interdisciplinary.json
```

- [ ] **Step 2: Fix empty label in computing.json**

CIP 110801 has an empty name string. Patch it:

```bash
cd site/data
python3 -c "
import json
d = json.load(open('computing.json'))
if d['labels'].get('110801', '') == '':
    d['labels']['110801'] = 'Web/Multimedia Management'
    json.dump(d, open('computing.json', 'w'), indent=None)
    print('Patched 110801')
else:
    print('No patch needed')
"
```

- [ ] **Step 3: Verify all four files load and have expected structure**

```bash
python3 -c "
import json
for name in ['computing', 'engineering', 'sciences', 'interdisciplinary']:
    d = json.load(open(f'site/data/{name}.json'))
    n = len(d['labels'])
    m = len(d['matrices'])
    empty = [c for c,v in d['labels'].items() if not v.strip()]
    assert m == 7, f'{name}: expected 7 metrics, got {m}'
    assert not empty, f'{name}: empty labels for CIPs {empty}'
    print(f'{name}: {n} majors, {m} metrics — OK')
"
```

Expected output:
```
computing: 10 majors, 7 metrics — OK
engineering: 25 majors, 7 metrics — OK
sciences: 25 majors, 7 metrics — OK
interdisciplinary: 6 majors, 7 metrics — OK
```

- [ ] **Step 4: Commit**

```bash
git add site/data/
git commit -m "Add JSON data files for interactive explorer"
```

---

### Task 2: HTML Shell + CSS

**Files:**
- Create: `site/index.html`

Build the complete HTML structure and all CSS with an empty `<script>` block. The static layout lets you verify visual structure in a browser before adding JS.

- [ ] **Step 1: Create site/index.html with full HTML structure and CSS**

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>STEM Curriculum Explorer</title>
<style>
  :root {
    --clemson-orange: #F56600;
    --clemson-purple: #522D80;
    --bg: #fefefe;
    --text: #2d3436;
    --text-muted: #636e72;
    --surface: #f8f8f8;
    --border: #e0e0e0;
    --detail-bg: #f8f4fc;
  }

  * { margin: 0; padding: 0; box-sizing: border-box; }

  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: var(--bg);
    color: var(--text);
    overflow-x: hidden;
    -webkit-tap-highlight-color: transparent;
  }

  /* ── Header ── */
  .header {
    background: white;
    padding: 12px 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 3px solid var(--clemson-orange);
    position: sticky;
    top: 0;
    z-index: 100;
  }
  .header h1 {
    font-size: 18px;
    font-weight: 700;
    color: var(--clemson-purple);
  }
  .header-dots {
    display: flex;
    gap: 4px;
  }
  .header-dots span {
    width: 10px;
    height: 10px;
    border-radius: 50%;
  }
  .header-dots span:first-child { background: var(--clemson-orange); }
  .header-dots span:last-child { background: var(--clemson-purple); }

  /* ── Domain Pills ── */
  .domain-bar {
    display: flex;
    gap: 6px;
    padding: 10px 16px;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }
  .domain-pill {
    flex-shrink: 0;
    padding: 6px 14px;
    border-radius: 16px;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    border: none;
    background: #f0f0f0;
    color: var(--text-muted);
    transition: background 0.2s, color 0.2s;
  }
  .domain-pill.active {
    background: var(--clemson-purple);
    color: white;
  }

  /* ── Heatmap Container ── */
  .heatmap-container {
    padding: 12px 8px;
    overflow: auto;
    -webkit-overflow-scrolling: touch;
    /* Leave room for collapsed drawer */
    padding-bottom: 80px;
  }
  .heatmap-wrapper {
    display: inline-block;
    min-width: 100%;
  }

  /* Column labels */
  .col-labels {
    display: grid;
    gap: 2px;
    padding-left: 0; /* set dynamically */
    margin-bottom: 4px;
  }
  .col-label {
    font-size: 10px;
    color: var(--text-muted);
    text-align: left;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    transform: rotate(-45deg);
    transform-origin: left bottom;
    height: 60px;
    display: flex;
    align-items: flex-end;
  }

  /* Grid rows */
  .heatmap-row {
    display: grid;
    gap: 2px;
    align-items: center;
  }
  .row-label {
    font-size: 10px;
    color: var(--text-muted);
    text-align: right;
    padding-right: 6px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .cell {
    aspect-ratio: 1;
    border-radius: 2px;
    cursor: pointer;
    transition: background-color 0.3s ease;
    position: relative;
  }
  .cell:hover, .cell.selected {
    outline: 2px solid var(--clemson-orange);
    outline-offset: -1px;
    z-index: 1;
  }

  /* ── Color Legend ── */
  .legend {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 8px 0;
  }
  .legend span {
    font-size: 11px;
    color: var(--text-muted);
  }
  .legend-gradient {
    height: 8px;
    width: 140px;
    border-radius: 4px;
    background: linear-gradient(to right,
      #440154, #482878, #3e4989, #31688e, #26828e,
      #1f9e89, #35b779, #6ece58, #b5de2b, #fde725
    );
  }

  /* ── Detail Panel ── */
  .detail-panel {
    display: none;
    position: fixed;
    bottom: 70px;
    left: 8px;
    right: 8px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 -2px 20px rgba(0,0,0,0.15);
    padding: 16px;
    z-index: 200;
    max-height: 50vh;
    overflow-y: auto;
  }
  .detail-panel.visible {
    display: block;
    animation: slideUp 0.2s ease-out;
  }
  @keyframes slideUp {
    from { transform: translateY(20px); opacity: 0; }
    to { transform: translateY(0); opacity: 1; }
  }
  .detail-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 12px;
  }
  .detail-pair-name {
    font-size: 14px;
    font-weight: 600;
    color: var(--clemson-purple);
  }
  .detail-close {
    background: none;
    border: none;
    font-size: 20px;
    color: var(--text-muted);
    cursor: pointer;
    padding: 0 4px;
    line-height: 1;
  }
  .metric-bar-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }
  .metric-bar-label {
    font-size: 11px;
    color: var(--text-muted);
    width: 75px;
    flex-shrink: 0;
    text-align: right;
  }
  .metric-bar-track {
    flex: 1;
    height: 14px;
    background: #f0f0f0;
    border-radius: 7px;
    overflow: hidden;
  }
  .metric-bar-fill {
    height: 100%;
    border-radius: 7px;
    transition: width 0.3s ease;
    background: var(--clemson-purple);
  }
  .metric-bar-fill.highlighted {
    background: var(--clemson-orange);
  }
  .metric-bar-value {
    font-size: 11px;
    font-weight: 600;
    width: 40px;
    flex-shrink: 0;
  }
  .classification {
    margin-top: 10px;
    padding: 8px 10px;
    background: var(--detail-bg);
    border-left: 3px solid var(--clemson-purple);
    border-radius: 0 6px 6px 0;
    font-size: 12px;
  }
  .classification-label {
    font-weight: 700;
    color: var(--clemson-purple);
  }
  .classification-note {
    font-size: 10px;
    color: var(--text-muted);
    margin-top: 4px;
    font-style: italic;
  }

  /* ── Bottom Drawer ── */
  .drawer-overlay {
    display: none;
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.3);
    z-index: 299;
  }
  .drawer-overlay.visible { display: block; }

  .drawer {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    background: var(--surface);
    border-top: 1px solid var(--border);
    border-radius: 14px 14px 0 0;
    z-index: 300;
    transition: transform 0.3s ease;
    max-height: 55vh;
  }
  .drawer.collapsed { transform: translateY(calc(100% - 70px)); }
  .drawer.expanded { transform: translateY(0); overflow-y: auto; }

  .drawer-handle {
    padding: 10px;
    cursor: pointer;
    display: flex;
    flex-direction: column;
    align-items: center;
  }
  .drawer-handle-bar {
    width: 36px;
    height: 4px;
    background: #ccc;
    border-radius: 2px;
  }

  .drawer-content {
    padding: 0 16px 20px;
  }

  .drawer-section-label {
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-muted);
    margin-bottom: 6px;
    margin-top: 12px;
  }

  .metric-chips {
    display: flex;
    gap: 6px;
    overflow-x: auto;
    padding-bottom: 4px;
    -webkit-overflow-scrolling: touch;
  }
  .metric-chip {
    flex-shrink: 0;
    padding: 6px 12px;
    border-radius: 14px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    border: 1px solid var(--border);
    background: white;
    color: var(--text-muted);
    transition: background 0.2s, color 0.2s, border-color 0.2s;
  }
  .metric-chip.active {
    background: var(--clemson-orange);
    color: white;
    border-color: var(--clemson-orange);
  }

  .major-toggles {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .major-toggle {
    padding: 5px 10px;
    border-radius: 14px;
    font-size: 11px;
    cursor: pointer;
    border: 1px solid var(--border);
    background: white;
    color: var(--text-muted);
    transition: background 0.2s, color 0.2s, border-color 0.2s;
  }
  .major-toggle.active {
    background: var(--clemson-purple);
    color: white;
    border-color: var(--clemson-purple);
  }

  .quick-select {
    display: flex;
    gap: 8px;
    margin-top: 10px;
  }
  .quick-select button {
    padding: 4px 12px;
    border-radius: 10px;
    font-size: 11px;
    cursor: pointer;
    border: 1px solid var(--border);
    background: white;
    color: var(--text-muted);
  }
  .quick-select button:active {
    background: #eee;
  }
</style>
</head>
<body>

  <!-- Header -->
  <header class="header">
    <h1>STEM Curriculum Explorer</h1>
    <div class="header-dots"><span></span><span></span></div>
  </header>

  <!-- Domain pills -->
  <nav class="domain-bar" id="domainBar"></nav>

  <!-- Heatmap area -->
  <main class="heatmap-container" id="heatmapContainer">
    <div class="heatmap-wrapper" id="heatmapWrapper">
      <!-- Column labels and grid rows injected by JS -->
    </div>
    <div class="legend">
      <span>0%</span>
      <div class="legend-gradient"></div>
      <span>100%</span>
    </div>
  </main>

  <!-- Detail panel (cell tap) -->
  <div class="detail-panel" id="detailPanel">
    <div class="detail-header">
      <div class="detail-pair-name" id="detailPairName"></div>
      <button class="detail-close" id="detailClose">&times;</button>
    </div>
    <div id="detailBars"></div>
    <div class="classification" id="detailClassification">
      <div><span class="classification-label" id="classLabel"></span> <span id="classDesc"></span></div>
      <div class="classification-note">Classification is approximate based on metric signatures.</div>
    </div>
  </div>

  <!-- Bottom drawer -->
  <div class="drawer-overlay" id="drawerOverlay"></div>
  <div class="drawer collapsed" id="drawer">
    <div class="drawer-handle" id="drawerHandle">
      <div class="drawer-handle-bar"></div>
    </div>
    <div class="drawer-content">
      <div class="drawer-section-label">Metric</div>
      <div class="metric-chips" id="metricChips"></div>
      <div class="drawer-section-label">Majors</div>
      <div class="major-toggles" id="majorToggles"></div>
      <div class="quick-select" id="quickSelect"></div>
    </div>
  </div>

<script>
// JS will go here in subsequent tasks
</script>
</body>
</html>
```

- [ ] **Step 2: Open in browser and verify layout**

```bash
cd site && python3 -m http.server 8000 &
echo "Open http://localhost:8000 in browser — verify header, orange underline, empty heatmap area, drawer at bottom"
```

Verify: header shows "STEM Curriculum Explorer" in purple with orange underline and two dots. Empty main area. Drawer bar visible at bottom. Kill the server when done.

- [ ] **Step 3: Commit**

```bash
git add site/index.html
git commit -m "Add HTML shell and CSS for interactive explorer"
```

---

### Task 3: Core Data Loading and State Management

**Files:**
- Modify: `site/index.html` (replace the `<script>` block)

Add the JS that loads JSON data, manages application state, and renders the domain pills and metric/major controls. No heatmap rendering yet — just the controls.

- [ ] **Step 1: Add state management and data loading JS**

Replace the `<script>` comment block in `site/index.html` with:

```javascript
// ── Viridis colorscale (256 entries, [r, g, b]) ──
const VIRIDIS = [
  [68,1,84],[68,2,86],[69,4,87],[69,5,89],[70,7,90],[70,8,92],[70,10,93],[70,11,94],
  [71,13,96],[71,14,97],[71,16,99],[71,17,100],[71,19,101],[72,20,103],[72,22,104],
  [72,23,105],[72,24,106],[72,26,108],[72,27,109],[72,28,110],[72,29,111],[72,31,112],
  [72,32,113],[72,33,115],[72,35,116],[72,36,117],[72,37,118],[72,38,119],[72,40,120],
  [72,41,121],[71,42,122],[71,44,122],[71,45,123],[71,46,124],[71,47,125],[70,48,126],
  [70,50,126],[70,51,127],[69,52,128],[69,53,129],[69,55,129],[68,56,130],[68,57,131],
  [68,58,131],[67,60,132],[67,61,132],[66,62,133],[66,63,133],[66,64,134],[65,66,134],
  [65,67,135],[64,68,135],[64,69,136],[63,71,136],[63,72,137],[62,73,137],[62,74,137],
  [62,76,138],[61,77,138],[61,78,138],[60,79,139],[60,80,139],[59,82,139],[59,83,140],
  [58,84,140],[58,85,140],[57,86,140],[57,87,141],[56,88,141],[56,90,141],[55,91,141],
  [55,92,141],[54,93,141],[54,94,142],[53,95,142],[53,96,142],[52,97,142],[52,98,142],
  [51,99,142],[51,100,142],[50,101,142],[50,102,142],[49,103,142],[49,104,142],
  [49,105,142],[48,106,142],[48,107,142],[47,108,142],[47,109,142],[46,110,142],
  [46,111,142],[45,112,142],[45,113,142],[44,113,142],[44,114,142],[44,115,142],
  [43,116,141],[43,117,141],[42,118,141],[42,119,141],[42,120,141],[41,121,141],
  [41,122,141],[40,122,140],[40,123,140],[40,124,140],[39,125,140],[39,126,140],
  [38,127,139],[38,128,139],[38,129,139],[37,130,139],[37,131,138],[36,131,138],
  [36,132,138],[35,133,137],[35,134,137],[35,135,137],[34,136,136],[34,137,136],
  [33,137,135],[33,138,135],[33,139,134],[32,140,134],[32,141,133],[32,141,133],
  [31,142,132],[31,143,132],[31,144,131],[30,145,131],[30,145,130],[30,146,130],
  [30,147,129],[29,148,128],[29,149,128],[29,149,127],[29,150,127],[28,151,126],
  [28,152,125],[28,152,125],[28,153,124],[27,154,123],[27,155,123],[27,155,122],
  [27,156,121],[27,157,121],[27,158,120],[27,158,119],[27,159,119],[27,160,118],
  [27,161,117],[27,161,117],[27,162,116],[27,163,115],[27,163,114],[27,164,114],
  [28,165,113],[28,165,112],[28,166,111],[29,167,111],[29,167,110],[29,168,109],
  [30,169,108],[30,169,107],[31,170,107],[31,171,106],[32,171,105],[33,172,104],
  [33,173,103],[34,173,102],[35,174,101],[36,174,101],[37,175,100],[37,176,99],
  [38,176,98],[39,177,97],[40,177,96],[41,178,95],[42,178,94],[44,179,93],
  [45,179,92],[46,180,91],[47,180,90],[49,181,89],[50,181,88],[52,182,87],
  [53,182,86],[55,183,85],[56,183,84],[58,184,83],[59,184,82],[61,185,81],
  [63,185,80],[64,186,79],[66,186,78],[68,187,77],[70,187,76],[71,188,75],
  [73,188,73],[75,189,72],[77,189,71],[79,190,70],[81,190,69],[83,191,68],
  [85,191,67],[87,192,66],[89,192,65],[91,193,64],[93,193,63],[95,194,62],
  [97,194,61],[100,195,60],[102,195,59],[104,196,58],[106,196,57],[108,197,56],
  [110,197,56],[113,198,55],[115,198,54],[117,199,53],[119,199,52],[121,200,52],
  [124,200,51],[126,201,50],[128,201,49],[131,202,49],[133,202,48],[135,203,48],
  [138,203,47],[140,204,47],[142,204,46],[145,205,46],[147,205,45],[150,206,45],
  [152,206,44],[155,207,44],[157,207,44],[159,208,44],[162,208,43],[164,209,43],
  [167,209,43],[169,210,43],[172,210,43],[174,211,43],[177,211,43],[179,211,43],
  [182,212,43],[184,212,44],[187,213,44],[189,213,44],[192,213,45],[194,214,45],
  [197,214,46],[199,214,46],[201,215,47],[204,215,47],[206,215,48],[209,216,49],
  [211,216,49],[213,216,50],[216,217,51],[218,217,52],[220,217,53],[223,218,54],
  [225,218,55],[227,218,56],[229,219,57],[232,219,58],[234,219,60],[236,220,61],
  [238,220,62],[240,221,64],[242,221,65],[244,222,67],[246,222,68],[248,223,70],
  [249,223,72],[251,224,73],[253,225,75]
];

// ── Metric display config ──
const METRIC_NAMES = {
  jaccard:    'Jaccard',
  tfidf:      'TF-IDF Cosine',
  overlap:    'Overlap',
  pmi:        'PMI',
  max_scaled: 'Max-Scaled',
  dice:       'Dice',
  kulczynski: 'Kulczynski'
};
const METRIC_KEYS = Object.keys(METRIC_NAMES);

const DOMAIN_NAMES = {
  interdisciplinary: 'Cross-Domain',
  computing:         'Computing',
  engineering:       'Engineering',
  sciences:          'Sciences'
};
const DOMAIN_KEYS = Object.keys(DOMAIN_NAMES);

// ── App state ──
const state = {
  domain: 'interdisciplinary',
  metric: 'jaccard',
  data: {},            // { domain: loadedJSON }
  activeMajors: [],    // array of indices into current labels
  labels: [],          // ordered array of { cip, name } from current domain
  selectedCell: null   // { row, col } or null
};

// ── Helpers ──
function viridisColor(value) {
  // value: 0–100 → index 0–255
  const idx = Math.round(Math.min(100, Math.max(0, value)) * 2.55);
  const [r, g, b] = VIRIDIS[Math.min(idx, 255)];
  return `rgb(${r},${g},${b})`;
}

function viridisTextColor(value) {
  // Light text for dark cells (low values), dark text for bright cells (high values)
  return value > 55 ? '#333' : '#fff';
}

function classify(pair) {
  // pair: { jaccard, tfidf, overlap, pmi, max_scaled, dice, kulczynski }
  const { jaccard, tfidf, overlap } = pair;
  if (jaccard > 30 && tfidf > 20) {
    return { label: 'Convergent', desc: 'High shared general and specialized content' };
  }
  if (overlap > 50 && jaccard < 30) {
    return { label: 'Nested', desc: "One program's courses are largely a subset of the other" };
  }
  if (jaccard >= 20 && jaccard <= 50 && tfidf < 20) {
    return { label: 'Parallel', desc: 'Shared base curriculum with divergent specializations' };
  }
  return { label: 'Weak', desc: 'Low curricular overlap across all measures' };
}

function getMetricsForPair(row, col) {
  const d = state.data[state.domain];
  const result = {};
  for (const key of METRIC_KEYS) {
    const ri = state.activeMajors[row];
    const ci = state.activeMajors[col];
    result[key] = d.matrices[key][ri][ci];
  }
  return result;
}

// ── Data loading ──
async function loadDomain(domain) {
  if (state.data[domain]) return state.data[domain];
  const resp = await fetch(`data/${domain}.json`);
  const json = await resp.json();
  state.data[domain] = json;
  return json;
}

async function switchDomain(domain) {
  state.domain = domain;
  state.selectedCell = null;
  const d = await loadDomain(domain);
  state.labels = Object.entries(d.labels).map(([cip, name]) => ({ cip, name }));
  state.activeMajors = state.labels.map((_, i) => i);
  renderDomainPills();
  renderDrawerControls();
  renderHeatmap();
  hideDetail();
}

function switchMetric(metric) {
  state.metric = metric;
  renderMetricChips();
  renderHeatmap();
  // If detail panel is open, refresh it with new highlighted metric
  if (state.selectedCell) {
    showDetail(state.selectedCell.row, state.selectedCell.col);
  }
}

function toggleMajor(index) {
  const pos = state.activeMajors.indexOf(index);
  if (pos !== -1) {
    if (state.activeMajors.length <= 2) return; // minimum 2
    state.activeMajors.splice(pos, 1);
  } else {
    state.activeMajors.push(index);
    state.activeMajors.sort((a, b) => a - b);
  }
  state.selectedCell = null;
  hideDetail();
  renderMajorToggles();
  renderHeatmap();
}

function selectAllMajors() {
  state.activeMajors = state.labels.map((_, i) => i);
  state.selectedCell = null;
  hideDetail();
  renderMajorToggles();
  renderHeatmap();
}

function selectNoneMajors() {
  // Keep first 2
  state.activeMajors = [0, 1];
  state.selectedCell = null;
  hideDetail();
  renderMajorToggles();
  renderHeatmap();
}

function selectTop10Majors() {
  state.activeMajors = state.labels.slice(0, Math.min(10, state.labels.length)).map((_, i) => i);
  state.selectedCell = null;
  hideDetail();
  renderMajorToggles();
  renderHeatmap();
}

// ── Render: Domain Pills ──
function renderDomainPills() {
  const bar = document.getElementById('domainBar');
  bar.innerHTML = DOMAIN_KEYS.map(key =>
    `<button class="domain-pill${key === state.domain ? ' active' : ''}"
            onclick="switchDomain('${key}')">${DOMAIN_NAMES[key]}</button>`
  ).join('');
}

// ── Render: Drawer Controls ──
function renderDrawerControls() {
  renderMetricChips();
  renderMajorToggles();
  renderQuickSelect();
}

function renderMetricChips() {
  const el = document.getElementById('metricChips');
  el.innerHTML = METRIC_KEYS.map(key =>
    `<button class="metric-chip${key === state.metric ? ' active' : ''}"
            onclick="switchMetric('${key}')">${METRIC_NAMES[key]}</button>`
  ).join('');
}

function renderMajorToggles() {
  const el = document.getElementById('majorToggles');
  el.innerHTML = state.labels.map((lbl, i) =>
    `<button class="major-toggle${state.activeMajors.includes(i) ? ' active' : ''}"
            onclick="toggleMajor(${i})">${lbl.name || lbl.cip}</button>`
  ).join('');
}

function renderQuickSelect() {
  const el = document.getElementById('quickSelect');
  const showTop10 = state.labels.length > 10;
  el.innerHTML = `
    <button onclick="selectAllMajors()">All</button>
    ${showTop10 ? '<button onclick="selectTop10Majors()">Top 10</button>' : ''}
    <button onclick="selectNoneMajors()">None</button>
  `;
}

// ── Render: Heatmap ──
function renderHeatmap() {
  const wrapper = document.getElementById('heatmapWrapper');
  const d = state.data[state.domain];
  if (!d) { wrapper.innerHTML = ''; return; }

  const active = state.activeMajors;
  const n = active.length;
  const matrix = d.matrices[state.metric];
  const labels = active.map(i => state.labels[i]);

  // Determine cell size
  const containerWidth = document.getElementById('heatmapContainer').clientWidth - 16;
  const labelWidth = 80;
  const available = containerWidth - labelWidth;
  const cellSize = Math.max(16, Math.floor((available - (n - 1) * 2) / n));

  const colWidth = `${cellSize}px`;
  const gridCols = `${labelWidth}px repeat(${n}, ${colWidth})`;

  let html = '';

  // Column labels row
  html += `<div class="heatmap-row" style="grid-template-columns: ${gridCols}">`;
  html += '<div></div>';
  for (const lbl of labels) {
    html += `<div class="col-label" style="width:${cellSize}px">${lbl.name || lbl.cip}</div>`;
  }
  html += '</div>';

  // Data rows
  for (let r = 0; r < n; r++) {
    html += `<div class="heatmap-row" style="grid-template-columns: ${gridCols}">`;
    html += `<div class="row-label">${labels[r].name || labels[r].cip}</div>`;
    for (let c = 0; c < n; c++) {
      const val = matrix[active[r]][active[c]];
      const bg = viridisColor(val);
      const selected = state.selectedCell && state.selectedCell.row === r && state.selectedCell.col === c;
      html += `<div class="cell${selected ? ' selected' : ''}"
                   style="background-color:${bg}"
                   onclick="cellTap(${r},${c})"
                   title="${labels[r].name} × ${labels[c].name}: ${val.toFixed(1)}%"></div>`;
    }
    html += '</div>';
  }

  wrapper.innerHTML = html;
}

// ── Cell Tap → Detail Panel ──
function cellTap(row, col) {
  state.selectedCell = { row, col };
  renderHeatmap(); // re-render to show selection outline
  showDetail(row, col);
}

function showDetail(row, col) {
  const labels = state.activeMajors.map(i => state.labels[i]);
  const nameA = labels[row].name || labels[row].cip;
  const nameB = labels[col].name || labels[col].cip;
  const metrics = getMetricsForPair(row, col);

  document.getElementById('detailPairName').textContent = `${nameA} × ${nameB}`;

  // Metric bars
  const barsHtml = METRIC_KEYS.map(key => {
    const val = metrics[key];
    const highlighted = key === state.metric ? ' highlighted' : '';
    return `<div class="metric-bar-row">
      <div class="metric-bar-label">${METRIC_NAMES[key]}</div>
      <div class="metric-bar-track">
        <div class="metric-bar-fill${highlighted}" style="width:${val}%"></div>
      </div>
      <div class="metric-bar-value">${val.toFixed(1)}</div>
    </div>`;
  }).join('');
  document.getElementById('detailBars').innerHTML = barsHtml;

  // Classification
  const cls = classify(metrics);
  document.getElementById('classLabel').textContent = cls.label + ':';
  document.getElementById('classDesc').textContent = cls.desc;

  document.getElementById('detailPanel').classList.add('visible');
}

function hideDetail() {
  document.getElementById('detailPanel').classList.remove('visible');
  state.selectedCell = null;
}

// ── Drawer Toggle ──
function setupDrawer() {
  const drawer = document.getElementById('drawer');
  const overlay = document.getElementById('drawerOverlay');
  const handle = document.getElementById('drawerHandle');

  function toggle() {
    const isExpanded = drawer.classList.contains('expanded');
    drawer.classList.toggle('collapsed', !isExpanded);
    drawer.classList.toggle('expanded', isExpanded ? false : true);
    overlay.classList.toggle('visible', !isExpanded);
  }

  handle.addEventListener('click', toggle);
  overlay.addEventListener('click', toggle);
}

// ── Detail close ──
function setupDetail() {
  document.getElementById('detailClose').addEventListener('click', () => {
    hideDetail();
    renderHeatmap(); // clear selection
  });

  // Close detail when tapping outside heatmap and detail panel
  document.getElementById('heatmapContainer').addEventListener('click', (e) => {
    if (!e.target.classList.contains('cell') && state.selectedCell) {
      hideDetail();
      renderHeatmap();
    }
  });
}

// ── Init ──
async function init() {
  setupDrawer();
  setupDetail();
  await switchDomain('interdisciplinary');
}

init();
```

- [ ] **Step 2: Test in browser**

```bash
cd site && python3 -m http.server 8000 &
```

Open http://localhost:8000 on both desktop and phone (or Chrome DevTools mobile emulation). Verify:

1. Header: "STEM Curriculum Explorer" in purple, orange underline, two dots
2. Domain pills: "Cross-Domain" active in purple, others gray
3. Heatmap: 6×6 viridis grid with labels for interdisciplinary majors
4. Legend: gradient bar with 0% and 100%
5. Tap a cell: detail panel slides up showing pair name, 7 metric bars, classification label
6. Detail panel: current metric bar highlighted in orange, others purple
7. Tap × to close detail
8. Drawer handle at bottom: tap to expand, shows metric chips and major toggles
9. Switch domain to "Engineering": heatmap redraws with 25×25 grid, "Top 10" button appears in quick select
10. Toggle off a major: that row/column disappears from heatmap
11. Switch metric: cell colors transition smoothly
12. "All" / "None" / "Top 10" quick select buttons work

- [ ] **Step 3: Commit**

```bash
git add site/index.html
git commit -m "Add interactive heatmap with controls, detail panel, and drawer"
```

---

### Task 4: Polish and Mobile Fixes

**Files:**
- Modify: `site/index.html`

Test on actual phone or tight mobile emulation (375px width) and fix any issues. This task covers known mobile concerns from the spec.

- [ ] **Step 1: Fix column labels for small grids vs large grids**

In the `renderHeatmap` function, after the line `const cellSize = ...`, add adaptive label sizing:

```javascript
  // Adaptive label font size
  const labelFontSize = n > 15 ? '8px' : n > 10 ? '9px' : '10px';
  const colLabelHeight = n > 15 ? '45px' : '60px';
```

Update the column label rendering to use these:

```javascript
    html += `<div class="col-label" style="width:${cellSize}px;font-size:${labelFontSize};height:${colLabelHeight}">${lbl.name || lbl.cip}</div>`;
```

And update row labels similarly:

```javascript
    html += `<div class="row-label" style="font-size:${labelFontSize}">${labels[r].name || labels[r].cip}</div>`;
```

- [ ] **Step 2: Add touch feedback to cells**

Add this CSS rule inside the `<style>` block, after the `.cell:hover` rule:

```css
  .cell:active {
    transform: scale(0.92);
    transition: transform 0.1s;
  }
```

- [ ] **Step 3: Prevent body scroll when drawer is expanded**

In the `setupDrawer` function's `toggle()`, add body scroll lock:

```javascript
    document.body.style.overflow = isExpanded ? '' : 'hidden';
```

This goes right after the `overlay.classList.toggle(...)` line.

- [ ] **Step 4: Add a loading indicator**

Add this HTML right after the opening `<main>` tag (before `heatmap-wrapper`):

```html
    <div id="loadingIndicator" style="text-align:center;padding:40px;color:var(--text-muted);">
      Loading data...
    </div>
```

In the `init()` function, after `await switchDomain(...)`, add:

```javascript
  document.getElementById('loadingIndicator').style.display = 'none';
```

- [ ] **Step 5: Test on mobile emulation**

Open Chrome DevTools, toggle device toolbar, select iPhone SE (375×667). Verify:

1. Everything fits without horizontal scroll on the interdisciplinary 6×6 view
2. Engineering 25×25: heatmap scrolls horizontally, cells are tappable
3. Engineering top 10: comfortable size, no scroll needed
4. Drawer expands/collapses, body doesn't scroll behind it
5. Detail panel doesn't overlap with drawer
6. Metric chips scroll horizontally if they overflow
7. Cell tap → detail → tap another cell → detail updates in place
8. No loading flash — indicator disappears after data loads

- [ ] **Step 6: Commit**

```bash
git add site/index.html
git commit -m "Polish mobile experience: adaptive labels, touch feedback, scroll lock"
```

---

### Task 5: Deploy to GitHub Pages

**Files:**
- No new files — configure existing repo

- [ ] **Step 1: Add site directory to git tracking**

Verify all site files are tracked:

```bash
git status site/
```

All files should already be tracked from prior commits. If not:

```bash
git add site/
git commit -m "Ensure site directory is fully tracked"
```

- [ ] **Step 2: Push to GitHub and enable Pages**

```bash
git push origin master
```

Then configure GitHub Pages:
- Go to repo Settings → Pages
- Source: "Deploy from a branch"
- Branch: `master`, folder: `/site`
- Save

Alternatively, if you prefer the `docs/` convention, rename `site/` to `docs/` and adjust. The spec mentions `docs/` but this plan uses `site/` to avoid conflicting with `docs/superpowers/`.

- [ ] **Step 3: Verify deployment**

After a minute or two, visit `https://<username>.github.io/<repo>/`. Verify the full interactive experience works on both desktop and phone.

- [ ] **Step 4: Generate QR code**

Use any QR generator (or the command line):

```bash
# If qrencode is installed:
qrencode -o qrcode.png -s 10 "https://<username>.github.io/<repo>/"
# Otherwise use a web-based generator with the URL
```

- [ ] **Step 5: Commit QR code**

```bash
git add qrcode.png
git commit -m "Add QR code for conference poster"
git push origin master
```

---

## Summary

| Task | What | Files | Depends On |
|------|------|-------|------------|
| 1 | Data files setup | `site/data/*.json` | — |
| 2 | HTML shell + CSS | `site/index.html` | — |
| 3 | Core JS: data loading, state, controls, heatmap, detail panel, drawer | `site/index.html` | 1, 2 |
| 4 | Mobile polish | `site/index.html` | 3 |
| 5 | Deploy to GitHub Pages + QR code | config | 4 |

Tasks 1 and 2 can run in parallel. Tasks 3–5 are sequential.
