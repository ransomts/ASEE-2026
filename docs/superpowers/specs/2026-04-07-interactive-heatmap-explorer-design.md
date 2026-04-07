# Interactive STEM Curriculum Explorer — Design Spec

## Purpose

A single-page GitHub Pages site that conference attendees reach by scanning a QR code at the ASEE 2026 poster session. The page lets them interactively explore similarity matrices between STEM programs derived from the MIDFIELD dataset.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Layout | Heatmap-first + bottom drawer (B) | Maximizes visualization on phones; instant payoff after QR scan; familiar mobile pattern |
| Data scope | Full domain sets (all majors per domain) | ~160KB total; lets users discover unexpected pairings; no browser-side math needed |
| Color: heatmap | Viridis | Colorblind-safe, perceptually uniform, familiar to STEM audience |
| Color: UI chrome | Clemson accents on white (subtle) | Purple (#522D80) headings/active domains, orange (#F56600) active states/accents; brand present but data stays focal |
| Cell tap detail | Multi-metric signature + relationship label | One tap shows all 7 metrics for a pair plus nested/parallel/convergent classification |
| Major toggle | Within-domain toggle on/off | Users can show/hide any major in the selected domain; heatmap updates live |

## Architecture

Single `index.html` file deployed to GitHub Pages. No build step, no framework, no server-side code.

### Files

```
docs/                         # GitHub Pages source (or gh-pages branch)
  index.html                  # The entire app — HTML + CSS + JS
  data/
    computing.json            # Full similarity_metrics_computing.json
    engineering.json
    sciences.json
    interdisciplinary.json
```

The JSON files are the existing `similarity_metrics_{domain}.json` files, renamed for cleaner URLs. Total payload: ~160KB.

### Page Structure

```
+------------------------------------------+
| STEM Curriculum Explorer        [Clemson] |  <- white header, orange underline
+------------------------------------------+
| (Computing)  Engineering  Sciences  Cross |  <- domain pills, purple active
+------------------------------------------+
|                                          |
|           [ VIRIDIS HEATMAP ]            |  <- main content area
|           with row/column labels         |
|           pinch-to-zoom on mobile        |
|                                          |
|  0% |████████████████████████████| 100%  |  <- viridis gradient legend
|                                          |
|  ┌─ CS × MechEng ──────────────────┐    |  <- detail panel (appears on tap)
|  │ Jaccard    ████████░░ 21.4%      │    |
|  │ TF-IDF    █░░░░░░░░░  4.4%      │    |
|  │ Overlap   █████████░ 64.6%      │    |
|  │ PMI       █░░░░░░░░░  2.0%      │    |
|  │ MaxScaled ███░░░░░░░ 18.5%      │    |
|  │ Dice      █████░░░░░ 35.2%      │    |
|  │ Kulczynski ██████░░░ 44.4%      │    |
|  │                                  │    |
|  │ Classification: Nested           │    |
|  │ (high overlap, low jaccard)      │    |
|  └──────────────────────────────────┘    |
+------------------------------------------+
| ─── (drawer handle) ───                  |  <- bottom drawer (swipe up)
| [Jaccard] TF-IDF  Overlap  PMI  ...     |  <- metric selector
| ↑ Swipe for majors                      |
+------------------------------------------+

Drawer expanded:
+------------------------------------------+
| Metric: [Jaccard] TF-IDF Overlap PMI ... |
|                                          |
| Majors:                                  |
| [✓ Comp Sci] [✓ Info Tech] [✓ Info Sci] |
| [  Software] [  Comp Eng] [✓ Web Dev  ] |
|                                          |
| Select: All | Top 10 | None             |
+------------------------------------------+
```

### Interaction Flow

1. **Page load**: Default to "interdisciplinary" domain, "jaccard" metric, all majors selected. This gives the simplest, most interpretable first view (6 majors).
2. **Domain switch**: Tap a domain pill. Heatmap redraws with that domain's data. Major toggles update to show that domain's majors.
3. **Metric switch**: Tap a metric chip in the drawer. Heatmap redraws with smooth CSS transition (cells fade to new colors).
4. **Major toggle**: Tap a major chip to include/exclude it. Heatmap adds/removes that row and column. Minimum 2 majors enforced.
5. **Cell tap**: Tap a heatmap cell to see the detail panel — all 7 metric values for that pair displayed as horizontal bars, plus the relationship classification.
6. **Quick select**: "All" and "None" buttons for fast major selection. For domains with >10 majors (engineering, sciences), also show a "Top 10" button.

### Heatmap Rendering

Use CSS Grid with `<div>` elements. At 25x25 max (625 cells), DOM performance is fine and avoids canvas complexity. Each cell is a div with a background color and click handler.

**Viridis interpolation**: Map 0-100 values to the viridis colorscale. Include a JS viridis lookup table (256 RGB entries, ~2KB).

**Labels**: Abbreviated major names from the JSON `labels` field. Rotated 45deg for column headers. Truncate long names with ellipsis.

**Responsive sizing**: Heatmap cells sized to fill available width minus label space. On narrow phones (~375px), a 10x10 grid has ~28px cells (comfortable tap targets). For 25x25, cells shrink to ~11px — show values on tap rather than in-cell.

### Detail Panel

Appears as a fixed overlay anchored above the bottom drawer, triggered by cell tap. Tapping another cell updates it in place; tapping outside the heatmap or the detail panel's close button dismisses it. Shows:

1. **Pair names**: "Computer Science × Mechanical Engineering"
2. **Metric bars**: All 7 metrics as labeled horizontal bars (0-100 scale), with the currently-selected metric highlighted in orange
3. **Relationship classification label**: One of:
   - **Nested** — high overlap coefficient (>50%) with low jaccard (<30%), indicating one program's coursework is largely contained within another
   - **Parallel** — moderate jaccard (20-50%) with low TF-IDF cosine (<20%), indicating shared general base but divergent specializations
   - **Convergent** — high jaccard (>30%) AND high TF-IDF cosine (>20%), indicating shared general and specialized content
   - **Weak** — low values across all metrics (<20% jaccard, <15% overlap)
4. **Short explanation**: One-line description of what the classification means (e.g., "One program's courses are largely a subset of the other")

Classification thresholds are approximate and derived from the patterns described in the paper. The label appears with a subtle note: "Classification is approximate based on metric signatures."

### Bottom Drawer

Implemented as a fixed-position panel at the bottom of the viewport.

**States:**
- **Collapsed** (default): Shows just the metric chips and drawer handle. ~60px tall.
- **Expanded** (swipe up or tap handle): Shows metrics + major toggles + quick select. ~40% viewport height. Background dims slightly.

**Metric chips**: Horizontal scrolling row of pill buttons. Active chip: orange background, white text. Inactive: white background, gray border.

**Major toggles**: Wrapped grid of toggle chips. Active: purple background, white text, checkmark. Inactive: light gray, dark text.

### Styling

```
Colors:
  --clemson-orange: #F56600
  --clemson-purple: #522D80
  --bg: #fefefe
  --text: #2d3436
  --text-muted: #636e72
  --surface: #f8f8f8
  --border: #e0e0e0
  --detail-bg: #f8f4fc (light purple tint)

Typography:
  Font: system font stack (-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif)
  Header: 18px bold, purple
  Labels: 11-12px, muted
  Values: 12px, bold

Spacing:
  Content padding: 12px
  Cell gap: 2px
  Border radius: 4px (cells), 16px (pills), 10px (drawer top)
```

### Performance

- Total page weight: ~180KB (HTML/CSS/JS + 4 JSON files)
- No external dependencies — no CDN, no framework
- JSON files loaded on demand per domain (lazy load), or all upfront given the small size
- Canvas/grid rendering at 25x25 is trivial
- CSS transitions for metric switching (300ms ease)

### Accessibility

- Viridis heatmap: colorblind-safe by design
- Cell values accessible via tap (not color-dependent)
- Detail panel provides numeric values for all metrics
- Sufficient contrast ratios for all text on Clemson purple/orange backgrounds (white text on #522D80 passes WCAG AA)
- Semantic HTML: headings, buttons with labels, ARIA attributes on interactive elements

### Deployment

- GitHub Pages from a `docs/` folder on main branch (or a `gh-pages` branch)
- QR code points to `https://<username>.github.io/<repo>/`
- No build step — push HTML and JSON, done

## Out of Scope

- Cross-domain comparisons (selecting majors from multiple domains simultaneously)
- Browser-side metric computation (all matrices are pre-computed)
- User accounts, saving configurations, or sharing links
- Desktop-optimized layout (mobile-first, but CSS Grid will scale fine on desktop)
