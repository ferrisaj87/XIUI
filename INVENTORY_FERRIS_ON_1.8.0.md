# Ferris Changes On Top Of XIUI 1.8.0 — Comprehensive Inventory

_Generated: 2026-05-23. Source of truth for the new pr/* slice authoring._

---

## Methodology

**Primary sources (read cover-to-cover):**
- `MIGRATION_1.8.0_PLAN.md` — 1323-line migration plan/audit doc maintained throughout the 1.8.0 forward-port. Primary spine for architectural decisions, audit findings, migrated/deferred/new features (D.1–D.16).
- `scripts/feature-pr-manifest.ps1` — old 25-slice manifest built against 1.7.5. Body/Subject fields provide high-quality "what/why" prose for historical features.
- `scripts/PUSH_INSTRUCTIONS.md` — workflow model for slice assembly and push (context only).

**File-level delta (authoritative vs git status):**
- Local `master` is at 1.7.5 era; working tree reflects 1.8.0 baseline + uncommitted Ferris re-integration.
- Recursive comparison: `XIUI/` (live working tree) vs `XIUI1.8.0/` (pristine upstream baseline).
- Method: `Get-ChildItem -Recurse -File` on both trees → relative-path sets → set difference for added/deleted; `Get-FileHash -MD5` on common paths for modified.
- Ignored: `.git/`, `scripts/`, `.cursor/`, `MIGRATION_1.8.0_PLAN.md`, `.gitignore`, `.git-tmp-hb-180.txt`.
- Each feature verified against live tree paths (not plan references alone).

**Caveats:**
- Git status shows many "deleted" assets (item PNGs, ClassicFFXIV job icons, slot-type badges) that were in the 1.7.5-era git commit but **never existed in 1.8.0**. These are NOT Ferris deletions from the 1.8.0 baseline — they are un-forward-ported 1.7.5 assets.
- Hash comparison found **0 files deleted from 1.8.0** by Ferris; all 4920 baseline files remain present (some modified).
- Asset deletions are aggregated, not enumerated per-PNG.
- Section **12.6** below was reconstructed by the parent agent from surviving trailing bullets (recommended slice + open question) when the subagent's emission truncated the header. Content represents the non-blocking profile modal port from old pr/20; verify against `config.lua` diff if exact wording matters.

---

## Summary Stats

| Metric | Count |
|---|---|
| Total distinct features inventoried | **~55** (25 survived old slices + ~18 migration-new + ~12 sub-features/groupings) |
| Old 25-slice features **SURVIVED** | **25 / 25** |
| Old 25-slice features **OBSOLETED** by 1.8.0 | **0** |
| Old 25-slice features **REWORKED** for 1.8.0 architecture | **~15** (GDI → imtext, perf rewrites, deferred texture release) |
| **NEW** features added during migration (not in old manifest) | **~18** |
| Lua source files **modified** vs pristine 1.8.0 | **43** |
| Files **added** by Ferris (all types, excl. scripts/.cursor/MIGRATION doc) | **52** |
| — of which: new Lua source files | **22** |
| — of which: custom item icon PNGs | **25** |
| — of which: UI status assets | **2** (`checkmark.png`, `x.png`) |
| — of which: tooling/docs (excluded from feature count) | **3** (`.gitignore`, `.git-tmp-hb-180.txt`, `.cursor/` rules) |
| Files **deleted** from 1.8.0 baseline by Ferris | **0** |
| 1.7.5-era assets NOT forward-ported (aggregate) | ~39 item PNGs, 8 slot-type badge PNGs, 28 ClassicFFXIV job icon PNGs |

**43 modified Lua files:**
`XIUI.lua`, `config.lua`, `config/castbar.lua`, `config/components.lua`, `config/hotbar.lua`, `config/notifications.lua`, `config/palettemanager.lua`, `core/gamestate.lua`, `core/settings/factories.lua`, `core/settings/migration.lua`, `core/settings/user.lua`, `handlers/actiontracker.lua`, `handlers/debuffhandler.lua`, `handlers/helpers.lua`, `handlers/imgui_compat.lua`, `handlers/petbuffhandler.lua`, `handlers/statushandler.lua`, `libs/dragdrop.lua`, `libs/drawing.lua`, `libs/target.lua`, `libs/texturemanager.lua`, `modules/castcost/display.lua`, `modules/hotbar/actiondb.lua`, `modules/hotbar/actions.lua`, `modules/hotbar/controller.lua`, `modules/hotbar/crossbar.lua`, `modules/hotbar/data.lua`, `modules/hotbar/database/horizonspells.lua`, `modules/hotbar/display.lua`, `modules/hotbar/init.lua`, `modules/hotbar/macropalette.lua`, `modules/hotbar/palette.lua`, `modules/hotbar/petpalette.lua`, `modules/hotbar/petregistry.lua`, `modules/hotbar/playerdata.lua`, `modules/hotbar/recast.lua`, `modules/hotbar/skillchain.lua`, `modules/hotbar/slotrenderer.lua`, `modules/hotbar/textures.lua`, `modules/partylist/display.lua`, `modules/petbar/data.lua`, `modules/petbar/display.lua`, `modules/petbar/pettarget.lua`

**22 new Lua files:**
`config/crossbar.lua`, `config/crossbar_settings.lua`, `config/efp_pets_tab.lua`, `core/shared_macro_store.lua`, `libs/json.lua`, `modules/hotbar/customiconresolve.lua`, `modules/hotbar/database/horizon_abilities.lua`, `modules/hotbar/database/horizon_bloodpacts.lua`, `modules/hotbar/database/horizon_bloodpacts_xiui.lua`, `modules/hotbar/database/horizon_retail_only_job_abilities.lua`, `modules/hotbar/database/horizon_spell_omissions.lua`, `modules/hotbar/database/ws_weapon_types.lua`, `modules/hotbar/equipment_ws.lua`, `modules/hotbar/iconmatch.lua`, `modules/hotbar/macro_global_defaults.lua`, `modules/hotbar/macro_palette_buckets.lua`, `modules/hotbar/macro_xiui_defaults.lua`, `modules/hotbar/macropalette_macroeditor.lua`, `modules/hotbar/macroparse.lua`, `modules/hotbar/palette_json.lua`, `modules/hotbar/pet_palette_allowlist.lua`, `modules/hotbar/universal_two_hour.lua`

---

## Features by Group

---

### Group 0: New Features Added During Migration (not in old 25-slice manifest)

---

#### 0.1 Magic Burst Highlight [NEW]

- **What:** When a skillchain fires on the player's target, highlight any spell, magical Blood Pact Rage, or `/ma`-/`/pet`-primary macro slot whose element matches the SC's burstable elements, for the full 7-second MB window. Cyan-blue dashed marching-ants border with SC-name icon in the bottom-left corner (distinct from gold skillchain top-right). Curated SMN blood pact element map covers BLM-shadow magic pacts only; physical pacts and named flavor rages deliberately excluded.
- **Why:** Gives players an at-a-glance MB opportunity cue without manually tracking SC results. Parallel to the existing skillchain highlight system.
- **Files:**
  - `modules/hotbar/skillchain.lua` [modified] — `magicBurstMap`, `magicBurstElements`, `bloodPactElementMap`, `HandleActionPacket` MB branches, public API: `GetBurstElementForSlot`, `GetMagicBurstForElement`, `GetMagicBurstForSlot`, `GetMagicBurstWindow`
  - `modules/hotbar/slotrenderer.lua` [modified] — `DrawMagicBurstHighlight()`, `params.magicBurstName` branch in DrawSlot
  - `modules/hotbar/display.lua` [modified] — per-slot `GetMagicBurstForSlot` dispatch, `magicBurstEnabled` gate
  - `modules/hotbar/crossbar.lua` [modified] — same dispatch through all render branches; suppressed in editor preview
  - `core/settings/factories.lua` [modified] — `hotbarGlobal.magicBurstHighlightEnabled`, `magicBurstHighlightColor`
  - `config/hotbar.lua` [modified] — Magic Burst checkbox + color picker in `DrawSharedSkillchainHighlightControls`
- **Depends on:** 8.1 (skillchain module), 0.3 (crossbar SMN routing), 7.1 (playerdata for availability)
- **1.8.0 architectural notes:** Pure new feature on imtext/drawList path. Separate state map from `resonationMap` (different lifetimes). Reuses `skillchainIconScale/OffsetX/OffsetY` from `hotbarGlobal`.
- **Recommended slice:** `pr/08-magic-burst-highlight`
- **Open questions:** None — design locked per D.16 in migration plan.

---

#### 0.2 Deferred Texture Release (Palette Delete CTD Fix) [NEW]

- **What:** Routes icon-cache clears through `TextureManager.DeferRelease()` so D3D COM texture handles aren't freed while still queued for `AddImage` in the same frame. Prevents `EXCEPTION_ACCESS_VIOLATION` CTD on palette deletion, profile switch, or mid-frame cache wipe.
- **Why:** Reproducible game crash when deleting an actively-selected palette. 1.8.0's `FlushPendingReleases` existed in `texturemanager.lua` but slotrenderer/display/crossbar local caches bypassed it.
- **Files:**
  - `libs/texturemanager.lua` [modified] — `M.DeferRelease(value)` public API
  - `modules/hotbar/slotrenderer.lua` [modified] — `ClearAllCache`, `ClearSlotRenderingCache` defer texture ptr table
  - `modules/hotbar/display.lua` [modified] — `ClearIconCache`, `ClearIconCacheForSlot` deferred
  - `modules/hotbar/crossbar.lua` [modified] — `ClearCrossbarIconCache`, `ClearCrossbarIconCacheForSlot` deferred
- **Depends on:** None (foundational safety)
- **1.8.0 architectural notes:** Extends 1.8.0's existing `pendingReleases` / `FlushPendingReleases` pattern (called at top of every `d3d_present`). Must land before any PR touching slotrenderer/display/crossbar cache paths.
- **Recommended slice:** fold into `pr/02-foundational-compat`
- **Open questions:** None.

---

#### 0.3 SMN Skillchain Prediction in Crossbar [NEW connection / parity fix]

- **What:** `crossbar.lua` now routes `actionType == 'pet'` and `/pet`-primary macros through `skillchain.GetSkillchainForBloodPact`, matching `display.lua` behavior. Previously crossbar only showed skillchain icons for `actionType == 'ws'`.
- **Why:** SMN blood pact slots on the crossbar never showed skillchain icons despite keyboard hotbar doing so.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified] — pet/macro skillchain dispatch in DrawLeftSide/DrawRightSide
  - `modules/hotbar/macroparse.lua` [new] — macro-primary resolution
  - `modules/hotbar/skillchain.lua` [modified] — `GetSkillchainForBloodPact` (existing)
- **Depends on:** 5.1 (blood pact data), 8.1 (skillchain module)
- **1.8.0 architectural notes:** No new rendering API; uses existing `params.skillchainName` on imtext DrawSlot path.
- **Recommended slice:** fold into `pr/14-crossbar-core` or `pr/05-smn-actions-bloodpacts`
- **Open questions:** None.

---

#### 0.4 L1 Shoulder Button Latching Fix [NEW fix]

- **What:** In `controller.lua`, shoulder-held latch state (`lbHeld`/`rbHeld`) is set-only from poll (never cleared by poll — cleared exclusively by `HandleXInputButton` release events). Fixes L1 palette cycling silently failing when FFXI consumes the L1 xinput bit before Ashita's snapshot.
- **Why:** Users reported L1 cycle broken while R1 worked.
- **Files:**
  - `modules/hotbar/controller.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Side effect: R1-edge scope toggle and R1 cpal-anchor double-tap also become more reliable under the same scenario.
- **Recommended slice:** fold into `pr/15-crossbar-cpal-r1-return`
- **Open questions:** None.

---

#### 0.5 Unavailable Ability Visual Feedback — Lv## Badge + Pet/Macro Coverage [RESTORED + ENHANCED]

- **What:** Restores and extends grayed-out / `Lv65` / `X` visual feedback for unavailable actions on the 1.8.0 imtext path. Covers `ma`, `ja`, `ws`, `pet`, and `macro` action types. Cache key includes effective post-sync levels. `unavailableReason` parsed once at cache-insert as `displayText`. Size-bounded caches (8192 availability, 4096 MP cost).
- **Why:** 1.8.0 base only showed plain `X` for `{ma,ja,ws}`. Ferris pr/07 had richer coverage; this restores it for imtext.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified] — allowlist expanded, `displayText` pre-parse, bounded cache helpers, `GetFrameAvailability` snapshot
  - `modules/hotbar/actions.lua` [modified] — `IsActionAvailable` reads party effective levels
  - `handlers/statushandler.lua` [modified] — Level Sync transition clears availability cache
- **Depends on:** None beyond slotrenderer
- **1.8.0 architectural notes:** Uses imtext corner text rendering; no GDI font objects. Cache key shape changed — invalidates on level sync without requiring explicit buff transition.
- **Recommended slice:** fold into `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 0.6 Frame-Level Availability Snapshot [NEW perf]

- **What:** `GetFrameAvailability()` in `slotrenderer.lua` snapshots `(jobId, subjobId, mainLevel, subLevel, partyMain, partySub)` once per frame, invalidated by `M.BeginFrame`. DrawSlot and DrawTooltip route through snapshot instead of per-slot `GetMemoryManager()` calls.
- **Why:** Was ~7 FFI getters × 16–32 slots × 60 fps; now constant regardless of slot count.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Complements 1.8.0's reusable `slotParams`/`slotInteraction` table pattern in display.lua.
- **Recommended slice:** fold into `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 0.7 Crossbar PlayerData Cache Warm for Crossbar-Only Setups [NEW fix]

- **What:** `crossbar.lua` calls `playerdata.RefreshCachedLists(data)` at top of `M.DrawWindow`. Without this, crossbar-only setups (`hotbarEnabled=false, crossbarEnabled=true`) never warm ability/WS caches → every JA/WS slot reads unavailable.
- **Why:** Bug discovered in D.14 performance audit.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified]
  - `modules/hotbar/playerdata.lua` [modified] — `RefreshCachedLists` (existing)
- **Depends on:** 7.1 (playerdata Show All infrastructure)
- **1.8.0 architectural notes:** Refresh is signature-gated internally; steady-state cost is one signature compare.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 0.8 Effective Level in `IsActionAvailable` [NEW fix]

- **What:** `actions.IsActionAvailable` reads `party:GetMemberMainJobLevel(0)` / `GetMemberSubJobLevel(0)` (post-Level-Sync effective levels) instead of raw `player:GetMainJobLevel()`.
- **Why:** Synced-down player could see too-high-level spells as available because check used raw character level.
- **Files:**
  - `modules/hotbar/actions.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Matches equipment_ws.lua's two-source level approach.
- **Recommended slice:** fold into `pr/06-playerdata-show-all`
- **Open questions:** None.

---

#### 0.9 Crossbar Visual Cutoff Fix — Top/Bottom Decoration Pad [NEW fix]

- **What:** Crossbar ImGui window opens `CROSSBAR_WINDOW_TOP_DECOR_PAD = 80` px higher and `(topPad + bottomPad)` taller than slot grid. `ApplyCrossbarWindowPositionOnce()` and `SaveCrossbarWindowSlotTopPosition()` persist slot-grid top Y (not window top). Profile-compat: existing saved Y preserved on first load under new code.
- **Why:** L2/R2 trigger icons, R1 pulse, palette name, action labels, combo text were rendering outside ImGui content rect and clipped.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified] — `CROSSBAR_WINDOW_TOP_DECOR_PAD`, `GetCrossbarWindowBottomPad`, position save/restore helpers
- **Depends on:** None
- **1.8.0 architectural notes:** `state.windowY` continues to mean slot-grid top everywhere; window position math adjusted around it.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 0.10 Crossbar Label-Above-Slot on Live HUD [NEW fix]

- **What:** Non-editor live-HUD label path in `slotrenderer.lua` now respects `params.labelAboveSlot`. Crossbar passes `labelAboveSlot = (posIndex == 1)` for top diamond slot.
- **Why:** Top-slot labels rendered below, overlapping bottom-slot MP cost / quantity text.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified]
  - `modules/hotbar/crossbar.lua` [modified] — passes `labelAboveSlot` flag
- **Depends on:** None
- **1.8.0 architectural notes:** Uses `imtext.Measure` for label height; keyboard hotbars pass false → no behavior change.
- **Recommended slice:** fold into `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 0.11 Double-Click Empty Slot → New Macro in Edit Full Palette [NEW]

- **What:** Manual double-click tracker in `slotrenderer.lua` (`lastClickButtonId`, `lastClickTime`, `DOUBLE_CLICK_INTERVAL = 0.35s`). Editor slots pass `onDoubleClick` (seeds fresh macro from active palette defaults) and `suppressActionOnClick`. `palettemanager.lua` consumes pending edit next frame via `data.SetPendingPaletteSlotEdit`.
- **Why:** Double-clicking empty EFP slot previously had no effect.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified] — double-click tracker, 4-branch click dispatcher
  - `modules/hotbar/crossbar.lua` [modified] — `onDoubleClick` closure in editor interaction cache
  - `config/palettemanager.lua` [modified] — consumes pending edit
  - `modules/hotbar/data.lua` [modified] — `SetPendingPaletteSlotEdit` (existing)
- **Depends on:** 2.2 (Edit Full Palette)
- **1.8.0 architectural notes:** Uses `ignoreCancelledMicroDrag` to suppress drag guard on editor slots. Avoids opening modal inside hotbar draw pass.
- **Recommended slice:** fold into `pr/18-crossbar-edit-palette-draft`
- **Open questions:** None.

---

#### 0.12 "Disable Crossbar While In Menu" Visual Dim [NEW fix — dim was missing from pr/19]

- **What:** `visibilityOpacity *= 0.35` in `crossbar.lua` when `gamestate.IsMenuOpen() and settings.crossbarDisableInMenu`. Previously controller blocked input but crossbar rendered at full opacity.
- **Why:** No visual cue that input was blocked.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified] — `local gamestate = require('core.gamestate')`
  - `core/gamestate.lua` [modified] — `IsMenuOpen()` (existing from pr/19)
  - `modules/hotbar/controller.lua` [modified] — input block (existing from pr/19)
- **Depends on:** 2.3 (crossbar game menu block)
- **1.8.0 architectural notes:** Multiplier propagates via existing `animOpacity` param through all slot/background/trigger alpha scales.
- **Recommended slice:** fold into `pr/16-crossbar-game-menu-block`
- **Open questions:** None.

---

#### 0.13 "Classic FFXIV" Theme Removed from Global Visual Settings Dropdown [NEW fix]

- **What:** Removed `'ClassicFFXIV'` from `paletteIconThemes` array. Narrowed three allowlist guards. One-shot migration: profiles with `paletteJobIconTheme == 'ClassicFFXIV'` fall back to `'Classic'` on first open.
- **Why:** `ClassicFFXIV` folder is user-custom; shouldn't ship in public dropdown.
- **Files:**
  - `config/crossbar_settings.lua` [new]
  - `config/palettemanager.lua` [modified] — `GetCrossbarPaletteJobIconTheme` allowlist
  - `modules/hotbar/crossbar.lua` [modified] — `GetPaletteJobIconThemeFromSettings` allowlist
  - `core/settings/factories.lua` [modified] — factory comment updated
- **Depends on:** None
- **1.8.0 architectural notes:** Graceful fallback on read; no migration.lua entry needed (one-shot on UI open).
- **Recommended slice:** fold into `pr/19-crossbar-settings`
- **Open questions:** Should the 28 ClassicFFXIV PNG files be deleted from git history or left as untracked local-only?

---

#### 0.14 Crossbar Palette Count Hides `(1/1)` Noise [NEW fix]

- **What:** `DrawPaletteName` routes through `palette.GetCrossbarPaletteLabelIndexAndTotal(...)`. Only renders `(idx/total)` suffix when `total > 1`.
- **Why:** Always showed `(1/1)` even with one enabled palette.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified]
  - `modules/hotbar/palette.lua` [modified] — `GetCrossbarPaletteLabelIndexAndTotal`
- **Depends on:** 2.1 (crossbar palette management)
- **1.8.0 architectural notes:** Universal vs job scope split handled inside palette.lua helper.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 0.15 Deferred Drop Priority / Overlapping Zone Resolution [NEW — described in pr/16 body]

- **What:** `dragdrop.lua` gains `deferredDropCandidates`, `FlushDeferredDrops()` with `dropPriority` + registration-order tiebreaker. EFP preview uses `dropPriority = 10` to win over live crossbar zone. `slotrenderer` passes `params.dropPriority` into `dragdrop.DropZone`.
- **Why:** Edit Full Palette preview overlaps live crossbar HUD; first-registered zone was winning incorrectly.
- **Files:**
  - `libs/dragdrop.lua` [modified]
  - `modules/hotbar/slotrenderer.lua` [modified]
  - `modules/hotbar/init.lua` [modified] — `M.FinalizeFrame()` calls `FlushDeferredDrops`
  - `XIUI.lua` [modified] — `hotbar.FinalizeFrame()` after palette manager draw
- **Depends on:** None
- **1.8.0 architectural notes:** 1.8.0 simplified dragdrop (removed inline tooltip rendering); Ferris overlap handling layered on top.
- **Recommended slice:** fold into `pr/18-crossbar-edit-palette-draft`
- **Open questions:** None.

---

#### 0.16 Performance Audit Wins [NEW — quality audit pass]

- **What:** Six hot-path scan collapses + deduplication applied during migration quality audit:
  - `actions.lua`: `spellsByLowerNameLookup` lazy multimap; `noIconCache` extended key; `LoadItemIconByName` via `actiondb.GetItemId`
  - `playerdata.lua`: `GetExpandedAbilities` via `actiondb.GetAbilityId`; `playerHasLearnedNonWsAbilityByName` O(1); WS scans via `actiondb.GetWeaponSkillAbilityIds()`
  - `actiondb.lua`: new `GetWeaponSkillAbilityIds()` lazy list
  - `slotrenderer.lua`: deduped color helpers (aliases to `colorlib`); `MakePreviewSettings` cached on geometry signature; preview early-exit when `baseOp <= 0.02`
  - `crossbar.lua`: `MakePreviewSettings` caching; double-tap preview early-exit
- **Why:** Prevent perf regressions after layering Ferris features on 1.8.0 base.
- **Files:**
  - `modules/hotbar/actions.lua` [modified]
  - `modules/hotbar/playerdata.lua` [modified]
  - `modules/hotbar/actiondb.lua` [modified]
  - `modules/hotbar/slotrenderer.lua` [modified]
  - `modules/hotbar/crossbar.lua` [modified]
  - `modules/hotbar/display.lua` [modified] — `ClearNoIconCache` hook
- **Depends on:** 6.1 (horizon databases for playerdata context)
- **1.8.0 architectural notes:** Reuses 1.8.0's `spellByNameLookup` / `noIconCache` patterns; extends rather than replaces.
- **Recommended slice:** distribute into parent module slices (actiondb → `pr/06-playerdata-show-all`; actions → `pr/05-smn-actions-bloodpacts`; slotrenderer → `pr/07-slotrenderer-uth-skillchain`)
- **Open questions:** `actiondb.lua` modifications not given dedicated plan section — confirm ownership slice.

---

#### 0.17 AlwaysClamp Policy Applied to Sliders [NEW fix]

- **What:** `ImGuiSliderFlags_AlwaysClamp` added to Rows/Columns sliders (`config/hotbar.lua`), cast-bar Fast Cast sliders (`config/castbar.lua`), and notification group sliders (`config/notifications.lua`).
- **Why:** 1.8.0 stated policy (throughout `config/components.lua`) requires AlwaysClamp on every slider. These were inconsistencies in both branches.
- **Files:**
  - `config/hotbar.lua` [modified]
  - `config/castbar.lua` [modified]
  - `config/notifications.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Brings Ferris-touched config files into compliance with 1.8.0 slider policy.
- **Recommended slice:** fold into respective config slices
- **Open questions:** None.

---

#### 0.18 Palette Scope Icon Above Divider [PORTED from Ferris, deferred Pass 2]

- **What:** `GetInfinityPaletteIconTexture` (lazy session-cached infinity texture), `GetPaletteJobIconThemeFromSettings`, `ShouldShowPaletteScopeIcon`, `DrawPaletteScopeIconAboveDivider` (drawList AddImage). Gated by `showCenterElements`.
- **Why:** Visual cue for Global vs Job palette scope above crossbar divider.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified]
  - `libs/texturemanager.lua` [modified] — texture load for job icons
- **Depends on:** 2.1 (palette scope system)
- **1.8.0 architectural notes:** Pure drawList AddImage; no persistent primitives.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

### Group 1: Foundational Infrastructure

---

#### 1.1 Independent Hotbar / Crossbar Enable Toggles [SURVIVED from pr/13]

- **What:** `gConfig.hotbarEnabled` and `gConfig.crossbarEnabled` are separate gates. Packet handlers (0x0068 pet sync, 0x0028 skillchain, 0x00A zone-in, 0x00B zone-out, 0x001B job change) fire when either is enabled. `init.lua` draws keyboard bars and crossbar independently.
- **Why:** Crossbar-only setups need palette/pet/skillchain updates without enabling keyboard hotbars.
- **Files:**
  - `XIUI.lua` [modified] — `or gConfig.crossbarEnabled` checks in 4 packet handlers
  - `modules/hotbar/init.lua` [modified] — independent `showHotbar` / `showCrossbar` draw paths
  - `core/settings/user.lua` [modified] — `crossbarEnabled` key
- **Depends on:** None
- **1.8.0 architectural notes:** 1.8.0 gates crossbar via `hotbarCrossbar` settings table; Ferris adds separate top-level flag. Both coexist.
- **Recommended slice:** `pr/02-foundational-compat`
- **Open questions:** None.

---

#### 1.2 Independent Movement Lock [SURVIVED from pr/03/pr/16, bug-fixed in smoke-test]

- **What:** `gConfig.hotbarLockMovement` vs `gConfig.crossbarLockMovement`. `IsMovementLockedForDropZone(id)` routes `crossbar_*` → crossbar lock, `paled*` → always unlocked, rest → hotbar lock. Right-click clear and move anchor both corrected.
- **Why:** Lock Crossbar toggle was incorrectly reading `hotbarLockMovement`.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified] — `IsMovementLockedForDropZone`
  - `modules/hotbar/crossbar.lua` [modified] — move anchor reads `crossbarLockMovement`
  - `config/crossbar.lua` [new] — Lock Crossbar toggle UI
- **Depends on:** None
- **1.8.0 architectural notes:** Per-zone policy replaces 1.8.0's single lock check.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 1.3 Independent Hide-On-Menu-Focus [SURVIVED, foundational — intentional drop of central key]

- **What:** `gConfig.hotbarHideOnMenuFocus` (keyboard bars) vs `gConfig.hotbarCrossbar.crossbarHideOnMenuFocus` (crossbar). XIUI.lua hotbar Register block intentionally lacks `hideOnMenuFocusKey`. Branching inside `init.lua:381–392`.
- **Why:** Central moduleregistry key would collapse both halves into single shared toggle, defeating Ferris's per-bar-type split.
- **Files:**
  - `XIUI.lua` [modified] — `hideOnMenuFocusKey` removed from hotbar registration
  - `modules/hotbar/init.lua` [modified] — per-bar-type menu-hide branching
- **Depends on:** None
- **1.8.0 architectural notes:** 1.8.0 kept the central key; Ferris intentionally dropped it. **Must not be restored.**
- **Recommended slice:** `pr/02-foundational-compat`
- **Open questions:** None.

---

#### 1.4 SharedMacroStore-Aware Save Path [SURVIVED from pr/14]

- **What:** `SaveCurrentProfileFileToDisk()` swaps frozen `macroDB` snapshot, saves profile, persists live shared library to `SharedMacros.lua`. Replaces 4 direct `profileManager.SaveProfileSettings` calls. `DuplicateProfile(name, options)` extended with `options.includeMacroLibrary`.
- **Why:** Shared-vs-profile macro storage requires atomic save semantics across profile switch.
- **Files:**
  - `XIUI.lua` [modified] — `SaveCurrentProfileFileToDisk`, post-load hook trio
  - `core/shared_macro_store.lua` [new]
- **Depends on:** 4.1 (shared macro store module)
- **1.8.0 architectural notes:** Must preserve 1.8.0's `ResetSettings` deferred-update pattern (`pendingVisualUpdate = true`).
- **Recommended slice:** `pr/03-shared-macro-store`
- **Open questions:** None.

---

#### 1.5 Post-Load Hook Trio [SURVIVED from pr/13/pr/14]

- **What:** After every profile load (initial, `ChangeProfile`, `settings_update`, `ResetSettings`): `sharedMacroStore.ApplyAfterProfileLoad`, `xiuiInvalidateHotbarDataCaches`, `xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad`.
- **Why:** Ensures macro scope, hotbar caches, and crossbar palette scope are coherent after any settings mutation.
- **Files:**
  - `XIUI.lua` [modified]
  - `modules/hotbar/init.lua` [modified] — cache invalidation targets
  - `modules/hotbar/palette.lua` [modified] — scope application
- **Depends on:** 4.1, 2.1
- **1.8.0 architectural notes:** Appended after 1.8.0's `RunStructureMigrations` at each call site.
- **Recommended slice:** fold into `pr/02-foundational-compat` and `pr/03-shared-macro-store`
- **Open questions:** None.

---

#### 1.6 Alt-Tab Cursor Recovery [SURVIVED from pr/20]

- **What:** `imgui.SetMouseCursor(0)` at start of `d3d_present`. `handlers/imgui_compat.lua` focus-regain hook.
- **Why:** Hardware cursor could disappear after alt-tab until user moved mouse.
- **Files:**
  - `XIUI.lua` [modified]
  - `handlers/imgui_compat.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Runs after `TextureManager.FlushPendingReleases()` (order: flush first, then cursor reset).
- **Recommended slice:** `pr/28-cursor-visibility-popup-ux`
- **Open questions:** None.

---

#### 1.7 `/xiui` Command Extensions [SURVIVED from pr/12/pr/16/pr/21]

- **What:** Full `/xiui cpal` / `cpalette` / `xcpal` / `xcpalette` command family (~350 lines): list, toggle, scope (job|universal), cycle on|off, global/g/gname, compact MAIN+SUB, explicit job, bare-job shorthand. `/xiui pal` toggles Palette Manager. `/xiui menuname` debug command. `/xiui cpaledit` command set. Coexists with 1.8.0's unified `/xiui palette` block.
- **Why:** Advanced job/SJ palette targeting beyond 1.8.0's simple palette cycling.
- **Files:**
  - `XIUI.lua` [modified]
  - `modules/hotbar/palette.lua` [modified] — CLI preview state, anchor API, SJ-only ordering
- **Depends on:** 2.1 (palette storage)
- **1.8.0 architectural notes:** Different keywords — no parser conflict with 1.8.0 `palette` command.
- **Recommended slice:** fold into `pr/15-crossbar-cpal-r1-return` and `pr/02-foundational-compat`
- **Open questions:** None.

---

#### 1.8 Weaponskill Cache Init on Login [SURVIVED from pr/12]

- **What:** After `charSettings = settings.load(...)`, call `playerdata.SetKnownWeaponskills()` with pcall guard. Populates per-character WS cache immediately.
- **Why:** Show All WS colors correct on login without waiting for zone/equip event.
- **Files:**
  - `XIUI.lua` [modified]
  - `modules/hotbar/playerdata.lua` [modified] — `SetKnownWeaponskills`
- **Depends on:** 7.3 (equipment WS cache)
- **1.8.0 architectural notes:** Defensive pcall guard since playerdata merge may not be complete at load time.
- **Recommended slice:** fold into `pr/02-foundational-compat`
- **Open questions:** None.

---

#### 1.9 Palette Manager + FinalizeFrame Draw Order [SURVIVED from pr/13/pr/16]

- **What:** After `configMenu.DrawWindow()`: `paletteManager.Draw()` → `slotrenderer.FlushTooltip()` → `hotbar.FinalizeFrame()`. Z-order: config → palette manager → drag finalize → tooltip.
- **Why:** Correct overlay stacking; deferred drop resolution must run after palette editor zones registered.
- **Files:**
  - `XIUI.lua` [modified]
  - `config/palettemanager.lua` [modified]
  - `modules/hotbar/init.lua` [modified] — `M.FinalizeFrame`
- **Depends on:** 0.15 (deferred drops), 3.1 (palette manager)
- **1.8.0 architectural notes:** 1.8.0 added `FlushTooltip()`; Ferris adds palette manager + finalize frame around it.
- **Recommended slice:** fold into `pr/13-palette-manager-ui`
- **Open questions:** None.

---

#### 1.10 Deferred Texture Release [NEW] — see 0.2

---

### Group 2: Crossbar System

---

#### 2.1 Crossbar Palette Management — Segment Overrides + Universal Palettes [SURVIVED from pr/01-02]

- **What:** `hotbarCrossbar.segmentOverrides` keyed by job+combo mode. Job-shared and Global palette sources resolve before legacy universal override. Universal palette rename/delete syncs segment override refs. `CopyCrossbarPaletteToUniversal` / `CopyUniversalCrossbarPaletteToJob`. Universal vs job-scoped palette cycling. `ValidatePalettesForJob` with scope application.
- **Why:** Per-job crossbar segments can point at shared tiers or global palettes without duplicating slot data.
- **Files:**
  - `modules/hotbar/data.lua` [modified] — segment override storage, draft layer, resolution
  - `core/settings/factories.lua` [modified] — `createCrossbarDefaults()`, segmentOverrides defaults
  - `modules/hotbar/palette.lua` [modified] — rename/delete sync, copy paths, scope API
  - `core/settings/migration.lua` [modified] — crossbar migration steps
- **Depends on:** 1.1 (crossbarEnabled)
- **1.8.0 architectural notes:** data.lua grew from ~1116 (1.8.0) to ~2639 lines. GDI font functions stripped; `BuildSlotDataForWrite` re-added from 1.8.0.
- **Recommended slice:** `pr/20-segment-overrides-data`, `pr/21-segment-overrides-palette-hooks`
- **Open questions:** None.

---

#### 2.2 Edit Full Palette (EFP) UI [SURVIVED from pr/03/pr/16, substantially reworked]

- **What:** `config/palettemanager.lua` (146 KB) hosts EFP. Six crossbar palette-editor public functions. Draft layer with empty-slot sentinel. Editor clip rect culling. Label rendering (minimal vs full multiline). Drop priority 10. Stronger inactive-side dim while trigger held. Pets tab via `efp_pets_tab.lua`.
- **Why:** Safe crossbar palette editing UX with draft/undo, clipped preview, and pet-family filtering.
- **Files:**
  - `config/palettemanager.lua` [modified]
  - `modules/hotbar/crossbar.lua` [modified] — 6 editor public functions, editor DrawSlot params
  - `modules/hotbar/data.lua` [modified] — draft layer API
  - `modules/hotbar/slotrenderer.lua` [modified] — editor clip, labelForeground, dropPriority
  - `config/efp_pets_tab.lua` [new]
- **Depends on:** 2.1, 0.15, 0.11
- **1.8.0 architectural notes:** Complete GDI→imtext port. `HidePaletteEditorPrimitives` is no-op stub (API compat). Editor uses `paled_*` drop zone IDs.
- **Recommended slice:** `pr/18-crossbar-edit-palette-draft`, `pr/22-segment-overrides-efp-ui`
- **Open questions:** Has EFP been smoke-tested end-to-end in-game post-imtext port?

---

#### 2.3 Crossbar Game Menu Block with Visual Dim [SURVIVED from pr/19 + dim fixed — 0.12]

- **What:** `core/gamestate.lua` `IsMenuOpen()` scans FFXI menu name with IGNORED_MENUS list. `crossbarDisableInMenu` setting (default on). Controller skips XInput/DInput when menu open. Crossbar dims to 35% opacity when blocked.
- **Why:** Prevents accidental crossbar execution in inventory/storage menus; optional setting preserves Quick Jump.
- **Files:**
  - `core/gamestate.lua` [modified]
  - `config/crossbar.lua` [new] — Disable Crossbar While In Menu checkbox
  - `core/settings/factories.lua` [modified] — `crossbarDisableInMenu = true`
  - `modules/hotbar/controller.lua` [modified]
  - `modules/hotbar/crossbar.lua` [modified] — visual dim
- **Depends on:** None
- **1.8.0 architectural notes:** New file `core/gamestate.lua` (Ferris-only-modified, safe overlay).
- **Recommended slice:** `pr/16-crossbar-game-menu-block`
- **Open questions:** None.

---

#### 2.4 Crossbar Visual Cutoff Fix [NEW] — see 0.9

---

#### 2.5 Double-Tap Preview Windows [SURVIVED from pr/23, perf-optimized]

- **What:** Two floating ImGui windows (`CrossbarPreviewL2x2`, `CrossbarPreviewR2x2`). Shows 8-slot diamond at configurable scale/opacity. When double-tap active, preview swaps to base L2/R2 bar. Independent lock positions. `DrawMoveAnchor` `anchorSide='top'`.
- **Why:** Players see double-tap contents and cooldowns without activating double-tap.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified] — `DrawDoubleTapPreviewWindow`, `MakePreviewSettings`, `DrawPreviewSide`
  - `config/crossbar_settings.lua` [new] — preview toggles/sliders
  - `core/settings/factories.lua` [modified] — preview defaults
  - `libs/drawing.lua` [modified] — `DrawMoveAnchor anchorSide='top'`
- **Depends on:** 2.2 (crossbar core)
- **1.8.0 architectural notes:** Separate ImGui windows with own draw lists. Zero WindowPadding. Cached settings on geometry signature.
- **Recommended slice:** `pr/17-crossbar-doubletap-preview`
- **Open questions:** Double-tap preview polish per plan: no qty/MP in preview, keep cooldowns, allow SC + MB borders — verify implemented.

---

#### 2.6 Shared Expanded Bar Layout (`useSharedExpandedBar`) [SURVIVED, fully ported D.15]

- **What:** When `useSharedExpandedBar=true` and L2+R2 chord held, both diamonds collapse into single centered 8-slot strip. `GetDisplayModes` returns `('Shared', …, 'center')`. Window force-centers; `lastWideCrossbarWindowX` stashed for exit-chord restore. `DrawTriggerIconsSharedExpandedCenter` renders combined L2+R2 glyph.
- **Why:** Alternative crossbar layout for players who prefer single centered bar during chord.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified]
  - `config/crossbar_settings.lua` [new] — toggle UI
  - `core/settings/factories.lua` [modified] — default
- **Depends on:** 2.2 (crossbar core)
- **1.8.0 architectural notes:** Major DrawWindow restructure; save-position only writes Y while chord active.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 2.7 Cpal Anchor + Pulsing R1 x2 Indicator [SURVIVED from pr/21]

- **What:** `/xiui cpal` sets anchor before palette switch. R1 double-tap (400ms, no L1) restores anchor. Pulsing R1 icon above R2 with dark pill + gold "x2" when anchor live. Per-scope anchors (universal vs job).
- **Why:** Programmatic palette switches via macro need a return path without another macro.
- **Files:**
  - `XIUI.lua` [modified] — anchor set in cpal handler
  - `modules/hotbar/palette.lua` [modified] — cpal anchor API
  - `modules/hotbar/controller.lua` [modified] — R1 double-tap restore
  - `modules/hotbar/crossbar.lua` [modified] — pulsing R1 render
- **Depends on:** 1.7 (cpal commands), 0.4 (L1 latching)
- **1.8.0 architectural notes:** Pure drawList ops for pulse animation (~2.5 Hz sin wave).
- **Recommended slice:** `pr/15-crossbar-cpal-r1-return`
- **Open questions:** None.

---

#### 2.8 Stronger Inactive-Side Dim While Trigger Held [SURVIVED from pr/16 body]

- **What:** When `activeCombo ~= NONE`, inactive half dims to `inactiveSideWhileTriggerDim` (default 0.15) vs `inactiveSlotDim` (default 0.5). `activeCombo` threaded through 11 call sites.
- **Why:** Clearer visual focus on active crossbar half during trigger hold.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified]
  - `core/settings/factories.lua` [modified] — defaults
- **Depends on:** None
- **1.8.0 architectural notes:** Ferris-only UX polish; 1.8.0 base shipped without this.
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 2.9 Crossbar WindowPadding Zero (Horizontal Clip Fix) [SURVIVED from smoke-test pass 1]

- **What:** `imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {0, 0})` before crossbar Begin/End. Recovers leftmost/rightmost diamond slot clipping.
- **Why:** Default ~8px padding clipped flush diamond slots and pushed hitboxes inward.
- **Files:**
  - `modules/hotbar/crossbar.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Complements 0.9 top/bottom decor pad (orthogonal fixes).
- **Recommended slice:** fold into `pr/14-crossbar-core`
- **Open questions:** None.

---

#### 2.10 Crossbar Settings Separation from Hotbar Tab [SURVIVED from smoke-test pass 1]

- **What:** Ferris refactored `config/hotbar.lua` (2448 lines, down from 1.8.0's 3263). Moved ~815 lines of crossbar UI to `config/crossbar.lua` + `config/crossbar_settings.lua`. Removed Layout Mode dropdown from Hotbar tab. Edit Full Palette entry moved to Crossbar tab. Lock Crossbar decoupled from Hotbar lock.
- **Why:** User explicitly separated hotbar and crossbar configuration concerns.
- **Files:**
  - `config/hotbar.lua` [modified]
  - `config/crossbar.lua` [new]
  - `config/crossbar_settings.lua` [new]
  - `config.lua` [modified] — Crossbar tab registration
- **Depends on:** None
- **1.8.0 architectural notes:** Retains 1.8.0's Show Stack Quantity checkbox (re-applied surgically). Ferris kept Slot Y Padding slider (1.8.0 removed it).
- **Recommended slice:** `pr/19-crossbar-settings`
- **Open questions:** Should Slot Y Padding slider be removed now that 1.8.0 uses independent bar positioning?

---

#### 2.11 Crossbar Slot Overlay DrawList Z-Order [SURVIVED from slotrenderer Pass 1]

- **What:** `slotOverlayDrawList()` returns `imgui.GetWindowDrawList()` for Crossbar window, else `GetUIDrawList()`. Crossbar overlays stack within window z-order, not above modal dialogs.
- **Why:** Shared UI drawList always paints on top of every ImGui window, breaking hovers under modals.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** New per-window drawList selector; 1.8.0 used shared UI drawList exclusively.
- **Recommended slice:** fold into `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

### Group 3: Palette Manager UI

---

#### 3.1 Expanded Palette Manager (146 KB) [SURVIVED from pr/22/pr/13]

- **What:** Floating Palette Manager window for hotbar + crossbar palettes. Scroll-safe layout, horizontal resize, job-label warnings, quick palette switcher, crossbar edit appearance decoupled from in-game visuals. Non-blocking create/rename/copy modals. Profile JSON backup/transfer UI in config.lua.
- **Why:** Central hub for palette CRUD, crossbar scope management, and profile portability.
- **Files:**
  - `config/palettemanager.lua` [modified] — expanded from 27.9 KB stub to 146 KB
  - `config.lua` [modified] — Profiles window Backup/Transfer
- **Depends on:** 4.5 (palette_json), 2.1 (palette storage)
- **1.8.0 architectural notes:** Uses imgui directly; zero GDI references post-overlay. 10 inner-scoped closures, 8 legacy `imgui.Columns` noted as polish opportunities.
- **Recommended slice:** `pr/13-palette-manager-ui`
- **Open questions:** Polish pass deferred (imgui.Columns → BeginTable) — include in this slice or separate?

---

#### 3.2 Palette Manager Status Icons — Checkmark/X [SURVIVED from pr/22, path fixed D.7/D.11]

- **What:** Active/Inactive column uses centered checkmark/X image icons via `TextureManager.getFileTexture('checkmark')` / `getFileTexture('x')`. Path updated from old `getCustomIcon('checkmark.png')` under `assets/hotbar/custom/`.
- **Why:** Cleaner palette list than text Active/Inactive labels.
- **Files:**
  - `config/palettemanager.lua` [modified]
  - `assets/checkmark.png` [new]
  - `assets/x.png` [new]
- **Depends on:** 3.1
- **1.8.0 architectural notes:** `getFileTexture` auto-appends `.png`, resolves under `assets/`.
- **Recommended slice:** fold into `pr/13-palette-manager-ui`
- **Open questions:** None.

---

#### 3.3 Palette Row +M Macro Button [SURVIVED from pr/22]

- **What:** `+M` button on each palette row pre-populates new macro with `/xiui cpal` switch command for that palette.
- **Why:** Eliminates manual macro authoring for palette switches.
- **Files:**
  - `config/palettemanager.lua` [modified]
- **Depends on:** 1.7 (cpal commands), 4.3 (macro system)
- **1.8.0 architectural notes:** None.
- **Recommended slice:** fold into `pr/13-palette-manager-ui`
- **Open questions:** None.

---

#### 3.4 Crossbar New Palette Popup — Non-Blocking + Tier Persistence [SURVIVED from pr/22]

- **What:** Crossbar New palette popup converted from blocking modal to BeginPopup. Persists last-selected job/storage-subjob tier across opens; resets on character job/subjob change. Auto-names new palettes based on tier.
- **Why:** Hardware cursor stays visible; tier memory reduces repetitive selection.
- **Files:**
  - `config/hotbar.lua` [modified] — shared palette modal helpers
  - `config/palettemanager.lua` [modified]
- **Depends on:** 3.1
- **1.8.0 architectural notes:** Matches pr/20 non-blocking popup pattern.
- **Recommended slice:** fold into `pr/13-palette-manager-ui`
- **Open questions:** None.

---

### Group 4: Macro System

---

#### 4.1 Shared Macro Store [SURVIVED from pr/14]

- **What:** `core/shared_macro_store.lua` — two-mode storage: `shared` (global `SharedMacros.lua`) vs `profile` (per-profile `gConfig.macroDB`). Frozen snapshot in shared mode for profile switch. Load/save/id separation.
- **Why:** One global macro library shared across all profiles vs per-profile isolation.
- **Files:**
  - `core/shared_macro_store.lua` [new]
  - `core/settings/user.lua` [modified] — `macroStorageScope`
  - `core/settings/migration.lua` [modified] — macro migrations
- **Depends on:** None
- **1.8.0 architectural notes:** No render code; pure data layer.
- **Recommended slice:** `pr/03-shared-macro-store`
- **Open questions:** None.

---

#### 4.2 Dual Per-Slot Macro Bindings [SURVIVED from pr/14]

- **What:** Each hotbar/crossbar slot holds independent `macroBindProfile` and `macroBindShared` arms. Active arm follows `macroStorageScope`. `MigrateSlotDualMacroBindings` in migration.lua.
- **Why:** Same physical slot can reference different macros depending on storage scope.
- **Files:**
  - `modules/hotbar/data.lua` [modified]
  - `core/settings/migration.lua` [modified]
- **Depends on:** 4.1
- **1.8.0 architectural notes:** Extends 1.8.0's `MigrateSlotMacroRefs` (macroRef-as-source-of-truth).
- **Recommended slice:** fold into `pr/03-shared-macro-store`
- **Open questions:** None.

---

#### 4.3 Macro Palette Buckets [SURVIVED from pr/14/pr/15]

- **What:** Bucket schema: `global`, `items`, `equipment`, `xiui`, `custom:N`. Custom buckets support create/rename/delete with slot cleanup via `ApplyMacroPaletteBucketRemovedToSlotAction`.
- **Why:** Organizes macro library by category; custom types for user-defined groupings.
- **Files:**
  - `modules/hotbar/macro_palette_buckets.lua` [new]
  - `modules/hotbar/macropalette.lua` [modified]
  - `modules/hotbar/data.lua` [modified]
- **Depends on:** 4.1
- **1.8.0 architectural notes:** None.
- **Recommended slice:** `pr/10-macro-system`
- **Open questions:** None.

---

#### 4.4 Universal 2 Hour Global Macro [SURVIVED from pr/14]

- **What:** `universal_two_hour.lua` maps job ID → 2-hour ability name. `macro_global_defaults.lua` provides sentinel resolution and seed. Arming window (~7.5s) with shimmer/subtarget glow. `/ja` targeting: `stpc` / `stnpc` (RNG uses `stnpc`). Pink-star marker in JA list. Locked Global-row macro cannot be deleted/edited away.
- **Why:** One pinned macro always reflects current main job 2-hour without per-job copies.
- **Files:**
  - `modules/hotbar/universal_two_hour.lua` [new]
  - `modules/hotbar/macro_global_defaults.lua` [new]
  - `modules/hotbar/macro_xiui_defaults.lua` [new]
  - `libs/target.lua` [modified] — subtarget detection
  - `modules/hotbar/slotrenderer.lua` [modified] — UTH rainbow border + glow
- **Depends on:** 4.1, 4.3
- **1.8.0 architectural notes:** UTH visual features ported to imtext drawList (Pass 1 slotrenderer). `NotifySlotExecutionEffects` skips shimmer while on cooldown.
- **Recommended slice:** fold into `pr/03-shared-macro-store` and `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 4.5 Profile JSON Export/Import [SURVIVED from pr/13]

- **What:** `palette_json.lua` (40 KB) — whole-profile JSON export/import (`xiuiExportVersion 1`, `kind xiui_profile`). All keyboard palettes, crossbar palettes, macro library. Merge vs replace. Pretty-printed annotations. Post-import palette invalidation hooks.
- **Why:** Structured backup/migration path for entire character bar setup.
- **Files:**
  - `modules/hotbar/palette_json.lua` [new]
  - `libs/json.lua` [new]
  - `config/palettemanager.lua` [modified] — per-palette JSON UI removed; whole-profile only
  - `config.lua` [modified] — Profiles Backup/Transfer modal
  - `modules/hotbar/palette.lua` [modified] — `InvalidateCachesAfterExternalSlotMutation`, `RefreshActivePaletteVisualsAfterExternalEdit`
  - `modules/hotbar/init.lua` [modified] — OnPaletteChanged dedupe includes bar/combo id
- **Depends on:** 4.3, 2.1
- **1.8.0 architectural notes:** No render code.
- **Recommended slice:** `pr/12-profile-json`
- **Open questions:** End-to-end export/import round-trip smoke test pending per plan D.13.

---

#### 4.6 Macro Editor — Show All, Spell Colors, Copy, JA Badge Sync [SURVIVED from pr/11]

- **What:** Show All toggles/filters (magic type, ability job, WS weapon, pet type). Two-color spell rows. Group headers. Hover reasons on unavailable entries. Copy macro. JA badge manual vs implicit sync. Locked Global-row handling. SaveMacro syncs dropdown/text buffers before validation.
- **Why:** Large spell/ability lists navigable; Copy speeds palette workflows.
- **Files:**
  - `modules/hotbar/macropalette.lua` [modified] — 6341 lines (Ferris overlay + 1.8.0 re-applications)
  - `modules/hotbar/macropalette_macroeditor.lua` [new] — 86 KB closure-factory extension
- **Depends on:** 4.3, 7.1 (playerdata Show All)
- **1.8.0 architectural notes:** Zero GDI references post-overlay. Closure attaches via `return function(MP)` pattern — verify 1.8.0 macropalette internals still match.
- **Recommended slice:** `pr/11-macro-editor`
- **Open questions:** Macro editor smoke-tested in-game post-imtext port?

---

#### 4.7 Macro Custom Categories + Items Palette Restrictions [SURVIVED from pr/15]

- **What:** Custom type (+) in popup only. Red remove + Rename on type row. Delete confirms macro count. Items/equipment macros: action-type combo restricted in editor via `ClampMacroEditorForItemsPalette`. `DefaultNewMacroBodyForPaletteKey`.
- **Why:** Custom categories manageable from UI; Items bucket editing stays coherent.
- **Files:**
  - `modules/hotbar/macropalette.lua` [modified]
  - `modules/hotbar/macropalette_macroeditor.lua` [modified]
  - `modules/hotbar/data.lua` [modified]
- **Depends on:** 4.3
- **1.8.0 architectural notes:** None.
- **Recommended slice:** fold into `pr/11-macro-editor`
- **Open questions:** None.

---

#### 4.8 Move Macro to Palette [SURVIVED from pr/16]

- **What:** `MoveMacroToPalette` public API. `RewriteMacroPaletteBindingsInConfig` + `RewriteMacroPaletteBindingsInDraft` update all bindings on move. Palette picker popup.
- **Why:** Relocating macro library row without breaking hotbar/crossbar binds.
- **Files:**
  - `modules/hotbar/macropalette.lua` [modified]
  - `modules/hotbar/data.lua` [modified]
- **Depends on:** 4.3, 2.2 (EFP draft layer)
- **1.8.0 architectural notes:** None.
- **Recommended slice:** fold into `pr/18-crossbar-edit-palette-draft`
- **Open questions:** None.

---

#### 4.9 Macro Editor Spell List Dedup Fix [SURVIVED from pr/24]

- **What:** Spell dedup on spell id before building display list. `GetPlayerSpells` reads unlearnable flags from horizonspells.lua. Show-All-off consistently shows known/available spells.
- **Why:** Create Macro spell picker missing known spells; duplicate rows for multi-category spells.
- **Files:**
  - `modules/hotbar/macropalette.lua` [modified]
  - `modules/hotbar/playerdata.lua` [modified]
- **Depends on:** 7.1
- **1.8.0 architectural notes:** None.
- **Recommended slice:** fold into `pr/11-macro-editor`
- **Open questions:** None.

---

#### 4.10 Macro Parse — Primary Action + Corner Badge [SURVIVED from old group A]

- **What:** `macroparse.lua` — multi-line macro parser. Priority: `/ws,/ma,/pet` → `/ja` → `/item,/equip` → other. Returns primary action + JA badge.
- **Why:** Drives corner badge rendering, skillchain/MB routing for macros, recast sniffing.
- **Files:**
  - `modules/hotbar/macroparse.lua` [new]
- **Depends on:** None
- **1.8.0 architectural notes:** Pure logic; no render code.
- **Recommended slice:** fold into `pr/10-macro-system`
- **Open questions:** None.

---

#### 4.11 XIUI Default Macros Seed [SURVIVED from pr/14]

- **What:** `macro_xiui_defaults.lua` — default `/xiui` slash macros (Toggle XIUI Menu, Open Macros, Palette Managers, etc.). One-time seed gated by `macroXiuiDefaultsSeeded`.
- **Why:** Discoverability of XIUI features via in-game macro library.
- **Files:**
  - `modules/hotbar/macro_xiui_defaults.lua` [new]
  - `core/settings/migration.lua` [modified] — `MigrateMacroXiuiDefaults`
- **Depends on:** 4.1
- **1.8.0 architectural notes:** None.
- **Recommended slice:** fold into `pr/10-macro-system`
- **Open questions:** None.

---

### Group 5: SMN / Blood Pact System

---

#### 5.1 Horizon Blood Pact Data Tables [SURVIVED from pr/04]

- **What:** `horizon_bloodpacts.lua` — synthetic spell-shaped rows (ids starting 10200). `horizon_bloodpacts_xiui.lua` — XIUI overlays (status labels, corner icons, `requiresFlow`). `horizonspells.lua` extended. `gen_horizon_bloodpacts.py` regen script.
- **Why:** Blood pact availability/costs match Horizon progression; data regeneratable.
- **Files:**
  - `modules/hotbar/database/horizon_bloodpacts.lua` [new]
  - `modules/hotbar/database/horizon_bloodpacts_xiui.lua` [new]
  - `modules/hotbar/database/horizonspells.lua` [modified]
  - `scripts/gen_horizon_bloodpacts.py` [restored, tooling]
- **Depends on:** None (pure data)
- **1.8.0 architectural notes:** None.
- **Recommended slice:** `pr/04-smn-bloodpacts-data`
- **Open questions:** None.

---

#### 5.2 Pet Registry Blood Pact Merge [SURVIVED from pr/05]

- **What:** `petregistry.lua` merges retail avatar metadata with horizon blood pact stats and XIUI overlays. `GetBloodPactByName` / `RebuildBloodPactIndex`. Astral Flow–gated pacts: pink asterisk + tooltip. Show All sort: AF-only → Commands → BP:Rage → BP:Ward.
- **Why:** Single resolution point for blood pact display and gating.
- **Files:**
  - `modules/hotbar/petregistry.lua` [modified]
- **Depends on:** 5.1
- **1.8.0 architectural notes:** +24 KB expansion over 1.8.0 base.
- **Recommended slice:** fold into `pr/04-smn-bloodpacts-data`
- **Open questions:** None.

---

#### 5.3 Blood Pact Action Resolution, Icons, Recast [SURVIVED from pr/06]

- **What:** `BloodPactRage/BloodPactWard` handling in actions.lua. Icon resolution. BP shared timer (173/174) name-based lookup in recast.lua. Macro-text sniffers: `sniffRecastTargetFromMaMacroText`, `sniffRecastTargetFromPetMacroText`, `sniffRecastTargetFromJaMacroText`. `resolveSpellIndexForMa` Horizon-aware. Lazy recast architecture preserved (no periodic `M.Update()` reintroduced).
- **Why:** Hotbar/macro layers resolve correct icons, names, and cooldowns for pact abilities.
- **Files:**
  - `modules/hotbar/actions.lua` [modified] — 2164 lines (Ferris overlay + 1.8.0 perf wins)
  - `modules/hotbar/recast.lua` [modified]
- **Depends on:** 5.1, 5.2, 4.10 (macroparse)
- **1.8.0 architectural notes:** 1.8.0's lazy per-spell-id cache + `noIconCache` preserved as base; Ferris sniffers feed into same cache.
- **Recommended slice:** `pr/05-smn-actions-bloodpacts`
- **Open questions:** None.

---

#### 5.4 Blood Pact Slot Overlays + UTH on Slots [SURVIVED from pr/07]

- **What:** Blood pact corner overlays and status icons on slots. Universal 2 Hour rainbow marching border + subtarget glow. Editor clip rect for EFP. Default MP cost anchor top-left.
- **Why:** Blood pact state visible on slots; editor preview respects ImGui clip bounds.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified]
  - `modules/hotbar/display.lua` [modified] — mpCostAnchor default topLeft
- **Depends on:** 5.3, 4.4 (UTH)
- **1.8.0 architectural notes:** Complete imtext port; GDI prim cache removed.
- **Recommended slice:** fold into `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 5.5 Pet Palette — Avatars / Elementals / EFP Pet Tabs [SURVIVED from pr/15]

- **What:** `pet_palette_allowlist.lua` — type tokens: avatars, elementals, beasts, wyvern, puppet. Legacy "summons" upgrades to avatars+elementals. EFP pet family tabs via `efp_pets_tab.lua`. SMN sort and pet-bar omit rules.
- **Why:** SMN "summons" split into avatars vs elementals for configuration and EFP.
- **Files:**
  - `modules/hotbar/pet_palette_allowlist.lua` [new]
  - `config/efp_pets_tab.lua` [new]
  - `modules/hotbar/petpalette.lua` [modified]
  - `modules/hotbar/petregistry.lua` [modified]
  - `modules/hotbar/macropalette.lua` [modified]
  - `core/settings/factories.lua` [modified] — petPalettePetKeys defaults
- **Depends on:** 5.2
- **1.8.0 architectural notes:** 1.8.0 added per-pet-type factory tables that may partially subsume Ferris's per-family overrides — verify no duplication.
- **Recommended slice:** `pr/24-pet-palette-allowlist`
- **Open questions:** Does 1.8.0's `petBarAvatarSettings` fully subsume Ferris pet-family positioning?

---

#### 5.6 BST Jug Ready Cost Display [SURVIVED from pr/15]

- **What:** `isBstJugReadySpellCost` flag in castcost display. Replaces "MP:" with "Cost:" (TP-gold color) using spell's `ManaCost` field as pet-charge cost.
- **Why:** Ready charge costs should read like gameplay charges, not MP.
- **Files:**
  - `modules/castcost/display.lua` [modified]
- **Depends on:** 5.2 (petregistry helpers)
- **1.8.0 architectural notes:** Layered on 1.8.0 imtext rewrite cleanly.
- **Recommended slice:** fold into `pr/24-pet-palette-allowlist`
- **Open questions:** None.

---

#### 5.7 SMN Blood Pact Assets [SURVIVED from pr/08, partially]

- **What:** Icons for blood pact/ward UI and status corners. Pet avatar/spirit PNGs. SMN AvatarsFavor.png. Tetsouou/35.png status icon. 25 item PNGs under `assets/hotbar/items/`.
- **Why:** SMN blood pact/ward visuals and correct item art in macros/hotbar.
- **Files:**
  - `assets/pets/bloodpact.png` [present]
  - `assets/pets/ward.png` [present]
  - `assets/hotbar/SMN/AvatarsFavor.png` [present]
  - `assets/status/Tetsouou/35.png` [present]
  - `assets/pets/avatars/*.png` [present — full avatar set]
  - `assets/pets/spirits/*.png` [present — full spirit set]
  - `assets/hotbar/items/*.png` [25 files, new vs 1.8.0]
- **Depends on:** 5.1
- **1.8.0 architectural notes:** 1.8.0 ships `submodules/xiui-icons/` (222 community icons) as documentation/source only — runtime loads from `assets/hotbar/`. Phase 1 icon overlap audit skipped at user request.
- **Recommended slice:** `pr/23-smn-assets`, `pr/29-misc-assets`
- **Open questions:** Some pr/08 item icons (04378, 18600, 21759, 61467) not re-added — covered by xiui-icons, intentionally dropped, or missing?

---

### Group 6: Horizon Static Databases

---

#### 6.1 Horizon Abilities [SURVIVED from pr/09]

- **What:** Static JA lookup (job + level + pet?) from HorizonXI JA Progression spreadsheet.
- **Why:** Show All and filters use accurate Horizon unlock rules.
- **Files:** `modules/hotbar/database/horizon_abilities.lua` [new]
- **Depends on:** None
- **1.8.0 architectural notes:** Pure data.
- **Recommended slice:** `pr/01-horizon-static-databases`
- **Open questions:** None.

---

#### 6.2 WS Weapon Types [SURVIVED from pr/09]

- **What:** Weaponskill → weapon category, required skill level, relic-only flags.
- **Why:** WS Show All sort and equipment-based availability.
- **Files:** `modules/hotbar/database/ws_weapon_types.lua` [new]
- **Depends on:** None
- **1.8.0 architectural notes:** Pure data.
- **Recommended slice:** `pr/01-horizon-static-databases`
- **Open questions:** None.

---

#### 6.3 Horizon Spell Omissions [SURVIVED from pr/09]

- **What:** Spell names excluded from Show All (post-75, retail-only, etc.).
- **Why:** Keeps core spell DB untouched while filtering Horizon-inappropriate spells.
- **Files:** `modules/hotbar/database/horizon_spell_omissions.lua` [new]
- **Depends on:** None
- **1.8.0 architectural notes:** Pure data.
- **Recommended slice:** `pr/01-horizon-static-databases`
- **Open questions:** None.

---

#### 6.4 Retail-Only Job Abilities [SURVIVED from pr/10]

- **What:** Named JAs on retail but not Horizon (Bestial Loyalty, Feral Howl, Killer Instinct, Unleash, Snarl, Spur, Run Wild).
- **Why:** HasAbility-driven lists treat them as unavailable on Horizon.
- **Files:** `modules/hotbar/database/horizon_retail_only_job_abilities.lua` [new]
- **Depends on:** None
- **1.8.0 architectural notes:** Pure data.
- **Recommended slice:** `pr/01-horizon-static-databases`
- **Open questions:** None.

---

### Group 7: Player Data & Action Availability

---

#### 7.1 Show All Lists with Spell Sort / Colors [SURVIVED from pr/10]

- **What:** `GetAllSpells`, `GetAllAbilities`, `GetAllWeaponskills` with status tiers and hover reason strings. Spell sort: level then name within magic type. WS sort: weapon category A→Z, skill req low→high. JA two-hour sort first. Pink asterisk for Universal 2 Hour hint. `ABILITY_TYPE` enum table (24 entries). Trait + CategoryPlaceholder filters. Horizon filtering throughout.
- **Why:** Macro editor and hotbar show consistent availability and readable lists on Horizon.
- **Files:**
  - `modules/hotbar/playerdata.lua` [modified] — +700 lines Ferris overlay with 1.8.0 refinements
- **Depends on:** 6.1–6.4
- **1.8.0 architectural notes:** Replaced `bit.band(ability.Type, 7)` with plain `ability.Type` (enum, not bitfield). Added `CATEGORY_PLACEHOLDER_NAMES`. Removed `'Assault'` from PET_COMMAND_NAMES.
- **Recommended slice:** `pr/06-playerdata-show-all`
- **Open questions:** None.

---

#### 7.2 Equipment WS Cache [SURVIVED from pr/14]

- **What:** `equipment_ws.lua` — WS cache-bust signature: job + levels + level sync + main/sub/range item IDs. Drives WS list refresh on gear swap.
- **Why:** WS availability tracks currently-equipped weapon without full rescan.
- **Files:**
  - `modules/hotbar/equipment_ws.lua` [new]
  - `modules/hotbar/playerdata.lua` [modified] — integration hooks
- **Depends on:** 6.2
- **1.8.0 architectural notes:** Orthogonal to 1.8.0's slotInteraction perf pattern.
- **Recommended slice:** fold into `pr/06-playerdata-show-all`
- **Open questions:** None.

---

#### 7.3 Level Sync Cache Invalidation [SURVIVED from pr/14]

- **What:** `statushandler.lua` detects Level Sync buff (id 269) transition → `playerdata.ClearCache()` + `slotrenderer.ClearAvailabilityCache()`.
- **Why:** Spell/ability availability depends on synced level; caches must invalidate on sync on/off.
- **Files:**
  - `handlers/statushandler.lua` [modified]
- **Depends on:** 0.5 (availability cache)
- **1.8.0 architectural notes:** Ferris-only feature; 1.8.0 doesn't track Level Sync for cache invalidation.
- **Recommended slice:** fold into `pr/06-playerdata-show-all`
- **Open questions:** None.

---

#### 7.4 Custom Icon Resolution [SURVIVED from old group A]

- **What:** `customiconresolve.lua` — resolves `assets/hotbar/custom/*.png` by action name (recursive scan). `iconmatch.lua` — fuzzy name-to-icon matcher. `textures.lua` — custom texture resolution with `custom_icons.maxSize = 0` no-eviction tweak.
- **Why:** User custom icons for macros/actions; Ferris found LRU evict+reload caused stutter in macro picker.
- **Files:**
  - `modules/hotbar/customiconresolve.lua` [new]
  - `modules/hotbar/iconmatch.lua` [new]
  - `modules/hotbar/textures.lua` [modified]
  - `libs/texturemanager.lua` [modified] — no-eviction for custom_icons
- **Depends on:** None
- **1.8.0 architectural notes:** Custom icon path separate from 1.8.0's `submodules/xiui-icons/` (documentation only).
- **Recommended slice:** fold into `pr/29-misc-assets` or `pr/06-playerdata-show-all`
- **Open questions:** Phase 1 icon overlap audit skipped — user to copy custom icons manually.

---

#### 7.5 Unavailable Ability Visual Feedback [RESTORED] — see 0.5

#### 7.6 Effective Level in IsActionAvailable [NEW fix] — see 0.8

#### 7.7 Crossbar PlayerData Cache Warm [NEW fix] — see 0.7

---

### Group 8: Skillchain & Magic Burst

---

#### 8.1 Skillchain Prediction (Existing) [SURVIVED from pr/07]

- **What:** `skillchain.lua` tracks resonation state per target. `GetSkillchainForBloodPact`. `DrawSkillchainHighlight` — gold dashed border + SC-name icon top-right. Override params for editor icon relocation.
- **Why:** Visual cue for next skillchain step on WS/BP/macro slots.
- **Files:**
  - `modules/hotbar/skillchain.lua` [modified]
  - `modules/hotbar/slotrenderer.lua` [modified]
  - `modules/hotbar/display.lua` [modified]
  - `modules/hotbar/crossbar.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Ported to imtext drawList. `GetCrossbarSkillchainVisualsFromGlobal` helper not needed — slotrenderer reads `gConfig.hotbarGlobal` directly at call site.
- **Recommended slice:** `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 8.2 Magic Burst Highlight [NEW] — see 0.1

---

#### 8.3 Universal 2 Hour Rainbow Border + Subtarget Glow [SURVIVED from pr/07]

- **What:** `DrawUniversalTwoHourRainbowMarchingBorder`, `DrawUniversalTwoHourSubtargetGlow` — pure ImGui drawList ops. Gated by `universalTwoHour.ShouldGlowUniversalTwoHourSlot(bind)`. Shimmer suppressed on cooldown.
- **Why:** Visual arming/subtarget cue for Universal 2 Hour macro execution.
- **Files:**
  - `modules/hotbar/slotrenderer.lua` [modified]
  - `modules/hotbar/universal_two_hour.lua` [new]
- **Depends on:** 4.4
- **1.8.0 architectural notes:** Ported in slotrenderer Pass 1; lazy pcall require for compat.
- **Recommended slice:** fold into `pr/07-slotrenderer-uth-skillchain`
- **Open questions:** None.

---

#### 8.4 Shared Skillchain + Magic Burst Config UI [NEW + SURVIVED]

- **What:** `DrawSharedSkillchainHighlightControls` in hotbar.lua — skillchain color picker (previously not exposed), Magic Burst checkbox + color picker, shared Icon Scale/Offset help text for both highlights.
- **Why:** User-configurable highlight appearance for both SC and MB systems.
- **Files:**
  - `config/hotbar.lua` [modified]
  - `core/settings/factories.lua` [modified]
- **Depends on:** 8.1, 8.2
- **1.8.0 architectural notes:** Shared controls consumed by crossbar_settings.lua via require.
- **Recommended slice:** fold into `pr/19-crossbar-settings`
- **Open questions:** None.

---

### Group 9: Pet Bar

---

#### 9.1 Pet Bar Resize Anchor [SURVIVED from pr/18]

- **What:** Global `gConfig.petBarResizeAnchor` (top vs bottom pinned edge). `PetBarResizeAnchoredBottom()` resolver. Preview Mode stripe at pinned edge. Stable bottom-edge math. Migration from legacy per-type `alignBottom`.
- **Why:** One global HUD resize choice regardless of Pet Target snapping.
- **Files:**
  - `modules/petbar/display.lua` [modified]
  - `modules/petbar/data.lua` [modified]
  - `config/petbar.lua` [modified — from 1.8.0 base + Ferris UI]
  - `core/settings/migration.lua` [modified]
  - `core/settings/user.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Layered on 1.8.0 GDI→imtext petbar rewrite + independent MP/TP/recast scaling.
- **Recommended slice:** `pr/25-pet-bar-resize-anchor`
- **Open questions:** None.

---

#### 9.2 Pet Target Snap + Cluster Drag [SURVIVED from pr/18]

- **What:** `petBarTargetHitRect`, cluster drag from snapped target hit rect. Snap-with-top places PetTarget above pet bar. Input-blocking (NoInputs) when snapped. `petBarSyncResizeAnchorNextFrame` for cluster drag. `petTargetSnapCachedHeight` persisted.
- **Why:** Pet bar and pet target move as a unit; snap placement correct across sessions.
- **Files:**
  - `modules/petbar/pettarget.lua` [modified]
  - `modules/petbar/data.lua` [modified]
  - `modules/petbar/display.lua` [modified]
  - `handlers/imgui_compat.lua` [modified] — hover detection helpers
- **Depends on:** 9.1
- **1.8.0 architectural notes:** Layered on 1.8.0 imtext rewrite; `clearPetTargetSpatialState()` on hide paths.
- **Recommended slice:** fold into `pr/25-pet-bar-resize-anchor`
- **Open questions:** None.

---

### Group 10: Party List

---

#### 10.1 Buff/Debuff 1-Based Iteration Fix [SURVIVED from pr/17] — UPSTREAM BUG

- **What:** Loop changed from `i = 0` to `i = 1` through `#memInfo.buffs`. Break on nil, -1, 255 terminators. Local-hoist buff/debuff arrays.
- **Why:** `buffs[0]` always nil → classified as debuff → `DrawStatusIcons(nil)` → native renderer crash on login/character swap.
- **Files:**
  - `modules/partylist/display.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** **1.8.0 upstream bug.** Ferris fix should be submitted to tirem/XIUI. Also includes pr/25 position-correction improvements in same file.
- **Recommended slice:** `pr/26-party-list-buff-split`
- **Open questions:** Submit upstream PR to tirem?

---

#### 10.2 Align-Bottom Anchor Drift Fix [SURVIVED from pr/25]

- **What:** `helpers.lua` `ApplyWindowPosition` returns true on apply frame. `display.lua` bottom-anchor math; height correction syncs `windowPositions` immediately. Profile/character load height correction when saved Y matches applied Y. User drag resets bottom anchor; persists via `SaveSettingsOnly()`.
- **Why:** Party/alliance lists drifted on reload, character swap, profile switch.
- **Files:**
  - `handlers/helpers.lua` [modified]
  - `modules/partylist/display.lua` [modified]
- **Depends on:** 10.1 (same file, but logically independent)
- **1.8.0 architectural notes:** Replaced `ashita_settings.save()` with `SaveSettingsOnly()` to prevent profile reload wiping in-memory positions.
- **Recommended slice:** `pr/27-party-list-align-bottom`
- **Open questions:** None.

---

### Group 11: Settings System

---

#### 11.1 Settings — User Keys [SURVIVED collectively from pr/01–pr/25]

- **What:** `core/settings/user.lua` (35,505 bytes). Ferris additions: `crossbarEnabled`, `crossbarLockMovement`, 6 macro settings, `petBarResizeAnchor`, `petTargetSnapTopGap`, `petTargetSnapCachedHeight`. Retains all 1.8.0 additions: `globalScale`, `showReadyCheck`, `expBarMasteryMode`, `petTargetBgScale`, `petTargetBorderScale`.
- **Why:** Every Ferris feature needs persisted settings keys with factory defaults.
- **Files:** `core/settings/user.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Both sides independently removed per-module `*WindowPosX/Y` block — happy convergence.
- **Recommended slice:** `pr/02-foundational-compat`
- **Open questions:** Was `petBarReadyBaseRecast` patched from 30 → 45 for Horizon?

---

#### 11.2 Settings — Factories [SURVIVED collectively]

- **What:** `core/settings/factories.lua` (34,034 bytes). Full `createCrossbarDefaults()` rewrite: universal palettes, segmentOverrides, double-tap preview, paletteJobIconTheme, magicBurst settings. Re-injected 1.8.0's 3 `showStackQuantity = false` lines.
- **Files:** `core/settings/factories.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Ferris overlay with surgical 1.8.0 key re-injection.
- **Recommended slice:** distribute into feature slices that introduce each factory key
- **Open questions:** `petBarReadyBaseRecast` default — Horizon uses 45, factory may still say 30.

---

#### 11.3 Settings — Migration [SURVIVED collectively]

- **What:** `core/settings/migration.lua` (57,838 bytes). 6 Ferris migrations + `EnsureMacroDatabaseCoherence` + `MigrateSlotDualMacroBindings`. Also contains 1.8.0's `MigrateSlotMacroRefs`. Independent convergence on `MigrateLegacyPositionFields`.
- **Files:** `core/settings/migration.lua` [modified]
- **Depends on:** 11.1, 11.2
- **1.8.0 architectural notes:** Ferris migrations run after 1.8.0's; must remain idempotent.
- **Recommended slice:** `pr/02-foundational-compat` (core migrations), feature-specific migrations in respective slices
- **Open questions:** None.

---

### Group 12: Config UI

---

#### 12.1 Config Root — ReadyCheck + Crossbar + Palette Manager Tabs [SURVIVED from pr/13 + 1.8.0 ReadyCheck]

- **What:** `config.lua` — Crossbar tab, Palette Manager routing, smart window-sizing (independent convergence with 1.8.0). Retains 1.8.0 ReadyCheck tab + dispatch. Non-blocking profile modals (pr/20).
- **Files:** `config.lua` [modified]
- **Depends on:** 3.1, 2.10
- **1.8.0 architectural notes:** Removed legacy `pendingResetConfigWindow` + `config.ResetConfigWindowPosition` shim.
- **Recommended slice:** `pr/02-foundational-compat`, `pr/28-cursor-visibility-popup-ux`
- **Open questions:** None.

---

#### 12.2 Hotbar Config (Refactored, Crossbar-Separated) [SURVIVED from pr/22/pr/15]

- **What:** `config/hotbar.lua` Ferris overlay. Three shared-control helpers: `DrawSharedDisableXiMacrosControls`, `DrawSharedSkillchainHighlightControls`, `DrawLogPaletteNameCheckbox`. AlwaysClamp on Rows/Columns. Magic Burst + skillchain color pickers. Unified palette create/rename modal for hotbar AND crossbar.
- **Files:** `config/hotbar.lua` [modified]
- **Depends on:** 2.10, 8.4
- **1.8.0 architectural notes:** Retains 1.8.0 Show Stack Quantity checkbox. Ferris kept Slot Y Padding slider.
- **Recommended slice:** `pr/19-crossbar-settings`
- **Open questions:** Remove Slot Y Padding slider?

---

#### 12.3 Crossbar Config Files [SURVIVED from pr/16/pr/19/pr/21/pr/23]

- **What:** `config/crossbar.lua` — sidebar entry shell. `config/crossbar_settings.lua` — 70 KB full crossbar settings: controller layout, palettes, visuals, double-tap preview, disable-in-menu, palette scope icon theme.
- **Files:**
  - `config/crossbar.lua` [new]
  - `config/crossbar_settings.lua` [new]
- **Depends on:** 12.2 (shared helpers via require)
- **1.8.0 architectural notes:** Pure imgui; no gdi.
- **Recommended slice:** `pr/19-crossbar-settings`
- **Open questions:** None.

---

#### 12.4 Components — MANAGER_BUTTON_STYLE [SURVIVED from pr/22]

- **What:** `MANAGER_BUTTON_STYLE` table + 4 push/pop helpers + `DrawStyledTab` variant parameter in components.lua.
- **Why:** Consistent styled tabs/buttons in Palette Manager and config UI.
- **Files:** `config/components.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Zero overlap with 1.8.0's slider changes (~line 400–700); Ferris additions at ~line 852+.
- **Recommended slice:** fold into `pr/13-palette-manager-ui`
- **Open questions:** None.

---

#### 12.5 AlwaysClamp Sliders [NEW fix] — see 0.17

---

#### 12.6 Non-Blocking Profile Modals [SURVIVED from pr/20] _(header reconstructed by parent agent)_

- **What:** Profile create/rename/delete/duplicate modals in `config.lua` converted from blocking `imgui.OpenPopupModal` to non-blocking `BeginPopupModal` flow, matching Palette Manager pattern (pr/22). Hardware cursor remains visible during prompts; user can still pan camera / move during profile management.
- **Why:** Blocking modals hid the hardware cursor and froze background interaction; matches the pr/22 palette manager popup pattern for consistent UX.
- **Files:**
  - `config.lua` [modified] — profile modal flow
- **Depends on:** None
- **1.8.0 architectural notes:** Matches Palette Manager non-blocking popup pattern (pr/22).
- **Recommended slice:** `pr/28-cursor-visibility-popup-ux`
- **Open questions:** `config/global.lua` does not appear in the hash-modified set vs 1.8.0 — verify whether pr/20 global popup changes are present or were absorbed elsewhere.

---

### Group 13: Handlers & Libs

---

#### 13.1 Handler Overlays — actiontracker, debuffhandler, petbuffhandler [SURVIVED, direct overlays]

- **What:** Ferris-only modifications to three handler files. 1.8.0 did not touch them. No GDI references.
- **Why:** Ferris-specific buff/debuff/action tracking extensions carried forward unchanged.
- **Files:**
  - `handlers/actiontracker.lua` [modified]
  - `handlers/debuffhandler.lua` [modified]
  - `handlers/petbuffhandler.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Safe direct overlay (byte-identical between 1.7.5 and 1.8.0 for these files' base).
- **Recommended slice:** fold into `pr/02-foundational-compat`
- **Open questions:** None — content is small; exact behavioral delta vs 1.8.0 not individually documented in migration plan.

---

#### 13.2 Status Handler — Level Sync + Encoding Path [SURVIVED from pr/14/pr/17 area]

- **What:** Level Sync buff detection (`LEVEL_SYNC_BUFF_ID = 269`), transition-detection block clearing playerdata + slotrenderer availability caches. Encoding import uses `libs.encoding` (not deprecated gdifonts path).
- **Why:** Availability caches must invalidate when Level Sync toggles.
- **Files:**
  - `handlers/statushandler.lua` [modified]
- **Depends on:** 7.3
- **1.8.0 architectural notes:** Ferris overlay with 1.8.0 encoding rename applied.
- **Recommended slice:** fold into `pr/06-playerdata-show-all`
- **Open questions:** None.

---

#### 13.3 Helpers — ApplyWindowPosition Return Semantics [SURVIVED from pr/25]

- **What:** `ApplyWindowPosition` returns true/false indicating whether position was applied this frame. Doc comment explaining return semantics. Used by party list align-bottom logic.
- **Why:** Callers can distinguish load/relog apply from user drag.
- **Files:**
  - `handlers/helpers.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Happy convergence — Ferris and 1.8.0 independently added return values; kept 1.8.0 file + Ferris doc comment.
- **Recommended slice:** fold into `pr/27-party-list-align-bottom`
- **Open questions:** None.

---

#### 13.4 ImGui Compat — Focus/Cursor Recovery [SURVIVED from pr/20]

- **What:** `handlers/imgui_compat.lua` — compatibility shim for Ashita 4.3 vs 4.16. Focus-regain cursor recovery. Used by pettarget cluster drag hover detection.
- **Why:** Cross-version ImGui behavior differences; alt-tab cursor fix support.
- **Files:**
  - `handlers/imgui_compat.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Ferris-only-modified file; safe overlay.
- **Recommended slice:** `pr/28-cursor-visibility-popup-ux`
- **Open questions:** None.

---

#### 13.5 Libs — Target Subtarget Detection [SURVIVED from pr/14]

- **What:** `libs/target.lua` — subtarget-active detection treats standalone subtarget as active even without primary target.
- **Why:** Universal 2 Hour targeting UX matches in-game behavior for `/ja` bind resolution.
- **Files:**
  - `libs/target.lua` [modified]
- **Depends on:** 4.4
- **1.8.0 architectural notes:** Ferris-only-modified; safe overlay.
- **Recommended slice:** fold into `pr/03-shared-macro-store`
- **Open questions:** None.

---

#### 13.6 Libs — Drawing Move Anchor Top Side [SURVIVED from pr/23]

- **What:** `libs/drawing.lua` — `DrawMoveAnchor` gains `anchorSide='top'` option with `windowWidth` for centering above target window.
- **Why:** Double-tap preview windows need drag handle above the preview, not to its left.
- **Files:**
  - `libs/drawing.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Small surgical addition to Ferris-extended drawing lib.
- **Recommended slice:** fold into `pr/17-crossbar-doubletap-preview`
- **Open questions:** None.

---

#### 13.7 Libs — Dragdrop Deferred Drops [SURVIVED from pr/16] — see also 0.15

- **What:** Full deferred drop system in `libs/dragdrop.lua`. Re-applied 1.8.0 simplification of inline tooltip rendering (centralized in slotrenderer.FlushTooltip).
- **Files:**
  - `libs/dragdrop.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** File shrunk vs Ferris 1.7.5 tree but still +3 KB over 1.8.0 base.
- **Recommended slice:** fold into `pr/18-crossbar-edit-palette-draft`
- **Open questions:** None.

---

#### 13.8 Libs — TextureManager Custom Icon No-Eviction [SURVIVED + extended]

- **What:** Ferris `custom_icons.maxSize = 0` no-eviction tweak (prevents macro picker stutter). Extended with public `M.DeferRelease(value)` (see 0.2).
- **Files:**
  - `libs/texturemanager.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Kept 1.8.0 deferred-release system as base; Ferris tweak + DeferRelease layered on top.
- **Recommended slice:** `pr/02-foundational-compat` (DeferRelease); fold no-eviction into `pr/29-misc-assets`
- **Open questions:** None.

---

#### 13.9 Hotbar Init — FinalizeFrame, Menu-Hide Split, Zone/Job Hooks [SURVIVED from pr/13/pr/16]

- **What:** `M.FinalizeFrame()` for deferred drag/drop. Separated hotbar vs crossbar menu-hide logic. `GetCrossbarDisableXiMacrosEffective()`. `lastPaletteVisualRefreshSig` dedup. `ValidatePalettesForJob` with `applyDefaultCrossbarScope`. Universal 2hr reset/sync on zone/job change. `MigratePetAwareSlotStorageKeys` defensive call.
- **Why:** Central hotbar module orchestration for crossbar separation and macro lifecycle.
- **Files:**
  - `modules/hotbar/init.lua` [modified]
- **Depends on:** 1.3, 0.15, 4.4
- **1.8.0 architectural notes:** 1.8.0's `AnyBarIsPetAware()` optimization preserved alongside Ferris dedup.
- **Recommended slice:** distribute into `pr/02-foundational-compat`, `pr/18-crossbar-edit-palette-draft`
- **Open questions:** None.

---

#### 13.10 Hotbar Controller — XInput Routing [SURVIVED from pr/19/pr/21 + 0.4]

- **What:** Full crossbar controller input routing. Menu block when `crossbarDisableInMenu`. R1 double-tap cpal restore. L1/R1 shoulder latching fix. Palette cycle on L1/R1. Scope toggle on R1 edge.
- **Why:** Core crossbar gameplay input layer.
- **Files:**
  - `modules/hotbar/controller.lua` [modified]
- **Depends on:** 2.3, 2.7, 0.4
- **1.8.0 architectural notes:** Ferris-only-modified file; safe overlay.
- **Recommended slice:** `pr/15-crossbar-cpal-r1-return`, `pr/16-crossbar-game-menu-block`
- **Open questions:** None.

---

#### 13.11 Hotbar Display — Keyboard Hotbar Path [SURVIVED from pr/07/pr/16, reworked]

- **What:** `display.lua` Ferris additions on 1.8.0 perf base: macro JA badge cache suffix, `GetBindIcon` cache-miss path, mpCostAnchor topLeft default, skillchain prediction for BP+macros, `RefreshCachedLists` at DrawWindow top, Magic Burst dispatch (0.1), deferred icon cache clear via DeferRelease (0.2).
- **Why:** Keyboard hotbar slot rendering with Ferris macro/palette/sc/MB integration.
- **Files:**
  - `modules/hotbar/display.lua` [modified]
- **Depends on:** 7.1, 8.1, 8.2, 0.2
- **1.8.0 architectural notes:** 1.8.0 reusable `slotParams`/`slotInteraction` tables preserved.
- **Recommended slice:** `pr/09-hotbar-display`
- **Open questions:** None.

---

#### 13.12 Hotbar ActionDB Performance Helpers [NEW — audit pass, undocumented slice]

- **What:** `actiondb.lua` modified vs 1.8.0. Added `GetWeaponSkillAbilityIds()` lazy session-cached list. Used by playerdata WS scans and actions item icon resolution.
- **Why:** Collapse O(1024) ability scans to O(1) or O(~50–100) per cache miss.
- **Files:**
  - `modules/hotbar/actiondb.lua` [modified]
- **Depends on:** None
- **1.8.0 architectural notes:** Both 1.8.0 and Ferris kept actiondb but neither originally propagated it into playerdata's scans; audit pass fixed this.
- **Recommended slice:** fold into `pr/06-playerdata-show-all`
- **Open questions:** Confirm full diff scope — migration plan mentions helper but not all call-site wiring.

---

#### 13.13 Hotbar Palette State Module [SURVIVED from old group A + pr/02/pr/13/pr/16/pr/21]

- **What:** `palette.lua` — +55 KB expansion. Full crossbar palette state/storage: universal palettes, segment override hooks, cpal anchor API, CLI preview state, copy between job/global, rename/delete sync, cycle ordering, SJ-only palette lists.
- **Why:** Central palette state machine for both hotbar and crossbar.
- **Files:**
  - `modules/hotbar/palette.lua` [modified]
- **Depends on:** 2.1
- **1.8.0 architectural notes:** Ferris-only-modified file; safe overlay. No gdi references.
- **Recommended slice:** `pr/21-segment-overrides-palette-hooks` (+ cpal pieces in `pr/15-crossbar-cpal-r1-return`)
- **Open questions:** None.

---

#### 13.14 JSON Library [SURVIVED from pr/13]

- **What:** `libs/json.lua` — rxi's json.lua (MIT). Used by palette_json export/import.
- **Why:** Structured profile backup/transfer serialization.
- **Files:**
  - `libs/json.lua` [new]
- **Depends on:** None
- **1.8.0 architectural notes:** Drop-in; no render code.
- **Recommended slice:** fold into `pr/12-profile-json`
- **Open questions:** None.

---

### Group 14: Assets

---

#### 14.1 Palette Manager Status Icons [NEW path — see 3.2]

- **Files:** `assets/checkmark.png` [new], `assets/x.png` [new]
- **Recommended slice:** `pr/13-palette-manager-ui`

---

#### 14.2 SMN / Pet / Status Assets [SURVIVED from pr/08 — see 5.7]

- **Files:** `assets/pets/bloodpact.png`, `assets/pets/ward.png`, `assets/pets/avatars/*.png`, `assets/pets/spirits/*.png`, `assets/hotbar/SMN/AvatarsFavor.png`, `assets/status/Tetsouou/35.png`
- **Recommended slice:** `pr/23-smn-assets`

---

#### 14.3 Custom Item Icon PNGs (25 files) [NEW vs 1.8.0]

- **What:** 25 item PNGs under `assets/hotbar/items/`. None existed in pristine 1.8.0 (1.8.0 had 0 item icons in that folder). Includes ids from old pr/08/pr/16 manifests plus additional ids.
- **Why:** Hotbar/macro display art for specific item ids.
- **Files:** `assets/hotbar/items/*.png` (25 files — see hash-comparison added list)
- **Depends on:** 5.7, 7.4 (icon resolution)
- **1.8.0 architectural notes:** Phase 1 icon overlap audit with `submodules/xiui-icons/` skipped at user request.
- **Recommended slice:** `pr/29-misc-assets`
- **Open questions:** Some old-manifest item ids (04378, 18600, 21759, 61467) not re-added — intentional or missing?

---

#### 14.4 Assets NOT Forward-Ported from 1.7.5 Git HEAD [aggregate — not 1.8.0 deletions]

- **What:** ~39 item PNGs, 8 slot-type badge PNGs (`assets/icons/`), 28 ClassicFFXIV job icon PNGs — present in 1.7.5-era git commit, never in 1.8.0, not in current working tree.
- **Why:** Personal/custom set; ClassicFFXIV intentionally excluded from public dropdown; slot-type badges obsolete on imtext path.
- **Recommended slice:** none (do not ship unless user explicitly restores)
- **Open questions:** User to manually copy any still-wanted custom icons per Phase 1.6 skip note.

---

### Group 15: Pure 1.8.0 Features (not Ferris — retained unchanged)

These ship with the 1.8.0 baseline and are NOT Ferris additions. Listed for slice-planning clarity so Ferris PRs don't accidentally revert them.

---

#### 15.1 ReadyCheck Module [1.8.0 upstream — no Ferris changes]

- **What:** Full ready check module with UI, config, 4 WAV sounds, text_in handler.
- **Files:** `config/readycheck.lua`, `modules/readycheck/init.lua`, `modules/readycheck/ui.lua`, `modules/readycheck/sound/*.wav`
- **Recommended slice:** do NOT include in Ferris pr/* slices (already in 1.8.0 baseline)
- **Open questions:** Smoke-tested on Horizon?

---

#### 15.2 ImText / FontConst / Encoding [1.8.0 upstream]

- **What:** `libs/imtext.lua`, `libs/fontconst.lua`, `libs/encoding.lua` — core 1.8.0 render layer.
- **Recommended slice:** baseline only
- **Open questions:** None.

---

#### 15.3 Submodule xiui-icons [1.8.0 upstream — documentation/source only]

- **What:** 222 community icons under `submodules/xiui-icons/`. NOT a runtime path — runtime loads from `assets/hotbar/`.
- **Recommended slice:** baseline only
- **Open questions:** Icon overlap audit still pending per user request.

---

## Old 25-Slice Status Table

| Old slice | Brief | Status | New slice(s) | Notes |
|---|---|---|---|---|
| pr/01-segment-overrides-data | segmentOverrides storage, resolution, defaults | **SURVIVED + REWORKED** | `pr/20-segment-overrides-data` | data.lua 1116→2639 lines; imtext-era draft layer |
| pr/02-segment-overrides-palette-hooks | palette rename/delete sync, copy universal↔job | **SURVIVED** | `pr/21-segment-overrides-palette-hooks` | palette.lua full Ferris scope intact |
| pr/03-segment-overrides-edit-full-palette-ui | EFP UI, copy palette flow, crossbar preview hooks | **SURVIVED + REWORKED** | `pr/18-crossbar-edit-palette-draft`, `pr/22-segment-overrides-efp-ui` | GDI slot resources → imtext; 6 editor public APIs ported |
| pr/04-smn-horizon-bloodpacts-data | blood pact tables + regen script | **SURVIVED** | `pr/04-smn-bloodpacts-data` | All 3 DB files + gen script confirmed present |
| pr/05-smn-petregistry-bloodpacts | petregistry merge + lookup | **SURVIVED** | `pr/04-smn-bloodpacts-data` | Fold with pr/04 data slice |
| pr/06-smn-actions-bloodpacts | BP action resolution, icons, recast | **SURVIVED + REWORKED** | `pr/05-smn-actions-bloodpacts` | 1.8.0 lazy recast + Ferris sniffers merged |
| pr/07-hotbar-slotrenderer-bloodpact-and-palette-clip | slot overlays, UTH, editor clip | **SURVIVED + REWORKED** | `pr/07-slotrenderer-uth-skillchain` | Complete imtext port; largest render change |
| pr/08-smn-bloodpact-assets | SMN/ward/item icon PNGs | **SURVIVED (partially)** | `pr/23-smn-assets`, `pr/29-misc-assets` | Core SMN assets present; some old item PNGs not re-added |
| pr/09-horizon-static-databases | abilities, ws_weapon_types, spell_omissions | **SURVIVED** | `pr/01-horizon-static-databases` | Pure data; land first |
| pr/10-playerdata-show-all-and-spell-sort | Show All lists, spell sort, retail-only JAs | **SURVIVED + ENHANCED** | `pr/06-playerdata-show-all` | + effective levels, actiondb perf, ABILITY_TYPE enum |
| pr/11-macro-editor-show-all-and-spell-colors | macro editor Show All, colors, Copy, JA badge | **SURVIVED** | `pr/11-macro-editor` | macropalette 6341 lines; zero GDI post-overlay |
| pr/12-xiui-ws-cache-init | WS cache on login; crossbar-only packet handlers | **SURVIVED** | `pr/02-foundational-compat` | Defensive pcall on SetKnownWeaponskills |
| pr/13-profile-json-and-hotbar-crossbar | JSON export/import, independent enable toggles | **SURVIVED + REWORKED** | `pr/12-profile-json`, `pr/02-foundational-compat` | Import refresh hooks wired |
| pr/14-shared-macro-and-dual-slot-bindings | shared macro store, dual arms, Universal 2hr | **SURVIVED** | `pr/03-shared-macro-store` | |
| pr/15-pet-palette-avatars-elementals-macro-custom-types | pet palette types, EFP tabs, BST cost, custom types | **SURVIVED** | `pr/24-pet-palette-allowlist` | |
| pr/16-crossbar-edit-palette-draft-live-dragdrop | EFP draft, Move Macro, deferred drop, cpal CLI | **SURVIVED + REWORKED** | `pr/18-crossbar-edit-palette-draft`, `pr/15-crossbar-cpal-r1-return` | Largest crossbar UX slice |
| pr/17-party-list-buff-split-indexing | buff 1-based iteration fix | **SURVIVED** | `pr/26-party-list-buff-split` | ⚠️ Also 1.8.0 upstream bug; submit to tirem |
| pr/18-pet-bar-resize-anchor-and-target-snap | resize anchor, snap, cluster drag | **SURVIVED** | `pr/25-pet-bar-resize-anchor` | Layered on 1.8.0 imtext petbar rewrite |
| pr/19-crossbar-game-menu-block | disable crossbar in menus | **SURVIVED + FIXED** | `pr/16-crossbar-game-menu-block` | Visual dim added during migration (was missing) |
| pr/20-cursor-visibility-popup-ux | alt-tab cursor, non-blocking popups | **SURVIVED** | `pr/28-cursor-visibility-popup-ux` | config/global.lua presence uncertain |
| pr/21-crossbar-cpal-r1-return | cpal anchor, pulsing R1, R1 double-tap return | **SURVIVED** | `pr/15-crossbar-cpal-r1-return` | + L1 latching fix (0.4) |
| pr/22-crossbar-palette-list-ux | checkmark/X icons, +M button, non-blocking create | **SURVIVED + PATH FIXED** | `pr/13-palette-manager-ui` | Assets at assets/checkmark.png, assets/x.png |
| pr/23-crossbar-doubletap-preview | floating L2x2/R2x2 preview windows | **SURVIVED + PERF** | `pr/17-crossbar-doubletap-preview` | MakePreviewSettings cache, early-exit |
| pr/24-macro-editor-spell-list-fixes | missing spells Show-All-off, duplicate entries | **SURVIVED** | `pr/11-macro-editor` | Fold with pr/11 |
| pr/25-party-list-align-bottom-anchor | align-bottom drift on reload/drag/switch | **SURVIVED** | `pr/27-party-list-align-bottom` | SaveSettingsOnly fix retained |

**Summary:** 25/25 SURVIVED. 0 OBSOLETED by 1.8.0. ~15 REWORKED for imtext architecture.

---

## Recommended New Slice Ordering (29 slices, with dependency rationale)

```
pr/01-horizon-static-databases
  Pure data files (horizon_abilities, ws_weapon_types, horizon_spell_omissions,
  horizon_retail_only_job_abilities). No runtime deps. Safe to land first.
  Enables: pr/04, pr/05, pr/06, pr/10, pr/11.

pr/02-foundational-compat
  XIUI.lua entry point (packet handlers, cpal commands, SaveCurrentProfileFileToDisk,
  post-load hooks, crossbarEnabled, cursor reset, palette manager draw order).
  Settings: user.lua core keys, migration.lua core steps, factories partial.
  Handlers: actiontracker, debuffhandler, petbuffhandler, statushandler encoding.
  TextureManager.DeferRelease (0.2). Hide-on-menu split (1.3). WS cache init (1.8).
  MUST precede all feature slices.

pr/03-shared-macro-store
  core/shared_macro_store.lua, dual slot bindings migration, universal_two_hour.lua,
  macro_global_defaults.lua, macro_xiui_defaults.lua, libs/target.lua.
  Depends on: pr/02.

pr/04-smn-bloodpacts-data
  horizon_bloodpacts.lua, horizon_bloodpacts_xiui.lua, horizonspells.lua extensions,
  petregistry.lua merge. Depends on: pr/01.

pr/05-smn-actions-bloodpacts
  actions.lua BP resolution, recast.lua sniffers, macroparse.lua.
  Depends on: pr/04.

pr/06-playerdata-show-all
  playerdata.lua (Show All, ABILITY_TYPE enum, Horizon filters), equipment_ws.lua,
  actiondb.lua perf helpers, effective-level IsActionAvailable fix (0.8),
  Level Sync cache invalidation.
  Depends on: pr/01, pr/04.

pr/07-slotrenderer-uth-skillchain
  slotrenderer.lua core imtext port: UTH rainbow/glow, skillchain highlight,
  editor clip/labels, dropPriority, labelAboveSlot, unavailable Lv##/X (0.5),
  frame availability snapshot (0.6), crossbar overlay drawList z-order (2.11),
  color helper dedup (0.16 partial).
  MUST precede: pr/08, pr/09, pr/14, pr/18 (all callers depend on DrawSlot API).

pr/08-magic-burst-highlight
  skillchain.lua MB state machine, slotrenderer MB border, display+crossbar wiring,
  factories defaults, config UI. Depends on: pr/07, pr/05.

pr/09-hotbar-display
  display.lua keyboard hotbar path (non-crossbar-specific slot rendering).
  Depends on: pr/07, pr/08.

pr/10-macro-system
  macro_palette_buckets.lua, macroparse (if not in pr/05), seed migrations.
  Depends on: pr/03.

pr/11-macro-editor
  macropalette.lua + macropalette_macroeditor.lua, spell dedup fix (pr/24).
  Depends on: pr/06, pr/10.

pr/12-profile-json
  palette_json.lua, libs/json.lua, config.lua Profiles Backup/Transfer,
  palette.lua invalidation hooks.
  Depends on: pr/11, pr/02.

pr/13-palette-manager-ui
  palettemanager.lua expansion, checkmark/x assets, +M button, non-blocking popups,
  config/components.lua MANAGER_BUTTON_STYLE.
  Depends on: pr/11, pr/12.

pr/14-crossbar-core
  crossbar.lua foundation: visual cutoff fix (0.9), WindowPadding zero (2.9),
  shared-expanded-bar (2.6), inactive-side dim (2.8), palette scope icon (0.18),
  palette count fix (0.14), playerdata cache warm (0.7), SMN SC routing (0.3),
  movement lock (1.2), labelAboveSlot wiring.
  MUST precede: pr/15, pr/16, pr/17, pr/18.

pr/15-crossbar-cpal-r1-return
  cpal anchor API, R1 double-tap restore, pulsing R1 indicator, L1 latching (0.4),
  /xiui cpal command wiring.
  Depends on: pr/14, pr/02.

pr/16-crossbar-game-menu-block
  gamestate.lua, controller menu block, crossbar visual dim (0.12).
  Depends on: pr/14.

pr/17-crossbar-doubletap-preview
  DrawDoubleTapPreviewWindow, MakePreviewSettings cache, drawing.lua anchorSide top,
  crossbar_settings preview UI.
  Depends on: pr/14.

pr/18-crossbar-edit-palette-draft
  EFP draft layer, 6 editor public functions, deferred drops (0.15),
  double-click new macro (0.11), Move Macro (4.8), macropalette/init hooks.
  Depends on: pr/13, pr/14, pr/07.

pr/19-crossbar-settings
  config/crossbar.lua, config/crossbar_settings.lua, config/hotbar.lua refactor,
  config/efp_pets_tab.lua, ClassicFFXIV removal (0.13), shared skillchain/MB controls (8.4),
  AlwaysClamp sliders (0.17 partial).
  Depends on: pr/14, pr/18.

pr/20-segment-overrides-data
  data.lua segmentOverrides storage + factories defaults.
  Depends on: pr/14.

pr/21-segment-overrides-palette-hooks
  palette.lua rename/delete sync, copy universal↔job, cycle ordering.
  Depends on: pr/20.

pr/22-segment-overrides-efp-ui
  palettemanager segment override UI rows, crossbar editor segment integration.
  Depends on: pr/18, pr/21.

pr/23-smn-assets
  bloodpact.png, ward.png, AvatarsFavor.png, Tetsouou/35.png, avatar/spirit PNGs.
  Depends on: pr/04 (logical grouping only; no code dep).

pr/24-pet-palette-allowlist
  pet_palette_allowlist.lua, petpalette.lua, BST jug cost in castcost/display.lua.
  Depends on: pr/04.

pr/25-pet-bar-resize-anchor
  petbar data/display/pettarget, config/petbar.lua anchor UI, migration.
  Depends on: pr/02.

pr/26-party-list-buff-split
  partylist/display.lua 1-based buff iteration fix.
  No deps. Can land early; independent of hotbar work.

pr/27-party-list-align-bottom
  helpers.lua return semantics, partylist align-bottom anchor math.
  Depends on: pr/26 (same file, sequential review).

pr/28-cursor-visibility-popup-ux
  imgui_compat focus recovery, config.lua non-blocking profile modals.
  Depends on: pr/02.

pr/29-misc-assets
  25 item icon PNGs under assets/hotbar/items/, customiconresolve/iconmatch/textures.
  Depends on: none (assets can ship with their consumer slices instead if preferred).
```

**Ordering principles:**
1. Pure data first (pr/01) — zero conflict surface.
2. Foundational entry point + settings + DeferRelease before any module touching caches (pr/02).
3. slotrenderer (pr/07) before any DrawSlot caller (pr/08–09, pr/14, pr/18).
4. crossbar-core (pr/14) before crossbar UX slices (pr/15–18).
5. macro system (pr/10–11) before palette manager (pr/13) and EFP (pr/18).
6. segment overrides (pr/20–22) after EFP infrastructure exists.
7. Independent fixes (party list pr/26–27, cursor pr/28) can land anytime after pr/02.

---

## Aggregate Deletions (assets etc.)

**Important distinction:** Ferris deleted **0 files** from the pristine 1.8.0 baseline. The following are 1.7.5-era git-tracked assets that were **never in 1.8.0** and were **not forward-ported** into the working tree:

| Category | Approx count | Path | Notes |
|---|---|---|---|
| Personal item icons | ~39 PNGs | `assets/hotbar/items/` | User's custom 1.7.5 set; 25 different item icons re-added instead |
| Slot-type badge icons | 8 PNGs | `assets/icons/` (equip, item, ja, ma, macro, pet, sync, ws) | Obsolete — old GDI renderer badges; imtext path doesn't use them |
| ClassicFFXIV job icons | 28 PNGs | `assets/jobs/ClassicFFXIV/` | User-custom theme; intentionally removed from public dropdown (0.13) |
| gdifonts submodule | 8 files | `submodules/gdifonts/` | Removed by 1.8.0 upstream; replaced by libs/imtext.lua + libs/encoding.lua |

**Working tree vs 1.8.0 asset additions:**
- 25 item PNGs in `assets/hotbar/items/` (new to Ferris layer)
- 2 status UI PNGs: `assets/checkmark.png`, `assets/x.png`
- Full pet avatar/spirit sets retained from 1.8.0 baseline
- SMN-specific assets retained/confirmed: bloodpact.png, ward.png, AvatarsFavor.png, Tetsouou/35.png

**Not enumerated individually per user request.** Phase 1.6 icon overlap audit with `submodules/xiui-icons/` was skipped — user to copy any remaining wanted custom icons manually.

---

## Open Questions for the User

1. **`petBarReadyBaseRecast` default** — Migration plan notes Horizon uses 45s but 1.8.0 factory defaults to 30. Was this patched in `core/settings/factories.lua` or `user.lua`? If not, should the new slice set it to 45?

2. **`config/global.lua` pr/20 changes** — Hash comparison shows `config/global.lua` is NOT modified vs 1.8.0. Were the non-blocking global config popup changes from old pr/20 actually ported, or only config.lua profile modals?

3. **`HzLimitedMode` gates sweep** — Plan called for auditing all `HzLimitedMode` gates post-migration. Known gate: `showTargetBarCastBar` in action packet handler. Were others identified? Should any be removed for Horizon?

4. **`actiondb.lua` slice ownership** — Modified vs 1.8.0 with new perf helpers but no dedicated plan section. Confirm `pr/06-playerdata-show-all` is the right owner.

5. **Missing pr/08 item icons** — `04378.png`, `18600.png`, `21759.png`, `61467.png` were in old pr/08 manifest but not in current working tree and not in 1.8.0. Covered by xiui-icons submodule, intentionally dropped, or should be restored to `assets/hotbar/items/`?

6. **Macro editor smoke test** — Zero GDI references confirmed by scan, but has the 86 KB macro editor been opened in-game post-imtext port? (Icon picker, save, JA badge sync, Show All lists.)

7. **`palette_json.lua` end-to-end test** — Export/import round-trip with macros + palettes + crossbar layouts: tested or still pending per plan D.13?

8. **`AvatarsFavor.png` loader path** — Asset confirmed present. Verify runtime resolution in `textures.lua` or `actions.lua` resolves correctly on 1.8.0 load path.

9. **ReadyCheck on Horizon** — Pure 1.8.0 feature retained unchanged. Does Horizon send the text_in packets ReadyCheck expects?

10. **Slot Y Padding slider** — Ferris kept this slider; 1.8.0 removed it (independent bar positioning). Still needed, or remove during crossbar-settings slice?

11. **ClassicFFXIV PNG files in git** — 28 files show as deleted in git status (1.7.5 commit). Confirm: leave deleted, or restore locally-only outside public slices?

12. **New slice count (29)** — Acceptable for review, or aggressively fold (e.g., merge pr/26+27, pr/23+29, pr/20+21)?

13. **Upstream party-list bug (pr/17)** — Submit fix to tirem/XIUI separately from Ferris fork slices?

14. **Double-tap preview polish details** — Plan mentions: no qty/MP in preview, keep cooldowns, allow SC + MB borders. Confirm these are implemented in current `crossbar.lua` preview path.

15. **Undocumented modified files** — Hash diff found exactly 43 modified Lua files; all are accounted for in this inventory except potential minor deltas in files where plan references are narrative-only (e.g., exact scope of `handlers/actiontracker.lua` changes). Any other files you expect to differ that aren't listed?
