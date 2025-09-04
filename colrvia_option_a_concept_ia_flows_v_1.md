# Colrvia — Option A (4‑tab Create‑First) — Concept, IA & Flows

## 0) Vision & Principles
**Vision:** Turn paint doubt into **Color Confidence** by streamlining the loop: **Design (Roller) → Plan (Color Plan) → Visualize (Visualizer)**, ending in a saved **Project**.

**Design Principles**
- Plain language; one‑tap to create, plan, visualize, save.
- Progressive disclosure: simple first; power when needed.
- Never stuck: every screen exposes **Make a Color Plan** and **Visualize**.
- Momentum > perfection: fast previews first; refine to high quality.
- Contextual AI (Via): helpful, constraint‑aware, never intrusive.
- Accessibility by default: LRV, contrast checks, color‑blind support.

---

## 1) Top‑Level IA (Option A + Adaptive Landing)
**Bottom nav:** **Create** · **Projects** · **Search** · **Account**

**Adaptive landing:**
- **First‑time / no projects →** land on **Create**.
- **Returning / ≥1 project →** land on **Projects** (Resume last).

**Global:** Floating **+ New Project**; compact **Via** bubble; contextual **Ask Via** chips.

---

## 2) Sitemap
- **Create (Hub)**
  - Hero CTA grid: **Guided Interview**, **Design with Roller**, **Visualize My Room**
  - **Recents**: last Palette · last Render · last Project
  - Tips (short cards): lighting, sampling, sheen
  - **Ask Via** chips (contextual prompts)
- **Projects**
  - Project List (cards) → **Project Overview**
    - Tabs/sections: **Palette** · **Color Plan** · **Visualizer** · **Rooms** · **History**
    - Always‑on actions: **Make a Color Plan**, **Visualize**, **Export**, **Share**
- **Search**
  - **Explore** (curated palettes, trending rooms)
  - Color DB (brand filters, undertone, LRV, similar, companions)
  - **Color Detail** → CTAs: **Add to Roller** · **Visualize with this color** · **Make a Color Plan**
  - **Compare** (side‑by‑side)
  - **Favorites** (feeds suggestions)
- **Account**
  - Profile, Purchases, Settings (Accessibility defaults, Preferred brands, Units), Legal

Support screens: Onboarding carousel, Permissions, Exports, Help/FAQ.

---

## 3) Object Model (Entities & Relationships)
- **User** ↔ has many **Projects**, **Favorites**, **Purchases**, **ViaSessions**
- **Project** (id, name, home/room tags, createdBy, updatedAt)
  - has one **Palette** (active) and many historical **Palettes**
  - has one **Color Plan** (latest) and versions
  - has many **Renders** (fast/HQ) and **Rooms**
  - has many **Assets** (photos, PDFs)
- **Palette** (colors[1..9], locks[], size, source: blank|seed|photo|interview|search, metadata: LRV, undertones, contrast pairs, brand refs, tags)
- **Color Plan** (vibe/name, placement map, finishes/sheen, accent rules, cohesion tips, do/don’t, sample sequence, room‑by‑room playbook)
- **Room** (name/type; surfaces: wall/trim/ceiling/door/cabinet; lighting profile; fixed elements)
- **Render** (projectId, photoId, maskId, paletteId, quality: fast|HQ, before/after refs)
- **Color** (brand, code, name, HEX, LRV, notes, similar[], companions[])
- **Favorite** (User ↔ Color/Palette/Plan/Render)
- **Asset** (photo, export PDF/PNG)
- **Mask** (segmentation by surface)
- **ViaSession** (context pointers + transcript)

---

## 4) Key Feature Specs

### 4.1 Roller (DIY Palette Designer)
- Start from **Blank**, **Seed color**, **Photo**, or **Suggestions**.
- Palette size selector (1–9). **Lock** any swatch. Quick actions: **swap**, **duplicate**, **favorite**, **send → Visualizer / Color Plan / Compare**.
- **Variants:** Softer / Brighter / Moodier / Warmer / Cooler (one‑tap versions + History).
- Harmony logic runs under the hood (roles implicit; UI keeps “size” simple).
- Inline metrics: LRV, basic contrast, undertone chips; **color‑blind safe** tag when applicable.

### 4.2 Color Plan (AI Palette Guide)
- Output blocks: name & vibe, placement map (walls/trim/ceiling/doors/cabinets), finishes & sheen, accent rules, cohesion tips, do/don’t, sample sequencing, room‑by‑room playbook.
- **Painter Pack export**: Brand SKUs, sheen list, printable swatch cards (3), sampling checklist.
- Via actions: “Explain this choice”, “Simplify for beginners”, “Budget variant”.

### 4.3 Visualizer (AI Image Render)
- **Fast → HQ** pipeline: immediate preview (approx masks) → queued HQ (refined masks).
- Surface chips (Walls/Trim/Ceiling/Doors/Cabinets), Before/After toggle, A/B (two palettes).
- **No photo yet?** Offer **Sample Rooms** with typical lighting & materials.
- Basic masking tools (brush/eraser) + **Quick Mask Assist**.

### 4.4 Search (Color Database + Explore)
- Color detail: LRV, undertone, HEX, similar/companions, brand/collection.
- Deep links: **Add to Roller**, **Visualize with this color**, **Make a Color Plan**.
- Compare 2–4 colors; show contrast deltas and LRV spacing. Favorite from here.
- **Explore** shelf: curated palettes & rooms (editorial + algorithmic).

### 4.5 Via (AI Assistant, contextual)
- Appears as inline chips and a small bubble. Understands project context & constraints.
- **Design Guardrails:** keep cabinets existing, north light bias, kid‑friendly finishes, translate SW ↔ Behr, avoid clash with fixed elements.
- Can trigger: suggest/refine palette, generate Color Plan, start Visualizer, queue HQ render, export Painter Pack.

---

## 5) Gap‑Bridging Enhancements (lightweight, high impact)
- **Lighting Profiles:** ask on first photo (north/south; bulb warm/neutral/cool). Used to bias Visualizer and add Plan notes.
- **Fixed‑Element Assist:** capture floors/counters/tile via photo or swatch; infer undertones; set “avoid clash” constraints for Roller/Plan.
- **House Flow / Adjacency Check:** in Projects → Rooms, show cohesion score; suggest LRV spacing and temperature balance across rooms.
- **One‑tap Variants** (Roller) and **Compare Everywhere** (Visualizer A/B, History side‑by‑side, Search compare).

---

## 6) Onboarding & Permissions
**3‑screen intro carousel**
1. **Color, made simple.**
   *Turn paint doubt into Color Confidence—in minutes.*
2. **Design. Plan. Visualize.**
   *Build a palette, get a step‑by‑step Color Plan, and see it on your walls.*
3. **Start your way.**
   *Guided Interview, DIY with Roller, or visualize your room first.*

**One‑tap start buttons:** **Guided Interview** · **Design with Roller** · **Visualize My Room**

**Permissions microcopy (Photos/Storage):**
> Colrvia needs access to your photos to preview colors on your walls. We only use images you choose.

---

## 7) Core User Flows (with saves, empty & recovery states)

### a) Guided Flow
```
Create → Guided Interview
  → AI proposes Palette (auto‑save draft)
  → CTA: Make a Color Plan → Plan (auto‑save)
  → CTA: Visualize → Upload or Sample Room → Fast preview
  → CTA: Save Project (name) → Project Overview
```
**Recovery:** If plan fails → Retry / Ask Via. If no photo → provide Sample Rooms.

### b) DIY Flow (Roller‑first)
```
Create → Roller (Blank | Seed | Photo | Suggestions)
  → Locks/size 1–9 → Iterate (auto‑save palette)
  → CTA: Make a Color Plan → Plan (save)
  → CTA: Visualize → Fast preview → Save Project
```
**Recovery:** No palette yet → 3‑color starter + “Roll ideas”. Undo/History always.

### c) Visual‑first Flow
```
Create → Visualizer → Upload photo
  → Prompt: Suggest palette for this room? → Palette
  → CTA: Refine in Roller → tweak
  → CTA: Make a Color Plan → Save Project
```
**Recovery:** Poor masks → Quick Mask Assist; or use Sample Rooms.

### d) Search‑first Flow
```
Search → Color Detail (LRV/undertone/similar)
  → CTA: Add to Roller | Visualize with this color | Make a Color Plan
  → Follow chosen path → Save Project
```
**Save points (all flows):** auto‑save drafts; explicit **Save Project** names it and pins to list. “Resume last” banner on return.

---

## 8) Screen‑by‑Screen Outline

### Create (Hub)
- Hero with 3 big CTAs.
- Recents row (Palette, Render, Project).
- Ask Via chips.
- Tips carousel.

### Project List
- Cards with thumbnail (latest render), palette strip, last updated.
- Quick actions: Resume, Share, Export.

### Project Overview
- **Palette** card → Edit in Roller; metrics (LRV range, contrast pairs).
- **Color Plan** card → open/export; “Explain choices” (Via).
- **Visualizer** card → latest render + “New render”.
- **Rooms** list → add/manage; show Adjacency Check.
- **History** → versions & A/B compare.

### Roller
- Swatch rail (1–9) with lock toggles; add/replace via search or suggestions.
- Variants row (Softer/Brighter/Moodier/Warmer/Cooler).
- Metrics (LRV, contrast hints), Favorites, Compare.
- CTAs: **Make a Color Plan**, **Visualize**.

### Color Plan
- Sections as in §4.2; export **Painter Pack** (PDF/PNG).
- Via panel with clarifying/simplify actions.

### Visualizer
- Photo picker; Sample Rooms if none.
- Surface chips; Before/After; A/B palettes.
- Fast preview status; Queue **HQ render** with progress.
- Save Render; **Back to Project**.

### Search
- Explore shelf; Brand filters; Color Detail; Compare; Favorites.

### Account & Settings
- Accessibility defaults, Preferred brands, Units; Purchases; Legal.

---

## 9) Navigation & Interactions
- Floating **+ New Project** (global).
- Palette chip interactions: **tap=lock/unlock**, **long‑press=swap/duplicate**; overflow: **Visualize**, **Make Color Plan**, **Compare**, **Favorite**.
- Via chips appear under headers and next to critical CTAs (e.g., after first palette: “Make a Color Plan”).
- Toasts & celebrations: confetti tick on Color Plan completion; “Saved to Project” toast with **View Project**.

---

## 10) Accessibility & Quality Bar
- **Contrast checks** for common pairs (walls vs trim) with WCAG guidance.
- **LRV visible** on swatches; warn on extreme low‑light combos based on Lighting Profile.
- **Color‑blind safe** tags; one‑tap “Generate CB‑friendly variant.”
- **Performance targets:** Fast preview < 5s typical; HQ render targeted < 60s (async), progress with ability to keep working.

---

## 11) Empty, Error & Recovery States
- **No photo:** Sample Rooms + “Add photo” CTA.
- **No palette:** Starter 3‑color palette + “Roll ideas”.
- **Plan generation error:** Retry; “Ask Via to simplify”; fall back to minimal Plan.
- **Render queued/fails:** Show queue position; easy retry; keep working.

---

## 12) Analytics & Success Criteria
**Guiding KPIs**
- Time to first Color Plan (TTFCP) < **4 min**.
- % reaching first fast preview on day 0 > **60%**.
- Save‑as‑Project rate in first session > **45%**.
- Return within 7 days to run HQ render > **25%**.

**Event map (core):** onboarding_viewed, start_guided, start_roller, start_visualizer, palette_created, plan_generated, render_fast, render_hq, project_saved, via_invoked, compare_used, variant_generated.

---

## 13) Terminology (standardized)
- **Project**: named container for palette, Color Plan, renders, rooms, assets.
- **Color Plan**: the actionable guide (formerly “Story”).
- **Palette**: 1–9 ordered colors (roles implicit).
- **Render**: visualized image (fast/HQ).
- **Visualize**: verb for creating renders.
- **Compare**: side‑by‑side palettes/colors/renders.
- **Favorite**: save for reuse; seeds Roller & Plan suggestions.

---

## 14) Interaction Map (Handoffs)
- Roller → **Color Plan** (Make a Color Plan)
- Roller → **Visualizer** (Preview on my photo / Sample Room)
- Visualizer → **Roller** (Refine this palette)
- Visualizer → **Color Plan** (Plan this palette)
- Search (Color Detail) → **Roller / Visualizer / Color Plan**
- Via anywhere → Suggest/Refine palette, Explain sheen, Queue HQ, Export Pack
- Project Overview → Jump to any spine tool with current context

---

## 15) Release Plan (MVP++)
**Now**: Option A IA + adaptive landing; Guided Interview; Roller (locks, variants); Visualizer fast→HQ; Color Plan + Painter Pack; Lighting Profiles; Fixed‑Element Assist; Sample Rooms; Compare; Accessibility.[text](colrvia_option_a_concept_ia_flows_v_1.md)

**Later**: Room adjacency visualization; quantity estimator; collaboration (comments/polls); AR live preview.

---

## 16) Acceptance Checklist
- Roller, Color Plan, Visualizer are the **core loop** and one‑tap reachable from every screen.
- Each flow ends with a **saved Project** and a clear next step.
- Via is constraint‑aware and contextual; onboarding is friction‑light; names are intuitive.

