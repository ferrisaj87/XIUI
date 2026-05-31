# XIUI 1.8.0 Migration Plan

**Goal:** Forward-port the custom feature set in `XIUIFerrisChanges` (forked from upstream `1.7.5`) onto upstream `XIUI1.8.0`, which is a substantial architectural rewrite focused on performance.

**Sources used for this analysis (all sibling folders in `addons/`):**
- `XIUI1.7.5` — original upstream baseline (pre-fork)
- `XIUI1.8.0` — new upstream release (target)
- `XIUIFerrisChanges` — snapshot of the user's fork as of 5/22 1:13 PM
- `XIUI` — the live working tree (= continuation of Ferris's fork)

> **Heuristic used:** all per-file diffs ran with `git diff --no-index --ignore-all-space --ignore-blank-lines` to suppress CRLF noise. "Truly modified" counts exclude whitespace/encoding-only deltas.

---

## Progress log (running record)

> Append-only. Most recent at the bottom. Each entry: phase, what we did, what we found, what surprised us.

### 2026-05-22 — Phase 0 (tree setup)
- Created safety branch `backup/master-before-1.8.0` at `b73fb6a` (last Ferris-1.7.5-fork commit). Full rollback available via `git reset --hard backup/master-before-1.8.0`.
- Wiped `XIUI/` working tree except `.git/`; preserved Ferris-local metadata (`.cursor/`, `.gitignore`, `MIGRATION_1.8.0_PLAN.md`, gitignored `scripts/*` workflow files) to `%TEMP%` first, then restored after copy.
- Copied `XIUI1.8.0/*` into `XIUI/`. Confirmed `addon.version = '1.8.0'` post-swap.
- **Discovery:** new submodule `submodules/xiui-icons/` ships 222 community icons in 1.8.0. **NOT a runtime path** — `modules/hotbar/textures.lua` only loads from `assets/hotbar/`. The submodule is documentation/source.
- **Correction:** `config/palettemanager.lua` is *modified-by-Ferris*, not new (existed as 27.9 KB stub in both 1.7.5 and 1.8.0; Ferris expanded to 146 KB).

### 2026-05-22 — Phase 1 (Ferris additions onto 1.8.0)
- **P1.1 — Restored 4 tracked scripts** from `backup/master-before-1.8.0`: `bst_retail_sheet_sync.py`, `feature-pr-manifest.ps1`, `gen_horizon_bloodpacts.py`, `strip-nerf-deltas.ps1`.
- **P1.2 — Copied 12 pure-data files**: `libs/json.lua`, 6 horizon DBs (`horizon_abilities`, `horizon_bloodpacts`, `horizon_bloodpacts_xiui`, `horizon_retail_only_job_abilities`, `horizon_spell_omissions`, `ws_weapon_types`), 5 macro/palette helpers (`universal_two_hour`, `macro_global_defaults`, `macro_palette_buckets`, `macro_xiui_defaults`, `pet_palette_allowlist`).
- **P1.3 — Copied 6 logic files**: `core/shared_macro_store.lua` (11.7 KB), `modules/hotbar/{iconmatch, customiconresolve, equipment_ws, macroparse, palette_json}.lua`. `palette_json.lua` is the 40 KB profile-export/import library.
- **P1.4 — Copied 5 UI files** (4 new + 1 modified-overlay): `config/{crossbar, crossbar_settings (70 KB), efp_pets_tab}.lua`, `modules/hotbar/macropalette_macroeditor.lua` (86 KB, closure-factory pattern), and overlaid `config/palettemanager.lua` (146 KB on top of 1.8.0's 27.9 KB stub).
- **P1.5 — Import audit**: scanned all 23 files. Zero `submodules.gdifonts.*`. Zero `gdi*` / `FontManager` / `create_primitive` patterns. All 30 unique require paths resolve.
- **palettemanager.lua compat check**: 1.8.0's `config/hotbar.lua` only calls `paletteManager.Open()` + `paletteManager.Draw()`; both present in Ferris's expanded version. API-superset. Safe overlay.
- **palettemanager.lua quick health pass**: file is structurally clean, 0 deprecated patterns, 0 debug `print`, 0 TODOs, gated on `windowState.isOpen` (not in per-frame hotpath). Polish opportunities deferred: 10 inner-scoped closures, 8 legacy `imgui.Columns` (could be `imgui.BeginTable`), 55 small string concats in loops. Recommendation: do not touch until Phase 3.
- **P1.6 — Icon overlay-merge: SKIPPED at user request.** User will copy custom icons manually after migration.

### 2026-05-22 — Phase 1.5 (Ferris-only-modified group-A overlay)
- Pre-overlay scan: 10/11 group-A files clean of deprecated patterns. `core/gamestate.lua` "hits" were false positives — they reference Ashita's host `AshitaCore:GetFontManager()` API (autohide-addon integration), not the deprecated XIUI `FontManager`.
- **Verified group-A premise**: ran 1.7.5-vs-1.8.0 semantic diff (`--ignore-all-space --ignore-blank-lines`) on all 11. Confirmed 11/11 are byte-identical between 1.7.5 and 1.8.0 — safe direct overlay.
- Overlaid 11 files. Notable deltas: `palette.lua` +55 KB (Ferris's biggest single expansion — palette state/storage), `petregistry.lua` +24 KB (pet/blood-pact merging), `textures.lua` +6 KB (custom texture resolution), `controller.lua` +5 KB, `petpalette.lua` **-4 KB** (Ferris simplified).
- Post-overlay re-scan: 0 deprecated patterns, 0 missing imports.
- **Phase 1+1.5 final tally**: 22 new + 1 modified-overlay (palettemanager) + 11 group-A overlays + 4 tracked scripts = **38 Ferris files** layered on 1.8.0 baseline.

### 2026-05-22 — Phase 2 (conflict-surface 3-way merges) — IN PROGRESS

**Phase 2.1 — Settings system + root config + components (COMPLETE)**

Established 3-way diff matrix across 1.7.5, 1.8.0, Ferris for 10 settings-related files. Found 5 needed true 3-way merges, 4 were 1.8.0-only changes (no Ferris edits, keep 1.8.0), 1 was no-op.

- **`core/settings/user.lua`** — Surgical merge: kept 1.8.0's 5 additions (`globalScale` rename, `showReadyCheck`, `expBarMasteryMode`, `petTargetBgScale`, `petTargetBorderScale`) and layered 10 Ferris additions (`crossbarEnabled`, `crossbarLockMovement`, 6 macro settings: `macroEditorIconPrefs`, `macroCustomCategories`, `macroCustomNextSeq`, `macroXiuiDefaultsSeeded`, `macroGlobalUniversalTwoHourSeeded`, `macroStorageScope`; plus `petBarResizeAnchor`, `petTargetSnapTopGap`, `petTargetSnapCachedHeight`). Both sides independently converged on removing the per-module `*WindowPosX/Y` block — happy convergence, no merge work needed. Result: 35,505 bytes.
- **`core/settings/factories.lua`** — Overlaid Ferris's full file (massive `createCrossbarDefaults()` rewrite: universal palettes, segmentOverrides, double-tap preview, paletteJobIconTheme, etc.), then re-injected 1.8.0's 3 `showStackQuantity = false` lines. Verified 11 Ferris keys + 3 1.8.0 keys present. Result: 34,034 bytes.
- **`core/settings/migration.lua`** — Discovered `MigrateLegacyPositionFields` exists **byte-identical** in both 1.8.0 and Ferris (independent convergence). Overlaid Ferris's file (has 6 extra migrations: `MigrateCrossbarModuleFlags`, `MigrateHotbarCrossbarLayoutFlags`, `MigrateHotbarShowKeyboardBarsRemoval`, `MigrateCrossbarRemoveDeprecatedMirroredKeys`, `MigrateMacroXiuiDefaults`, `MigrateMacroGlobalUniversalTwoHour` + `EnsureMacroDatabaseCoherence` pre-pass + `MigrateSlotDualMacroBindings`), then injected 1.8.0's `MigrateSlotMacroRefs` function (critical for macroDB-as-source-of-truth slot data) + its `RunStructureMigrations` call, and removed the `barHeight = 20` from the party-list-layout defaults migration. Result: 57,838 bytes.
- **`config/components.lua`** — Zero overlap between sides (1.8.0 touched sliders ~line 400–700, Ferris touched tab styling ~line 852+). Kept 1.8.0's file (slider sites with `ImGuiSliderFlags_AlwaysClamp` + `UpdateUserSettings()` rename), inserted Ferris's `MANAGER_BUTTON_STYLE` table + 4 push/pop helpers + `DrawStyledTab` variant parameter. Result: 36,307 bytes.
- **`config.lua` (root)** — Discovery: Ferris and 1.8.0 **independently implemented near-identical smart-window-sizing logic** (`configJustOpened`, `lastConfigPosX/Y`, `lastConfigSizeW/H`, `configHasBeenOpened`, `SetNextWindowSizeConstraints`). Overlaid Ferris's file (preserves crossbar category + 4 crossbar-tab functions + `OpenCrossbarManagePalettes` / `ToggleCrossbarManagePalettes` / `SetWindowOpen` + `_XIUI_CONFIG_LAST_GEOM` shim), then layered in 1.8.0's `readycheckModule` require + `readyCheck` category + `DrawReadyCheckSettings` + `DrawReadyCheckColorSettings` + dispatch-table entries (5 additions), and removed legacy `pendingResetConfigWindow` + `config.ResetConfigWindowPosition` shim + redundant `UpdateSettings()` after `ResetSettings()` (3 cleanups). Verified no other callers of the removed symbols. Result: 58,315 bytes.
- **Files where Ferris had no changes (kept 1.8.0 as-is, no action):** `core/settings/{modules,updater,colors}.lua`, `core/profile_manager.lua`.
- **`core/settings/init.lua`** — 1.7.5 = 1.8.0 = Ferris (whitespace only). No action.

**Net Phase 2.1 outcome**: 5 conflict-surface files merged, all 1.8.0 architectural improvements (window-position migration, smart-window-sizing, slot macroRef migration, slider clamping, ready check) preserved, all Ferris custom features (crossbar separation, universal palettes, macro storage scope, palette-manager styling, custom categories, etc.) preserved.

**Phase 2.2 — Entry point `XIUI.lua` (COMPLETE)**

Profile: 1.7.5 (69 KB) → 1.8.0 (75 KB, +6 KB / 477 diff lines) → Ferris (94 KB, +25 KB / 648 diff lines). Both sides made substantial changes touching ~10 shared zones (requires, hotbar registration, GetDefaultWindowPositions move, ResetSettings, CenterAllPositions rename, d3d_present, /xiui palette command).

Strategy: start from 1.8.0 (currently in tree, has the structural improvements) and layer Ferris's adds as ~21 surgical edits. Did not overlay-then-patch (Ferris's file was 1.7.5-based and would lose 1.8.0's deferred-update pattern + RecoverAllPositions rename + smart-window-sizing co-implementation).

**Changes applied to `XIUI.lua`:**

1. Added `sharedMacroStore` require + 2 local helpers (`xiuiInvalidateHotbarDataCaches`, `xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad`).
2. Added `paletteManager` require.
3. Removed `hideOnMenuFocusKey = 'hotbarHideOnMenuFocus'` from hotbar registration (Ferris's hotbar/crossbar menu-focus separation).
4. Converted both `settings.load({...})` to `settings.load(T{...})` (typed-table consistency).
5. Added `knownWeaponskills` per-character cache init after `charSettings = settings.load(...)`. **Made defensive** with pcall and `if pd.SetKnownWeaponskills then` guard — since 1.8.0's `playerdata.lua` is still in tree and Ferris's `SetKnownWeaponskills` won't exist until Phase 2.4 merges that module.
6. Added post-load hook trio (`sharedMacroStore.ApplyAfterProfileLoad`, `xiuiInvalidateHotbarDataCaches`, `xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad`) at 3 sites: after the initial `RunStructureMigrations`, inside `ChangeProfile`, and inside the `settings_update` callback.
7. Extended `DuplicateProfile(name)` → `DuplicateProfile(name, options)` with `options.includeMacroLibrary` mode (resets `macroDB`, custom categories, default seeds, and strips palette macro binds when false).
8. Added new `SaveCurrentProfileFileToDisk()` function — shared-macro-scope-aware save that swaps in the frozen `macroDB` snapshot, saves the profile, and persists the live shared library to `SharedMacros.lua`.
9. Replaced 4 direct `profileManager.SaveProfileSettings(config.currentProfile, gConfig)` calls (in `ChangeProfile`, `RecoverAllPositions`, `SaveSettingsToDisk`, `SaveSettingsOnly`) with `SaveCurrentProfileFileToDisk()`. The 2 remaining calls inside `SaveCurrentProfileFileToDisk` itself are correct (they ARE the implementation).
10. `ResetSettings` overhauled to combine 1.8.0's deferred-update pattern with Ferris's post-load hooks. Did **not** include Ferris's `configMenu.ResetConfigWindowPosition()` call (function removed in Phase 2.1 — smart-window-sizing supersedes it).
11. Added `imgui.SetMouseCursor(0)` at start of `d3d_present` frame (alt-tab cursor recovery).
12. Added `paletteManager.Draw()` + `hotbar.FinalizeFrame()` after `configMenu.DrawWindow()` (before `slotrenderer.FlushTooltip()` for correct z-order: config → palette manager → drag finalize → tooltip).
13. Added 4 packet-handler `or gConfig.crossbarEnabled` checks (0x0068 pet sync, action packet skillchain, zone-in job init, zone-out + 0x001B job change).
14. Added `/xiui menuname` debug command (prints current FFXI menu name + container-nav state).
15. Added `/xiui pal` toggle floating Palette Manager (when `#command_args == 2` only — sub-args still route to palette cycling).
16. Modified `/xiui palette` dispatcher to also match `pal` when `#command_args >= 3` (so `/xiui pal next/list/etc` keeps working).
17. Added massive `/xiui cpaledit` + `/xiui cpalette` (with `cpal`/`xcpalette`/`xcpal` aliases) command set — ~350 lines covering list, toggle, scope (job|universal), cycle on|off, global/g/gname, compact MAIN+SUB (e.g. WHMSMN N), explicit `job <JOB>`, and bare-job shorthand. Calls into Ferris's expanded `palette.lua` (already overlaid in Phase 1.5) and `paletteManager` (already overlaid in Phase 1).

**Dependencies verified in-tree**: `handlers/tbar_migration.lua`, `libs/jobs.lua`, `core/shared_macro_store.lua`, `config/palettemanager.lua`, `modules/hotbar/palette.lua` (21 functions confirmed: `BuildPaletteStorageKey`, `BuildUniversalCrossbarStorageKey`, `GetActivePaletteForCombo`, `GetActiveUniversalCrossbarPalette`, `GetCrossbarActiveStorageSubjob`, `GetCrossbarPaletteScope`, `GetCrossbarPaletteNamesForOrderTier`, `GetCrossbarSjOnlyPaletteNamesOrdered`, `GetUniversalCrossbarPaletteNamesOrdered`, `GetUniversalPaletteIncludeInCycle`, `NotifyProfileSettingsLoaded`, `SetActivePaletteForCombo`, `SetActiveUniversalCrossbarPalette`, `SetCpalJobAnchorIfUnset`, `SetCpalUniversalAnchorIfUnset`, `SetCrossbarCliPreview`, `SetCrossbarPaletteScope`, `SetUniversalPaletteIncludeInCycle`, `ToggleCrossbarPaletteScope`, `ValidatePalettesForJob`). `paletteManager.{Open, Draw, ToggleEditFullPaletteForCurrent, ToggleHotbarPaletteManager}` all confirmed.

**Known deferred-until-Phase-2.4 functions** (defensive guards in place): `playerdata.SetKnownWeaponskills`, `data.EnsureMacroDatabaseCoherence`, `data.MigrateSlotDualMacroBindings`, `data.StripPaletteMacroBindsFromSettings`, `data.InvalidateConfigDerivedCaches`, `hotbar.FinalizeFrame`. All call sites use `pcall(require)` or `if mod.Fn then` guards so the addon still loads cleanly before Phase 2.4 merges these modules.

Final `XIUI.lua`: 2,336 lines, 97,357 bytes. **All 21 Ferris additions verified present, all 7 1.8.0 architectural additions verified preserved, 1 explicit removal verified gone (`hotbarHideOnMenuFocus` key).**

**Phase 2.3 — Handlers + libs (COMPLETE)**

Built a more targeted diff matrix for `handlers/` + `libs/`. Original Phase 2 plan flagged 6 handler/lib files; reality was tighter. Findings:

- `handlers/` (8 total files): 4 changed by Ferris (`debuffhandler`, `petbuffhandler`, `actiontracker`, `statushandler`) — first 3 are Ferris-only modifications, `statushandler` had both-sides changes; remaining 4 untouched across all 3 versions (`init`, `petbuffhandler`, `imgui_compat` from Phase 1.5, `helpers` had both-sides change, `tbar_migration` was 1.8.0-only-modified).
- `libs/` (27 → 30 → 28 files): 1.8.0 added 3 new files (`encoding.lua`, `fontconst.lua`, `imtext.lua`) — already in tree. Ferris added 1 new file (`json.lua`) — already overlaid in Phase 1.2. Of files in 1.8.0: `dragdrop` and `texturemanager` had both-sides changes; `statusicons` was 1.8.0-only-modified (keep 1.8.0); `drawing` + `target` already overlaid in Phase 1.5.

**Files merged**:

- **`handlers/statushandler.lua`** — Overlaid Ferris's file (adds Level Sync buff detection: `LEVEL_SYNC_BUFF_ID = 269` constant, `partyBuffListHas` helper, transition-detection block in `ReadPartyBuffsFromPacket` that invalidates `playerdata.ClearCache` + `slotrenderer.ClearAvailabilityCache` on level sync change), then applied 1.8.0's `submodules.gdifonts.encoding` → `libs.encoding` rename. Result: 8,349 bytes.
- **`handlers/helpers.lua`** — Happy convergence: Ferris and 1.8.0 independently added `return true/false` to `ApplyWindowPosition`. Kept 1.8.0's file (already in tree) and added only Ferris's doc comment explaining the return semantics. 1.8.0's cleanup (removed `FontManager`/`ColorCachedFont`/`SetFontsVisible`/`UpdateAllFontOutlineWidths`/`ClearDebuffFontCache`/`debuffTable`/`WindowBackground` re-exports + `windowBackgroundLib` require) preserved.
- **`libs/texturemanager.lua`** — Kept 1.8.0's deferred-release system (`pendingReleases`, `deferRelease`, `FlushPendingReleases` — critical D3D8 safety pattern that prevents `EXCEPTION_ACCESS_VIOLATION` on Ashita 4.16) and layered Ferris's `custom_icons.maxSize = 0` no-eviction tweak (Ferris found LRU evict+reload caused heavy stutter for the macro picker).
- **`libs/dragdrop.lua`** — Overlaid Ferris's file (adds overlapping-zone resolution: `deferredDropCandidates` state, `FlushDeferredDrops` function with `dropPriority` + registration-order tiebreaker — needed for HUD crossbar overlapping the Edit Full Palette preview), then re-applied 1.8.0's simplification of `dragdrop.Render` (removed inline ImGui tooltip rendering with `ACTION_TYPE_LABELS`, `BeginTooltip`, and the text-fallback abbreviation rendering — all of that is now centralized in `slotrenderer.FlushTooltip`). File shrunk from Ferris's 17,966 bytes to 14,350 bytes (still +3 KB over 1.8.0's 12,319).
- **`handlers/{debuffhandler,petbuffhandler,actiontracker}.lua`** — Direct Ferris overlays (1.8.0 didn't touch). All clean of deprecated patterns. +330/+248/+134 bytes vs 1.7.5.
- **`libs/statusicons.lua` + `handlers/tbar_migration.lua`** — 1.8.0-only-modified (Ferris didn't touch). Kept 1.8.0 versions (already in tree).

**Net Phase 2.3 outcome**: 4 conflict-surface files merged, 3 Ferris-only overlays applied, 2 1.8.0-only files kept. Total 9 files handled, zero deprecated patterns introduced.

**Phase 2.4 — Module rewrites (IN PROGRESS)**

Module folder diff matrix (modules/ across 1.7.5 / 1.8.0 / Ferris):
- **57** total 1.8.0 files, **15** unchanged across all 3 versions.
- **14 both-changed** (3-way merge needed): castcost/display.lua, hotbar/{actions,crossbar,data,display,init,macropalette,playerdata,recast,slotrenderer}.lua, partylist/display.lua, petbar/{data,display,pettarget}.lua.
- **7 Ferris-only changed** (all already overlaid in Phase 1.5).
- **19 1.8.0-only changed** (already in tree, kept as-is).
- **2 new in 1.8.0** (`modules/readycheck/{init,ui}.lua` — already in tree).
- **17 new in Ferris** (all already copied in Phase 1, primarily under `modules/hotbar/{database,iconmatch,macroparse,palette_json,macropalette_macroeditor,*}.lua`).

Attack order (by combined LOC delta complexity, lowest first):

**Tier 1 — Light (≤250 complexity) — COMPLETE**:

- **`modules/petbar/data.lua`** (complexity 85) — Surgical Ferris overlay of 6 new state vars onto 1.8.0's Horizon-Burning-Lands jugPets rewrite + GDI-cleanup. Added `petBarSnapTopReferenceY`, `lastPetBarWindowHeight`, `petBarTargetHitRect`, `petBarClusterDragActive`, `petBarSyncResizeAnchorNextFrame`, `lastPetBarTargetWindowHeight` — all needed for cluster-drag and resize-anchor sync between PetBar and PetBarTarget windows.

- **`modules/partylist/display.lua`** (complexity 100) — 1.8.0 did a GDI→imtext rewrite + window background draw reorder + `positionChanged` block. Ferris added (a) buff loop fix (1-based + nil/sentinel break — prevented crashes when statushandler stored buff IDs 1-based and the old `for i=0` looped past valid data), (b) much richer position correction logic distinguishing `staleAfterApply` (stale state after ApplyWindowPosition) from a user-drag-detected `positionChanged` and syncing the corrected Y back to `gConfig.windowPositions[windowName]` immediately, (c) `ashita_settings.save()` → `SaveSettingsOnly()`. Both versions converged on `display.ResetPositions` rewrite using `windowPositions`/`appliedPositions`. Removed dead `ashita_settings` require.

- **`modules/castcost/display.lua`** (complexity 153) — 1.8.0 GDI→imtext rewrite with `refHeightCache` keyed by font size + immediate-mode `windowBg.Draw`. Ferris's changes were 3 small insertions: (a) `isBstJugReadySpellCost` flag init, (b) BST jug Ready cost detection in spell branch (replaces "MP:" label with "Cost:" and uses `itemInfo.mpCost` as the pet-charge cost), (c) cost color override using TP gold (same as WS) when the flag is set. Layered cleanly on top of 1.8.0's imtext rewrite.

- **`modules/hotbar/display.lua`** (complexity 166) — 1.8.0 did major perf rewrite: reusable `slotParams`/`slotInteraction` tables (avoid ~360 alloc/frame), `GetCachedIcon` extended to also return precomputed abbreviation, `windowBg.update` → `windowBg.Draw`, GDI→imtext for hotbar number, `gs = gConfig.globalScale` multiplier in `GetBarDimensions`, removed all "hide font/prim" loops (immediate-mode is stateless). Ferris's changes layered on top: (a) `playerdata` + `macroparse` requires, (b) `BuildBindKey` extended with `actions.GetMacroJaBadgeIconCacheSuffix(bind)` for macro JA badge custom icon cache invalidation (defensive guard since `actions.lua` not yet merged), (c) cache-miss path switched from `actions.BuildCommand` to `actions.GetBindIcon` (perf — skip building command strings when only icon is needed; defensive fallback if function absent), (d) `mpCostAnchor` default flipped `topRight` → `topLeft`, (e) skillchain prediction extended from WS-only to also cover Blood Pact and macros parsed via `macroparse.GetMacroPrimaryAndJaBadge`, (f) `playerdata.RefreshCachedLists(data)` at the top of `DrawWindow` to keep cached spell/ability/WS/item lists fresh for filters. Both versions converged on `ResetPositions` rewrite.

- **`modules/petbar/display.lua`** (complexity 225) — 1.8.0 did massive GDI→imtext rewrite + independent MP/TP/recast scaling (previously cascaded off HP X scale) + `totalRowWidth = math.max(...)` so window auto-fits widest bar + `positionJustApplied` adoption + `windowState` cachedWidth/Height for bg layering. Ferris added: (a) `windowState.anchorBottom` field (locked screen Y of bottom edge), (b) `PetBarResizeAnchoredBottom(typeSettings)` resolver for `gConfig.petBarResizeAnchor='top'|'bottom'|nil`, (c) `DrawResizeAnchorEdgePreview` function (visual stripe at pinned edge during config preview), (d) replaced simple alignBottom block with sophisticated anchor logic that handles `petBarSyncResizeAnchorNextFrame` (cluster drag from pet target), seed-on-first-frame, drag exemption (track live), and stable correction (`SetWindowPos` only when delta > 0.01px — eliminates the +/-1px crawl that the old delta-gate had), (e) `data.lastMainWindowPosX/Top/Bottom` integer-rounded, plus new `petBarSnapTopReferenceY = top - 8` (themed border outset) and `lastPetBarWindowHeight`, (f) `SaveWindowPosition('PetBar')` moved to AFTER position correction so the corrected Y persists, (g) `ResetPositions` extended to clear all `windowState.*` fields. 1.8.0's positionChanged detection became the `positionJustApplied` re-seed branch in the unified Ferris logic.

**Tier 1 net outcome**: All 5 light-complexity merges complete. Zero deprecated patterns introduced, all Ferris additions defensively guarded against the as-yet-unmerged `actions.lua` dependencies (`GetBindIcon`, `GetMacroJaBadgeIconCacheSuffix`).

### Phase 2.4 Tier 2 (medium 250–1000 complexity) — IN PROGRESS

- **`modules/petbar/pettarget.lua`** (complexity 288) — 1.8.0 GDI→imtext rewrite + `petTargetBgScale`/`petTargetBorderScale` split + `globalScale` propagation + `cachedWindowSize` for bg layering. Ferris layered a substantial snap-and-cluster-drag system on top: `handlers.imgui_compat` require, `clearPetTargetSpatialState()`, `pointInPetTargetHitRect()`, `anyImGuiItemHovered()`, and `maybeDragSnappedPetClusterFromTarget()` helpers. Core merge: replaced 1.8.0's simple snap block with Ferris's anchor-aware logic that handles top/bottom anchors, input-blocking (NoInputs) for snapped state so PetBarTarget doesn't steal clicks from hotbars stacked below, and cluster dragging that moves the PetBar window when the user drags inside the snapped target's hit rect. New persistent state: `data.petBarTargetHitRect` (cached outer rect for NoInputs hit testing), `gConfig.petTargetSnapCachedHeight` (persisted height for next-session top-snap placement). `SetHidden` and early-return paths updated to call `clearPetTargetSpatialState()` so stale rects don't leak across frames when the window goes invisible.

- **`modules/hotbar/recast.lua`** (complexity 300) — 1.8.0 refactored from periodic full-scan (`M.Update`) to lazy on-demand lookup with per-ID caching + `SPELL_RECAST_TTL`. Strategy: keep 1.8.0's lazy architecture as the base, layer Ferris's resolver/sniffer helpers on top. Added: lazy-loaded `universal_two_hour` + `actions` requires (avoid circular import), `normalizeCommandName()` (case-insensitive matching), `resolveSpellIndexForMa()` (Horizon-aware spell index resolution — prevents duplicate-name false hits e.g. SummonerPact), `PET_COMMAND_TIMER_ID_BY_NAME` static table + `getPetCommandTimerIdByName()`, `getRecastTimerIdFromAbilityResource()` (Ashita resource fallback for component IDs), `getRemainingForPetLikeAbilityName()` (BP shared timer / static pet-command timer / resource timer dispatch BEFORE ability-id scan). Macro-text sniffers: `sniffRecastTargetFromMacroText()` (generic /ma|/pet|/ja), `sniffRecastTargetFromMaMacroText()` (only /ma + /magic — never steal Carbuncle's spell timer from leading /pet), `sniffRecastTargetFromPetMacroText()` (only /pet + blood-pact /ja — preserve shared 173/174 timers), `sniffRecastTargetFromJaMacroText()` (BP→pet timers, else ability recast). `GetCooldownInfo` dispatch updated to use the new resolvers. Critically, `M.Update()` is **NOT** reintroduced — Ferris's universal-2hr + recast-component logic is achievable via the lazy-cache architecture without periodic scanning.

- **`modules/hotbar/init.lua`** (complexity 334) — 1.8.0 removed GDI/primitives requires, replaced `gdi`/`primitives` with `imtext`, added `AnyBarIsPetAware()` optimization (skip pet-state cache wipes when no bar is configured to react), streamlined `M.Initialize` (no font/prim creation needed). Ferris added: `gameState` require, `GetCrossbarDisableXiMacrosEffective()` helper for the disable-XI-macros toggle, `lastPaletteVisualRefreshSig` for palette-change deduplication (prevents redundant cache wipes when the same old→new palette signature fires twice), defensive `data.MigratePetAwareSlotStorageKeys()` call, enhanced `palette.ValidatePalettesForJob` with `applyDefaultCrossbarScope` flag, **separated** hotbar vs crossbar menu-hide logic (independent `hideOnMenuFocus` toggles per bar type), new `M.FinalizeFrame()` entry point for deferred drag/drop resolution (called from `XIUI.lua`'s `d3d_present`), `dragdrop.WasDroppedOutside` extended to handle `paletteEditStorageKey` correctly, and `universal_two_hour` + `macro_global_defaults` reset/sync calls in `HandleZonePacket` and `HandleJobChangePacket` — all defensively guarded with `if ... then` since some referenced modules don't exist yet in the current tree.

- **`modules/hotbar/playerdata.lua`** (complexity 748) — Ferris's diff was massive (+700 lines), so strategy was **overlay Ferris, then surgically re-apply 1.8.0's targeted refinements**:
  1. Replaced `ABILITY_TYPE_WEAPON_SKILL = 3` with the full `ABILITY_TYPE` enum table (24 entries from Ashita-v4beta enums.h — General, JobAbility, PetCommand, WeaponSkill, Trait, BloodPactRage, all DNC/RUN subtypes, etc.). Kept `ABILITY_TYPE_WEAPON_SKILL` as a backward-compat alias so Ferris's existing checks still resolve.
  2. Removed `'Assault'` from `PET_COMMAND_NAMES` — 1.8.0 dropped it because the BST pet command is confusable with the Treasures of Aht Urhgan Assault game system (added a code comment documenting why).
  3. Added `CATEGORY_PLACEHOLDER_NAMES` table (`Sambas`, `Waltzes`, `Steps`, `Jigs`, `Flourishes I/II/III`) — these are FFXI macro-maker subcategory headers that `HasAbility()` returns true for but aren't executable; they pollute the JA dropdown.
  4. Replaced all 5 occurrences of `ability.Type and bit.band(ability.Type, 7) or 0` with `ability.Type or 0` — `IAbility.Type` is a plain uint8 enum, NOT a bitfield, so the `bit.band` was masking off valid high values (DancerFlourish3=19, RuneEffusion=23, MonsterSkill=20).
  5. Added Trait + CategoryPlaceholder filters to `GetPlayerAbilities()` (in addition to Ferris's existing horizonRetailOnlyJa + WeaponSkill + PET_COMMAND_NAMES filters).
  No GDI/primitives references remain. Ferris's massive feature set (Horizon abilities/spells, equipment WS tracking, RefreshCachedLists, etc.) preserved intact.

- **`modules/hotbar/actions.lua`** (complexity 939) — Heaviest Tier 2 file. Ferris's diff was +897 lines vs 1.7.5; 1.8.0's diff was +42 lines of pure perf refinements. Strategy: **overlay Ferris (2164 lines), then layer 1.8.0's 4 surgical perf wins on top**:
  1. **`spellByNameLookup` lazy O(1) hashmap** — replaced O(n) `for _, spell in pairs(horizonSpells)` scan in `GetSpellByName()` with a hashmap built on first use. Builder preserves the FIRST match found per English name (intentional — for prefix/action-type-specific resolution callers should use the separate `GetSpellByNameForIcon()` which is case-insensitive and filters by school-magic / pet semantics).
  2. **`noIconCache` negative-result cache** + `buildNoIconKey()` helper + memoization in `GetBindIcon` end + `M.ClearNoIconCache()`. Key composition extended beyond 1.8.0's version to also include `recastSourceType`/`recastSourceAction` (Ferris's macro-recast override fields can change icon resolution) so the negative result invalidates when those change. Hooked `ClearNoIconCache()` into `display.lua`'s `ClearIconCache()` and `crossbar.lua`'s `M.ClearIconCache()` so the negative cache always wipes alongside the positive cache.
  3. **MP cost via macro recast source** — `M.GetMPCost()` extended to resolve from `bind.recastSourceType == 'ma' and bind.recastSourceAction` so macros showing a spell's recast also show that spell's MP. Ferris already had a more elaborate version of this path (with extra /pet sniffing), so this 1.8.0 hook was already covered — no edit needed.
  4. **Kept Ferris's `for abilityId = 1, 1024` resource scans in GetBindIcon** — 1.8.0 removed these scans for perf, but Ferris uses the resolved `iconId` for overlay/badge computation downstream. The noIconCache short-circuits repeat misses so the O(1024) scan only runs once per unique miss key per cache-wipe cycle (acceptable cost).

**Tier 2 net outcome**: All 5 medium-complexity merges complete. 1.8.0's perf rewrites (lazy recast, spell-name hashmap, noIconCache, immediate-mode rendering) preserved as the base; Ferris's massive feature additions (macro recast sniffing, universal 2hr, snap-and-cluster-drag, ABILITY_TYPE enum, Horizon-aware spell resolution) layered on top. All cross-module dependencies wired (display+crossbar→actions.ClearNoIconCache, hotbar.init→universal_two_hour, pettarget→imgui_compat).

### Quality audit: Ferris patterns vs 1.8.0 patterns

After Tiers 1 + 2 + Tier 3 Pass 1, user requested an explicit audit of every Ferris-only addition we kept, asking: **did 1.8.0 introduce a cleaner pattern that supersedes the Ferris implementation?** This is the third-pass perspective we deliberately skipped on the first sweep (which prioritized "preserve 1.8.0 wins + layer Ferris features without conflict").

For each finding, the verdict is one of:
- **KEEP FERRIS** — 1.8.0 has no equivalent or Ferris's implementation is better.
- **REPLACE WITH 1.8.0** — Ferris's code is redundant or worse than a 1.8.0 hook.
- **MERGE BOTH** — Combine the two patterns (e.g., use 1.8.0's mechanism, plus Ferris's extra coverage).
- **DOCUMENT BUG** — 1.8.0 has a latent bug Ferris already fixed; KEEP FERRIS and note 1.8.0's bug for upstream.

| # | Finding | File | Verdict | Notes |
|---|---|---|---|---|
| 1 | 1.8.0's `for i = 0, #memInfo.buffs do` loop processes a guaranteed-nil index 0 (statushandler stores 1-based), passes nil through `IsBuff()` (classifies as debuff), then `DrawStatusIcons(nil)` — potential native-renderer crash. | `modules/partylist/display.lua` | **DOCUMENT BUG** | Ferris's `for i = 1, ...` + sentinel break + local-hoist correctly avoids this. Kept Ferris version. Worth flagging upstream. |
| 2 | `lastPaletteVisualRefreshSig` (palette callback fan-out dedup) vs `AnyBarIsPetAware` (pet-aware skip) | `modules/hotbar/init.lua` | **KEEP FERRIS** | Solve different problems; both coexist cleanly. |
| 3 | Macro recast sniffers (sniff `/ma`, `/pet`, `/ja` from macro text when `recastSourceType` isn't explicitly set) | `modules/hotbar/recast.lua` | **KEEP FERRIS** | 1.8.0 has no macro-text interpretation. Sniffer is a usability feature for users who don't set the recast source explicitly. Architecturally compatible with 1.8.0's lazy per-spell-id cache (sniff result feeds into the same cache). |
| 4 | Pet bar integer rounding for `data.lastMainWindow*` + `petBarTopSnapOutset=8` magic number | `modules/petbar/display.lua` | **KEEP FERRIS** | Sub-pixel drift fix for snap math. 1.8.0's `libs/windowbackground.lua` doesn't expose border thickness for unification. |
| 5 | `GetCrossbarDisableXiMacrosEffective()` one-line helper | `modules/hotbar/init.lua` | **KEEP FERRIS** | Trivial helper for a Ferris-only setting (`disableMacroBars`); 1.8.0 has no equivalent. |
| 6 | `IsBstJugReadySpellCost` — BST jug-Ready cosmetic (label="Cost:" + TP-gold color, since spell's `ManaCost` field holds pet charge cost) | `modules/castcost/display.lua` | **KEEP FERRIS** | Orthogonal to 1.8.0's macro→spell `GetMPCost` resolution. |
| 7 | `FlushDeferredDrops` — drop-priority resolution for overlapping zones (crossbar under palette editor preview) | `libs/dragdrop.lua` | **KEEP FERRIS** | 1.8.0's `dragdrop.lua` has no overlap handling at all; first-registered zone wins. |
| 8 | `equipment_ws` cache — weapon→WS availability tracker tied to currently-equipped weapon | `modules/hotbar/equipment_ws.lua` + `modules/hotbar/playerdata.lua` | **KEEP FERRIS** | Orthogonal to 1.8.0's `slotInteraction` perf pattern. |
| 9 | `GetSpellByNameForIcon` did an O(n) scan over all `horizonSpells` per call (even though 1.8.0 introduced `spellByNameLookup` for the single-match variant) | `modules/hotbar/actions.lua` | **OPTIMIZE (APPLIED)** | Added a lazy case-insensitive multimap (`spellsByLowerNameLookup`). Reuses 1.8.0's pattern; matches the perf shape of `spellByNameLookup`. Auto-benefits `M.GetSpellIdByEnglishName` and `M.GetHorizonSpellForIconResolution` which route through it. |
| 10 | Two O(1024) ability scans inside `GetExpandedAbilities` (one to build name→id, one to populate playerHas) — ~4096 `resMgr` calls per cache miss | `modules/hotbar/playerdata.lua` | **OPTIMIZE (APPLIED)** | Pre-existing `modules/hotbar/actiondb.lua` already has a lazy session-cached `abilityNameToId` hashmap that both 1.8.0 and Ferris kept but neither propagated into playerdata's scans. Switched to: iterate ~80-entry `horizonAbilities` and use `actiondb.GetAbilityId(name)` for the O(1) lookup. Net: ~4096 → ~160 ops per cache miss. |
| 11 | `playerHasLearnedNonWsAbilityByName` did O(1024) scan to find a name match | `modules/hotbar/playerdata.lua` | **OPTIMIZE (APPLIED)** | Replaced with `actiondb.GetAbilityId(name)` + single `player:HasAbility(id)` check. O(1024) → O(1) per call. |
| 12 | `GetPlayerWeaponskills`, `DiscoverNewWeaponskills`, `countLearnedWeaponSkillAbilities` each did O(1024) scan filtering for `ability.Type == WeaponSkill` | `modules/hotbar/playerdata.lua` | **OPTIMIZE (APPLIED)** | Added `actiondb.GetWeaponSkillAbilityIds()`: lazy session-cached list of ability IDs with `Type == 3`, built once. All three callers now iterate just that list. Typical FFXI has ~50–100 WS abilities → ~10x reduction. |
| 13 | `imgui.SliderInt('Rows'/'Columns')` for hotbar dimensions don't use `ImGuiSliderFlags_AlwaysClamp` — double-click-to-type lets user store 0 or 999 as bar dimensions. **Both 1.8.0 and Ferris share this omission.** | `config/hotbar.lua` | **FIX BOTH (APPLIED)** | 1.8.0's stated policy (used throughout `config/components.lua`) is AlwaysClamp on every slider. Applied to bring these into compliance. |
| 14 | `imgui.SliderFloat` for cast-bar Fast Cast percentages (per-job + RDM SubJob + WHM Cure + BRD Sing) don't use AlwaysClamp. **Both 1.8.0 and Ferris share this omission.** | `config/castbar.lua` | **FIX BOTH (APPLIED)** | Same policy inconsistency as #13; out-of-range fast-cast values produce broken cast-speed math. |
| 15 | `imgui.SliderInt/Float` in `DrawGroupSlider` + `Number of Groups` slider don't use AlwaysClamp. **Both 1.8.0 and Ferris share this omission.** | `config/notifications.lua` | **FIX BOTH (APPLIED)** | Same policy inconsistency as #13. |
| 16 | Level Sync transition detection (clears playerdata + slotrenderer availability caches when Level Sync turns on/off) | `handlers/statushandler.lua` | **KEEP FERRIS** | Ferris-only feature. 1.8.0 doesn't track Level Sync for cache invalidation. Spell/ability availability genuinely depends on synced level. |
| 17 | `LoadItemIconByName` did O(65535) resource-manager scan per unique-item-name (local cache only deduped repeats of the same name) | `modules/hotbar/actions.lua` | **OPTIMIZE (APPLIED)** | Replaced with `actiondb.GetItemId(name)`. Pays the 65535 scan once across the whole addon (lazy-built on first use, shared with `recast.lua` and others). Local `itemNameToIdCache` retained for the icon-resolution leg (LoadItemIconById call). Net for a player resolving 50 unique item icons: ~3.3M ops → ~66K ops. |
| 18 | Pass 1 `slotrenderer.lua` added a local `ArgbToImguiU32` and a local `UthHsvToRgb` that duplicate `libs/color.lua`'s `ARGBToU32` and `hsvToRgb`. | `modules/hotbar/slotrenderer.lua` | **DEDUPE (APPLIED)** | Replaced the local versions with thin wrappers / direct aliases to `colorlib.ARGBToU32` and `colorlib.hsvToRgb`. Reduces drift risk if the shared color math is ever updated. `ScaleArgbOpacity`, `DimArgbColor`, `LerpArgbTowardWhite` are slotrenderer-specific tone-mapping ops not in libs/color.lua; they stay local. |

**Audit pass result:** 18 findings identified across 10 files. 1 documents a 1.8.0 bug (Ferris is the fix). 8 are KEEP FERRIS (Ferris features 1.8.0 doesn't address). 5 are perf-OPTIMIZE wins where the existing 1.8.0/actiondb infrastructure was underutilized. 3 are FIX BOTH where 1.8.0's slider-clamp policy wasn't applied consistently in either branch. 1 is DEDUPE of recently-added code against pre-existing utilities.

**Files audited (sampled / spot-checked):** All files modified in Phases 2.1-2.4 (config/components, config/castbar, config/hotbar, config/notifications, handlers/statushandler, libs/color, libs/dragdrop, modules/hotbar/{actions, actiondb, crossbar, display, init, playerdata, recast, slotrenderer}, modules/partylist/display, modules/petbar/{data, display, pettarget}).

**Net code impact of the audit pass:**
- ~6 hot-path scans collapsed to O(1) lookups (3 in playerdata WS scans, 1 in actions item icon, 1 in actions case-insensitive spell, 1 in playerdata GetExpandedAbilities).
- 1 new `actiondb.GetWeaponSkillAbilityIds()` helper added.
- 1 new lazy multimap `spellsByLowerNameLookup` added in actions.lua.
- 7 sliders gained `ImGuiSliderFlags_AlwaysClamp` to match 1.8.0's stated policy.
- 2 helper duplications removed from slotrenderer.lua.

**Remaining work after audit:** Resume Tier 3 Pass 2 (macroeditor labels, soft-ellipse backdrops, editor clip culling) per the original Option 1 multi-session plan.


### Phase 2.4 Tier 3 (heavy 1000+ complexity) — SCOPE FINDING + BLOCKED ON USER DECISION

Initial inventory of the 4 Tier 3 files reveals a fundamental architectural conflict that the previous Tier 1/2 overlay-and-patch strategy **cannot** resolve:

| File | 1.7.5 lines | 1.8.0 lines | Ferris lines | 1.8.0 delta | Ferris delta |
|---|---|---|---|---|---|
| `crossbar.lua` | 1912 | 1492 | 2789 | **−420** (GDI→imtext refactor) | **+877** (palette editor, double-tap preview, expanded triggers, skillchain) |
| `slotrenderer.lua` | 1578 | 1292 | 2755 | **−286** (GDI→imtext, removed `M.RegisterSlotPrim`/`InvalidateSlotByKey`/`ClearSlotCache`) | **+1177** (UTH rainbow border + subtarget glow, macroeditor label rendering, per-slot prim cache, GDI cooldown foreground) |
| `data.lua` | est. ~1100 | 1604 | est. ~1900 | **+500** (pet-aware storage refactor, per-pet-type settings) | **+800** (palette/macro/sharedmacrostore integration) |
| `macropalette.lua` | 0 (new in Ferris) | 0 | 2469 | n/a (file does not exist in 1.8.0) | **+2469** (entirely new — pure Ferris file) |

**The conflict**: 1.8.0 and Ferris **independently rewrote the same files in incompatible architectures**:
- **1.8.0 architecture**: `M.DrawSlot(params)` with a flat params table (font sizes/colors as plain numbers), `imtext.Draw` for all text, no persistent primitives, no `resources` parameter.
- **Ferris architecture**: `M.DrawSlot(resources, params)` where `resources` is a table of `FontManager`-created GDI font objects + persistent slot primitives. All text rendering goes through `set_text`/`set_position`/`set_visible` on those persistent objects.

Tier 1/2 worked because the conflicts were either small (Ferris adds features) or one-sided (1.8.0 refactors, Ferris doesn't touch). Tier 3 is **both sides rewrote the entire rendering hot path** — and they wrote it differently.

**Per-file Tier 3 strategy:**

- **`macropalette.lua`** — Trivial. Ferris-only file, no 1.8.0 equivalent. Already copied in Phase 1 (group A carry-over). Only risk: it may call `slotrenderer` with the old GDI signature (`M.DrawSlot(resources, params)`). To verify after slotrenderer port.

- **`data.lua`** — Tractable but heavy. Both versions added storage/cache logic; Ferris added palette/macro hooks; 1.8.0 added per-pet-type settings + storage refactor. Expected approach: overlay Ferris, then re-apply 1.8.0's per-pet-type storage refactor (similar shape to playerdata.lua). No rendering conflict.

- **`crossbar.lua`** — Must follow slotrenderer. Crossbar passes params to `slotrenderer.DrawSlot()`, so its call site must match whatever signature slotrenderer ends up with.

- **`slotrenderer.lua`** — The crux. Two equally-valid options:
  1. **Base = 1.8.0 (imtext)**: Re-implement Ferris's UTH/editor/macroeditor features as drawList ops on top of 1.8.0's params-table API. Cleanest long-term result. Requires line-by-line porting of ~1400 lines of Ferris's `DrawSlot` body. Risk: high — easy to miss nuance (label measurement, soft-backdrop ellipses, anchored corner positioning).
  2. **Base = Ferris (GDI)**: Resurrect FontManager + persistent primitives just for this module. Keeps Ferris's `DrawSlot(resources, params)` signature. Cuts work by 80%, but reintroduces the GDI fonts that 1.8.0 deleted — the addon would carry two rendering systems (imtext + GDI). Risk: maintenance burden, possible perf regression vs 1.8.0.

  Recommendation: **Option 1** for long-term cleanliness, but it's a multi-session port (slotrenderer alone is several hours of focused work). Option 2 is achievable in 1 session.

**Current Tier 3 state**: `crossbar.lua` restored to 1.8.0 base + `ClearNoIconCache` wiring (one-line change preserved). User selected **Option 1 (clean imtext port)**. Work on `slotrenderer.lua` is incremental — pure-drawList Ferris features ported first, font-dependent macroeditor features deferred to later sub-passes.

#### Tier 3 work-in-progress: `modules/hotbar/slotrenderer.lua`

Layered onto the 1.8.0 imtext base **in order of decreasing simplicity / increasing risk**. Each pass is independently verifiable (file loads cleanly + linters pass) so we can stop at any safe checkpoint.

**Pass 1 — Color helpers + UTH + skillchain icon overrides + per-window drawList + crossbar/paled lock semantics + `universalTwoHour` lazy require + `result.command` field (this session)**:

- Added `ArgbToImguiU32`, `ScaleArgbOpacity`, `DimArgbColor`, `LerpArgbTowardWhite` near `DrawDashedLine`. These convert XIUI's ARGB color words (used by all settings) into ImGui's `GetColorU32` floats, scale alpha for animation opacity, dim RGB for hover/inactive states, and brighten toward white for hover highlights. Used by every Ferris foreground-text path; foundation for later passes.
- Added `UthHsvToRgb`, `DrawUniversalTwoHourRainbowMarchingBorder`, `DrawUniversalTwoHourSubtargetGlow` — pure ImGui drawList ops, no font deps. Wired into `M.DrawSlot` directly after the existing `DrawSkillchainHighlight` call, gated by `universalTwoHour.ShouldGlowUniversalTwoHourSlot(bind)`. Silent no-op when `universal_two_hour` module isn't loaded (1.7.5 fork compat).
- Extended `DrawSkillchainHighlight` signature to accept per-call `iconScaleOverride`/`iconOxOverride`/`iconOyOverride`. The macro palette editor uses these to relocate the skillchain icon out of corner cells where action labels or BST-Ready badges live. Falls back to `gConfig.hotbarGlobal.skillchainIcon*` when not provided. `M.DrawSlot` now reads `params.skillchainIconScale`/`OffsetX`/`OffsetY` and passes them through.
- `slotOverlayDrawList()` selector inside `M.DrawSlot` returns `imgui.GetWindowDrawList()` when `params.windowName == 'Crossbar'`, else `GetUIDrawList()`. Crossbar overlays now stack within the window's z-order so they don't paint above modal dialogs (the shared UI drawList always paints on top of every ImGui window, which was breaking hovers).
- `IsMovementLockedForDropZone` updated to differentiate `crossbar_*` zones (use `crossbarLockMovement`), `paled*` zones (palette editor — never locked), and the rest (`hotbarLockMovement`).
- `universal_two_hour` module loaded with `pcall(require)` so the base loads cleanly even when the module is absent.
- `drawSlotResult.command = nil` initialized on every frame so Ferris callers that prefer pre-built command strings (palette editor click handlers) can opt in — actual command-building is still deferred to click time for the perf-critical hotbar/crossbar render path. **No semantic regression** for 1.8.0 callers.

**Pass 2 — Macroeditor label rendering + editor clip culling + dropPriority (this session, COMPLETED for slotrenderer scope)**:

1. **Editor clip rect culling** — `editorClipRect: {minX, minY, maxX, maxY}` + `editorStrictContain: bool` params drive an early-return short-circuit at the top of `M.DrawSlot`, immediately after the `animOpacity <= 0.01` check. The reject box expands to include the label area (~fs + 14 + line-wrap pad) so labels above/below the slot are still hidden when off-screen. Strict-contain mode is for cases where the parent panel must not show partially-visible slots (e.g. clipping wouldn't be enough — the slot must be FULLY inside the rect to draw at all).
2. **`labelForeground` branch** — when set, the label render path skips the default single-line below-slot routine and routes through one of two new helpers:
   - `editorMinimalView = true`: `DrawEditorMultilineCenteredOnSlot` centres the label ON the slot, using `EditorIdleAbbrev4` (first 4 chars when idle) and the full label on hover, with one imtext.Draw per line (matches Ferris's "thin outline only, no scrim/halo" style so wrapped labels don't stack heavy shadows).
   - `editorMinimalView = false`: `DrawEditorMultilineCenteredAtY` centres the label above or below the slot with soft-wrap from `EditorLabelWrapNearSlot` — at most one newline, with the line nearest the slot holding a single word. This is the wider Edit Full Palette view where slot density is lower.
3. **`labelAboveSlot` support** — both editor label paths and the clip-rect padding logic respect the new flag so the editor can place labels above the slot row (e.g. top row of Edit Full Palette). Default behavior is unchanged.
4. **Animation opacity threading** — label color now has `animOpacity` applied to its alpha so fade-in/fade-out works on editor labels (the old single-line path delegated to imtext's color directly; the multi-line helpers don't compose alpha automatically).
5. **`dropPriority` forwarded** — `M.DrawSlot` now passes `params.dropPriority` into `dragdrop.DropZone`'s options. Default is nil (= first-registered wins, current behavior) so existing call sites are unaffected. Edit Full Palette will set it >0 so the editor preview overlay wins ties against the live crossbar zone underneath.

### Crash fix — palette deletion CTD (this session)

**Reported:** "When I deleted a palette, it crashed my game, look into that. I think it was actively selected."

**Root cause:** mid-frame texture release race. The palette-deletion path runs *inside* an ImGui draw call (the Palette Manager UI button handler), and calls a cascade of cache wipes — `slotrenderer.ClearAllCache()` / `slotrenderer.ClearSlotRenderingCache()` / `display.ClearIconCache()` / `crossbar.ClearIconCache()` (via `InvalidateAllVisualCachesAfterPaletteListMutation` and the `OnPaletteChanged` callback). Each of those caches held the SOLE Lua reference to D3D textures returned by `textures:LoadTextureFromPath` (FFI handles wired with `d3d8.gc_safe_release`). Reassigning the table to `{}` mid-frame drops those refs, Lua GC can run at any later allocation in the same frame, the COM texture gets released — but `dl:AddImage(ptr, …)` calls queued earlier in the same frame still hold the raw pointer. When the renderer hits that draw call → `EXCEPTION_ACCESS_VIOLATION` → CTD.

This is the same race that `libs/texturemanager.lua` already guards against for its own categories via `pendingReleases` + `FlushPendingReleases` (called at the top of every `d3d_present`). The palette-delete path was bypassing that safety net because slotrenderer / display / crossbar manage their own local texture caches outside TextureManager.

**Fix:** routed the cache-wipe paths through a new public helper `TextureManager.DeferRelease(value)` that pushes any Lua value onto the existing `pendingReleases` list. Touched files:

- **`libs/texturemanager.lua`** — exposed `M.DeferRelease(value)` (thin wrapper over the existing internal `deferRelease`); doc comment ties it to the palette-delete crash.
- **`modules/hotbar/slotrenderer.lua`** — `M.ClearAllCache` and `M.ClearSlotRenderingCache` now call `TextureManager.DeferRelease(texturePtrCache)` before `texturePtrCache = {}`. The non-texture caches (availability / mpCost / equipmentCheck / ninjutsu / itemQuantity / stackSize / ammoStatus) stay on the immediate-clear path — they only hold primitives so no GC race.
- **`modules/hotbar/display.lua`** — `ClearIconCache` defers the whole `iconCache` table; `ClearIconCacheForSlot` defers just the deleted per-slot row (the only entry losing a Lua ref).
- **`modules/hotbar/crossbar.lua`** — same pattern as display: `ClearCrossbarIconCache` defers the whole table; `ClearCrossbarIconCacheForSlot` defers the per-slot row.

**Why this is safe:** `FlushPendingReleases` runs at the very top of `d3d_present`, BEFORE any frame work queues new AddImage calls. By that point the previous frame's ImGui draw list has already executed, so any pointer it queued is safe to invalidate. The deferred table can then be dropped wholesale and Lua GC is free to run `gc_safe_release` on the underlying COM objects.

**Lint:** clean across the four touched files.

### Smoke-test fix pass — 8 user-reported issues (this session)

After the user smoke-tested the Phase 2.4 merges, eight issues surfaced. All eight were fixed in a single pass:

1. **`config/crossbar.lua:50` nil function (`DrawSharedDisableXiMacrosControls`).** Root cause: our `config/hotbar.lua` was still the 1.8.0 base; Ferris's `config/crossbar.lua` (which we already had) calls back into `config/hotbar.lua` for SHARED controls that only Ferris defines. **Fix:** overlaid Ferris's `config/hotbar.lua` (2448 lines, down from 1.8.0's 3263 — Ferris moved ~815 lines of crossbar-specific UI out of hotbar.lua into `crossbar.lua` / `crossbar_settings.lua`, and added 3 shared-control helpers: `DrawSharedDisableXiMacrosControls`, `DrawSharedSkillchainHighlightControls`, `DrawLogPaletteNameCheckbox`). The 1.7.5→1.8.0 diff was small (+11 lines) and re-applied surgically (see below).
2. **"Edit Full Palette" nested under Hotbar** — was a side-effect of #1. Ferris's refactored `config/hotbar.lua` puts the Edit Full Palette entry in `config/crossbar.lua` / `config/crossbar_settings.lua` instead. Fixed by the same overlay.
3. **"Layout Mode" dropdown still visible on Hotbar** — also a side-effect of #1. 1.8.0's `config/hotbar.lua` had a Layout Mode dropdown at lines 2717-2735 referring to crossbar layout. Ferris's refactor moved those concerns to the Crossbar tab and dropped the dropdown. Fixed by the same overlay.
4. **"Lock Crossbar" toggle tied to Hotbar's `hotbarLockMovement`.**
    - `config/crossbar.lua` (Ferris's stub) writes to `gConfig.crossbarLockMovement`. Good.
    - **`modules/hotbar/crossbar.lua:1582` (move anchor) was reading `gConfig.hotbarLockMovement`** — wrong. **Fix:** swapped to `gConfig.crossbarLockMovement` so the Hotbar lock no longer freezes the crossbar.
    - **`modules/hotbar/slotrenderer.lua:1530` (right-click clear) was hardcoded to `gConfig.hotbarLockMovement`** for both hotbar and crossbar slots. **Fix:** routed through `IsMovementLockedForDropZone(params.dropZoneId)` so the per-zone policy (already correct for drop zones at line 766-779) also gates right-click. Hotbar zones still consult `hotbarLockMovement`; crossbar zones (`crossbar_*` prefix) consult `crossbarLockMovement`; palette-editor zones (`paled*` prefix) are never locked.
5. **Crossbar's left/right diamond slots visually cut off.** Root cause: ImGui's default `WindowPadding` (~8 px) was clipping the leftmost slot of the L2 diamond and the rightmost slot of the R2 diamond — these sit flush against the window content rect (slot offset X = 0 for the left-most, and at `groupWidth - slotSize` for the right-most). Without zero padding the button hitboxes were also pushed inward, making slot interactions unreliable. **Fix:** `imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, {0, 0})` before `imgui.Begin('Crossbar', …)` and `imgui.PopStyleVar()` after `imgui.End()` — the pop is unconditional so it matches whether or not Begin returned true.
6. **Top diamond slot's label rendered BELOW the slot, overlapping the bottom slot's MP cost / quantity text.** Root cause: `slotrenderer.lua` honors `params.labelAboveSlot` for the editor (paths b + c at lines 1262-1284), but the default live-HUD path (a) at lines 1285-1290 always placed the label below the slot. The Pass 1 crossbar code already sets `p.labelAboveSlot = (posIndex == 1)`, but slotrenderer was ignoring it on the live path. **Fix:** path (a) now computes `labelY` from `params.labelAboveSlot` — measures with `imtext.Measure('Mg', size)` and stacks above the slot when the flag is true. Keyboard hotbars pass false → no behavior change.
7. **Palette scope icon (Global/Job indicator above the divider) missing.** Was deferred to crossbar Pass 2. **Fix (Pass 2 partial):** ported Ferris's `GetInfinityPaletteIconTexture` (lazy session-cached FFXIV-1 / Classic infinity texture), `GetPaletteJobIconThemeFromSettings` (theme allowlist with Classic fallback), `ShouldShowPaletteScopeIcon` (explicit setting wins, nil → follows `showPaletteName` for legacy profile compat), and `DrawPaletteScopeIconAboveDivider` (drawList AddImage with size auto-derived from `paletteNameFontSize` when no explicit `paletteScopeIconSize` slider value). Wired into `M.DrawWindow` next to the divider line — both gated by `showCenterElements` (hidden in `activeOnly` display mode where there's no divider). Added `local TextureManager = require('libs.texturemanager')` for the job-icon and infinity textures.
8. **Pulsing R1 + "x2" indicator (set via `/xiui cpal <Job>`) not rendering, even though the cpal cycle was functional.** Was deferred to crossbar Pass 2. **Fix (Pass 2 partial):** ported into `DrawTriggerIcons` — only renders when `palette.GetCpalAnchor(scope)` returns truthy. ~2.5 Hz size pulse via `math.abs(math.sin(os.clock() * 2.5))` (peak +30%), centered on the original R1 icon position above R2. Includes a dark pill backdrop (`AddRectFilled` with rounded corners) spanning the icon + "x2" gold text (ARGB `0xFF32C8FF`) so the legend reads as a unit. Uses `palette.GetCrossbarPaletteScope()` so anchors are per-scope (universal vs job-scoped don't leak).

**Also re-applied 1.8.0's `config/hotbar.lua` perf/feature changes** (the 11-line 1.7.5→1.8.0 diff that Ferris's tree missed):
- **`Show Stack Quantity` checkbox** added to `DrawVisualSettingsContent` (hotbar tab) and `DrawStandaloneCrossbarSettings` (crossbar tab in `config/crossbar_settings.lua`). Counts complete stacks above the item quantity (e.g. 25 of stack-12 items shows "(2)"). 1.8.0 added this as a small UX win for stack management.
- **`Slot Y Padding` slider** — 1.8.0 removed it with the comment "each hotbar is now positioned independently, so bar-to-bar spacing is handled by drag-positioning". **Kept Ferris's slider** for now since Ferris's data layer still wires `slotYPadding` for the gap inside multi-row bars; revisit during Phase 3 audit if drag-positioning fully replaces it.

**Lint:** clean across all four touched files (`config/hotbar.lua`, `config/crossbar_settings.lua`, `modules/hotbar/crossbar.lua`, `modules/hotbar/slotrenderer.lua`).

**Status update:** all 8 reported issues are addressed. Crossbar Pass 2's remaining deferred work shrinks to just `DrawDoubleTapPreviewWindow` and smart window-position save/restore (`ApplyCrossbarWindowPositionOnce` / `SaveCrossbarWindowSlotTopPosition`). The shared-expanded-bar variant (`DrawTriggerIconsSharedExpandedCenter`) is still deferred — it's only relevant when `settings.useSharedExpandedBar` is enabled.

---

### Tier 3: `modules/hotbar/macropalette.lua` (previous session)

**Provenance scan:**
- 1.7.5 base: 3906 lines, 26 public functions, 43 local functions.
- 1.8.0 refactor: 3859 lines (−47), **same 26 public functions**, 43 locals. Pure internal polish: centralised slot-record construction through `data.BuildSlotDataForWrite()`, removed dead `slotrenderer.InvalidateSlotByKey` calls, added defensive empty-slot guard on `M.StartDragSlot`, extended `ClearAllIconCaches` to drop MP-cost / availability / icon-resolution negative caches.
- Ferris fork: **6328 lines (+2469)**, **35 public functions** (kept all 26 from 1.7.5 plus added **9 new**: `ApplyIconPickerContextFromEditor`, `ClampMacroEditorForItemsPalette`, `DrawMacroEditorSaveToSection`, `EditorMacroPaletteKeyIsItems`, `GetEditorSaveDisplayName`, `GetMacroSourceTagForDrops`, `MoveMacroToPalette`, `OpenEditorForSlotData`, `OpenNewMacroWithText`). 95 locals (+52). The new public surface drives the dual-arm macro-editor wiring (profile/shared store), the Items / pet palette type system, the Move Macro flow, and the `GetMacroSourceTagForDrops` helper that `crossbar.lua` Pass 1 already calls.

**GDI footprint in Ferris's tree: zero.** A `Grep` for `FontManager / gdifonts / primitives.create / set_visible / set_text / set_font_alignment / submodules.gdifonts / :set_position` returns no matches. The only obsolete-API references were 2 calls to `slotrenderer.InvalidateSlotByKey()` (which 1.8.0 removed).

**Strategy: overlay Ferris + surgically re-apply 1.8.0's 7-change diff** (mirrors the `actions.lua` / `playerdata.lua` strategy). Ferris already centralised slot construction through richer functions (`BuildMacroSlotAfterDrop` / `FinalizeHotbarRawSlotForStorage` / `SwapActiveMacroArmsInPlace` — full dual-arm support) so the 1.8.0 `BuildSlotDataForWrite` centralisation is **already satisfied by a strict superset**; no need to undo Ferris's drop-handler shape.

**Merge applied (this session):**
1. **Overlay** — copied Ferris's `macropalette.lua` wholesale (6328 lines) as the new base.
2. **Stripped `slotrenderer.InvalidateSlotByKey` calls** — 2 removed from `ClearSlotIconCache` (`barIndex:slotIndex` key) and `ClearCrossbarSlotIconCache` (`comboMode:slotIndex` key). Replaced with comments explaining why (immediate-mode rendering has no persistent prim cache; the per-frame bind hash naturally re-derives — see `slotrenderer.lua` 1.8.0 refactor). The `pcall(require, 'modules.hotbar.slotrenderer')` lazy loads remain because `ClearAllIconCaches` still uses them.
3. **Re-applied 1.8.0's `ClearAllIconCaches` extension** — added `slotrenderer.ClearMPCostCache()`, `slotrenderer.ClearAvailabilityCache()`, `actions.ClearNoIconCache()` to the full-clear path. Without these, macro edits that change a slot's `actionType:action` leave the old key orphaned in those caches; functionally fine (the new key naturally misses) but unbounded across many edits. Wired with the same `if … and ….Func then …` defensive pattern Ferris uses elsewhere in the file.
4. **Re-applied 1.8.0's `M.StartDragSlot` defensive guard** — added `if not slotData then return; end` at the top. Prevents the "ghost drag" bug Ferris's tree could hit: in 1.7.5, dragging an empty/orphaned slot bypassed the `slotData and (slotData.displayName or …)` fallback and started a dragdrop session with a nil payload, which confused the drop-zone resolution.
5. **Kept Ferris's `M.HandleDropOnSlot` shape** — all three branches (`macro` / `slot` / `crossbar_slot`) already go through `BuildMacroSlotAfterDrop + FinalizeHotbarRawSlotForStorage` (macro arm path) or `SwapActiveMacroArmsInPlace + FinalizeHotbarRawSlotForStorage` (slot swap path). This is a strict superset of 1.8.0's `data.BuildSlotDataForWrite()` centralisation — it also handles dual-arm macros, the cleared-state contract, and the K_BIND_P / K_BIND_S split. Verified against `data.lua`'s `FinalizeHotbarRawSlotForStorage` (line 720) which enforces the same "macro stores macroRef + macroPaletteKey only" invariant 1.8.0 wanted.
6. **Verified module dependencies all resolve** — every `data.*` / `slotrenderer.*` / `playerdata.*` / `actions.*` call has a target in the merged tree:
    - `data.lua` exports: `FinalizeHotbarRawSlotForStorage` (720), `SetSlotDataChangedCallback` (49), `MacroPaletteKeysEqual` (878), `RewriteMacroPaletteBindingsInDraft` (984), `SwapActiveMacroArmsInPlace` (1041), `GetBarSettings` (1713), `_GetActiveMacroBindingFromSlot` + `IsMacroSlotDualLayout` (388-389), plus the 13 other Ferris APIs already verified.
    - `slotrenderer.lua` exports: `ClearAllCache` (414), `ClearSlotRenderingCache` (428), `ClearAvailabilityCache` (433), `ClearMPCostCache` (440) — all four called by macropalette.
    - `crossbar.lua` Pass 1's drop handler now resolves `macropalette.GetEffectivePaletteType` (M-exported at line 1691) and `macropalette.GetMacroSourceTagForDrops` (line 2652).

**Lint:** clean.

Final line count: **6341 lines** (Ferris 6328 + 13 net from the 1.8.0 re-applications).

**With macropalette.lua merged, Phase 2.4 Tier 3 is effectively done.** All four heavy files (`slotrenderer.lua`, `crossbar.lua`, `data.lua`, `macropalette.lua`) are landed. Only `crossbar.lua` Pass 2 (UX polish — double-tap preview, palette scope icon, smart window positioning, etc.) is deferred until the user has smoke-tested Pass 1 end-to-end.

---

### Tier 3: `modules/hotbar/crossbar.lua` (previous session — Pass 1: palette-editor wiring)

**Provenance scan:**
- 1.7.5 base: 1912 lines, 11 public functions, 36 local functions.
- 1.8.0 refactor: 1492 lines, 11 public functions, 35 local functions. Same public API as 1.7.5, but the renderer body was rebuilt around the new `slotrenderer.DrawSlot(params)` flat-table API + a reusable `GetCbInteraction(comboMode, slotIndex)` cache (avoids re-allocating closures every frame). Drop-zone IDs are stable; `cbParams` is reused in-place to skip per-frame table churn.
- Ferris fork: 2789 lines, **17 public functions** (kept all 11 from 1.7.5 plus added **6 palette-editor entry points**: `DrawPaletteEditorL2R2Row`, `DrawPaletteEditorSingleRow`, `DrawPaletteEditorL2R2TriggerGlyphs`, `DrawPaletteEditorSharedChordTriggerGlyphs`, `GetEditorCrossbarRowDimensions`, `HidePaletteEditorPrimitives`). 51 local functions — 20 of those are Ferris-only (palette editor row, double-tap preview window, palette scope icon, window position save/restore, skillchain visuals reader, etc.). The shared `DrawSlot` body in Ferris's tree is still on the **legacy GDI resources API** — `state.slotPrims / iconPrims / timerFonts / mpCostFonts / quantityFonts / labelFonts / abbreviationFonts` plus a 7-table `resources = {...}` arg pushed into `slotrenderer.DrawSlot(resources, params)`.

**Architectural conflict (this is the big one — same as `slotrenderer.lua`):**
- 1.8.0's `DrawSlot` calls `slotrenderer.DrawSlot(p)` with a single flat params table. No resources arg, no persistent fonts.
- Ferris's `DrawSlot` calls `slotrenderer.DrawSlot(resources, params)` with the 7-table resources arg (filled from `state.slotPrims[primKey][slotIndex]` etc.).
- Ferris's tree contains **104 GDI references** in crossbar.lua alone (across `primitives.create`, `state.*Fonts`, `set_visible`, etc.).

**Strategy chosen by the user (`Option 1 — Clean imtext port`):** keep our current 1.8.0 base of crossbar.lua and layer Ferris's editor features on top, rather than overlaying Ferris and stripping 104 GDI refs.

**Pass 1 applied (this session):**
1. **Palette-editor interaction cache** — added `cbInteractionPalEd` table + `GetCbInteractionPaletteEditor(comboMode, slotIndex)` factory mirroring 1.8.0's `GetCbInteraction` pattern. Editor zones use `paled_*` IDs (separate from live `crossbar_*` so the slotrenderer drop-zone-lock policy treats them differently — paled is never locked). Editor drop handler routes through `data.SetDraftSlotData / GetDraftSlotData` so the live HUD is not mutated until Apply Draft.
2. **`DrawSlot` extended for palette session** — auto-detects `data.GetCrossbarPaletteEditSessionKey()` and switches: data source (draft layer), interaction set (`paled_*`), background (`PAL_ED_EMPTY_SLOT_BG = 0xFF8E96AC` behind empty editor slots), label policy (always-on, abbreviated on slot, full text on hover via `editorMinimalView + labelForeground`), MP/quantity/cooldown text suppressed, skillchain highlight suppressed, drop priority bumped to 10. Top diamond slot gets `labelAboveSlot = true` so labels don't overlap the bottom slot's text.
3. **Stronger inactive-side dim while trigger held** — threaded `activeCombo` from `M.DrawWindow` through `DrawBarSet → DrawLeftSide / DrawRightSide → DrawSlot` (11 call sites updated). When `activeCombo ~= NONE`, the inactive half dims to `settings.inactiveSideWhileTriggerDim` (default `0.15`) instead of the usual `settings.inactiveSlotDim` (default `0.5`). This is a Ferris-only UX polish that 1.8.0's base shipped without.
4. **6 palette-editor public functions added** — `DrawPaletteEditorL2R2Row` (two-sided), `DrawPaletteEditorSingleRow` (Pets-tab filter, one side at a time), `DrawPaletteEditorL2R2TriggerGlyphs` (raised L2/R2 art above the cluster — supports `'primary'` / `'doubleTap'` / `'chordCombo'` / `'sharedChord'` modes), `DrawPaletteEditorSharedChordTriggerGlyphs` (convenience wrapper), `GetEditorCrossbarRowDimensions` (sizing for `palettemanager.lua` row hosts), and `HidePaletteEditorPrimitives` (no-op stub — kept for API compatibility with `palettemanager.lua`'s 6 call sites; under imtext there are no persistent objects to hide).
5. **Constants added** — `ALL_COMBO_MODES` (`{'L2','R2','L2R2','R2L2','L2x2','R2x2','Shared'}`) + `PAL_ED_PREFIX` for naming.
6. **`macropalette` required** — needed by the editor's drop handler for `GetEffectivePaletteType` and `GetMacroSourceTagForDrops`. Required at module scope (no circular dep observed); if one creeps in this becomes a lazy require inside the closure.

Final line count after Pass 1: **1820 lines** (1.8.0 base 1492 + 328 net Ferris additions, with the GDI plumbing left out).

**Lint:** clean. **Smoke test:** pending — the editor is callable from `palettemanager.lua` but has not been opened in-game yet. Sliding into Pass 2 only after the user validates the editor renders, drops work, and the dim-on-trigger behavior is correct on the live HUD.

**Pass 2 deferred — Ferris-only crossbar features not yet ported:**
- `DrawDoubleTapPreviewWindow` — hover-preview of the doubletap bars from a tooltip-style window.
- `ShouldShowPaletteScopeIcon` / `DrawPaletteScopeIconAboveDivider` / `GetInfinityPaletteIconTexture` / `GetPaletteJobIconThemeFromSettings` — palette scope indicator over the center divider (visual cue for which palette is currently active).
- `ApplyCrossbarWindowPositionOnce` / `SaveCrossbarWindowSlotTopPosition` — smart window-position carry across mode changes (1.8.0's `GetDefaultPosition` covers the basic case; Ferris layers persistence).
- `DrawTriggerIconsSharedExpandedCenter` — center trigger glyph art for the sharedExpanded layout (the editor variant is in already; this is the live HUD variant).
- `GetCrossbarSkillchainVisualsFromGlobal` — reads gConfig.hotbarGlobal skillchain settings into a small reusable table (color, ring opacity, etc.). 1.8.0's path uses `gConfig.hotbarGlobal.skillchainHighlightColor` directly, which covers the common case; the richer table is a polish item.
- `GetModesToResetForFrame` / `IconCacheNs` — minor frame-bookkeeping helpers.
- `InitComboModeSlotResources` / `EnsurePalEdPrimitivesForComboMode` / `CreatePrimitive` — GDI plumbing. **Intentionally not ported.**

These are all UX-polish or GDI-only. None of them are required for the editor's basic open/drop/apply flow.

---

### Tier 3: `modules/hotbar/data.lua` (previous session)

**Provenance scan:**
- 1.7.5 base: 1254 lines, 47 public functions.
- 1.8.0 refactor: 1116 lines, 48 public functions (removed 3 GDI font functions: `RebuildAllFonts` / `SetAllFontsVisible` / `SetBarFontsVisible`; added 1: `BuildSlotDataForWrite`).
- Ferris fork: 2720 lines, 98 public functions (kept all 47 from 1.7.5 plus added 51 new: macro dual-arm bindings, palette draft layer / undo, segment overrides, per-pet-type crossbar storage, macro propagation across slot bindings, `MigratePetAwareSlotStorageKeys`, etc.). The 3 GDI functions are still present in Ferris's tree.

**Diff math (functions):**
- 1 function in 1.8.0 ∧ NOT in Ferris: `BuildSlotDataForWrite` — must be ADDED back as a public API after the overlay.
- 51 functions in Ferris ∧ NOT in 1.8.0 — preserved via overlay.
- 3 functions in both 1.7.5 + Ferris but DROPPED by 1.8.0 (`RebuildAllFonts`, `SetAllFontsVisible`, `SetBarFontsVisible`) — must be REMOVED after the overlay.

**Merge applied:**
1. **Overlay** — copied Ferris's `data.lua` wholesale (2720 lines) as the new base. No rendering conflict (data.lua is pure logic) so this is safe.
2. **Stripped GDI functions** — removed `RebuildAllFonts` / `SetAllFontsVisible` / `SetBarFontsVisible` and replaced them with a comment block documenting why they're gone (imtext is stateless per-frame). The font tables themselves (`M.keybindFonts`, `M.labelFonts`, etc.) are kept as empty placeholders for now — any leftover writes from older crossbar/macropalette code are inert, and we'll remove the placeholders once Tier 3 crossbar.lua / macropalette.lua have stopped writing to them.
3. **Added `M.BuildSlotDataForWrite`** — public API copied from 1.8.0, placed next to Ferris's local `buildSlotRecord`. Same two-shape contract as 1.8.0 (macro → `{macroRef, macroPaletteKey}`, everything else → full record) PLUS forward Ferris's dual-arm metadata (`macroSourceStore`) and JA badge flag (`showJaBadgeOnMacro`) when present in the input, so swap/move operations preserve arm identity.
4. **Verified call sites** — all `data.*` references in `init.lua` (`MigratePetAwareSlotStorageKeys`, `ClearDraftSlotData`, etc.), `display.lua` (`BUTTON_GAP`, `PADDING`, etc.), and `macropalette.lua` (`BuildSlotDataForWrite` × 4) resolve cleanly against the merged file.

Final line count: **2639 lines** (Ferris 2720 − 110 GDI removal + 30 BuildSlotDataForWrite + extras).

---

**Remaining slotrenderer Ferris-only features intentionally not ported** (will be evaluated when needed by callers; most are GDI-specific and obsoleted by imtext):
- `resources.slotPrim/iconPrim` persistent primitive cache management → 1.8.0 uses ImGui AddImage; obsoleted.
- Persistent GDI font lifetime (`labelFont:set_text`, `cache.labelText`) → imtext is stateless per-frame.
- `HideSlot` API → no-op in imtext mode (drawing simply not emitted).
- Multi-pass outline + drop shadow + fill stacking → not needed at editor's font sizes; imtext.Draw's 4-cardinal outline is sufficient and runs at one-third the cost.
- Soft-ellipse backdrops behind editor labels → re-evaluate after smoke test; if labels are legible on the editor's grey panel background without a backdrop we can skip; otherwise add a `drawList:AddRectFilled` rounded-rect tinted by the panel color.

**Pass 3 — DEFERRED: drop zone visualization helpers** (overlay rects, drop indicator arrows). Pure drawList ops, low risk; held for a session that can test them end-to-end with the palette editor.

**Pass 4 — DEFERRED: per-slot prim cache** (`M.RegisterSlotPrim`/`InvalidateSlotByKey`/`ClearSlotCache`). 1.8.0 removed these because immediate-mode rendering has no persistent prims to track. Ferris's macropalette.lua calls them — those callers need updating to no-op or use the 1.8.0 cache invalidation paths. Audit deferred to the crossbar/macropalette merge pass.

---

## Quick verdict

- **1.8.0 is a major rewrite of the render layer.** All persistent `primitives:new(...)` + GDI-font text objects are gone. Every module that previously held `bgPrim`, `tlPrim`, `textObj` etc. is now pure immediate-mode (`drawList:AddImage`, `drawList:AddText`, `imtext.Draw`).
- **The `gdifonts` submodule is deleted.** A new `libs/imtext.lua` (302 lines) is the replacement text-rendering layer. `libs/encoding.lua` (formerly `submodules/gdifonts/encoding.lua`) was moved into `libs/`.
- **`FontManager.create / recreate / destroy` is dead.** The whole `set_text / set_font_alignment / set_position / set_visible` pattern Ferris uses must be replaced with `imtext.Measure` + `imtext.Draw` immediate-mode calls.
- **Ferris's fork is mostly hotbar/macro/palette work.** Out of 39 Lua files Ferris modified, **27 collide with files 1.8.0 also rewrote** — those need 3-way merges. The other 12 Ferris-modified files were left alone by 1.8.0 — those can be carried over with minor de-gdi work.
- **22 brand-new Lua files in Ferris** (Horizon DBs, macro/palette system, shared macro store, palette manager UI, JSON, etc.) come over essentially intact — most don't touch rendering.
- **6 brand-new files in 1.8.0** must be taken as-is: `libs/imtext.lua`, `libs/fontconst.lua`, `libs/encoding.lua`, `config/readycheck.lua`, `modules/readycheck/init.lua`, `modules/readycheck/ui.lua`, plus 4 `.wav` sounds in `modules/readycheck/sound/`.

---

## Step 1-1 — Official 1.8.0 changes (`XIUI1.7.5` → `XIUI1.8.0`)

### 1.1 The big architectural shifts

#### A. Text rendering: GDI fonts → `imtext` (ImGui native fonts on drawLists)

| | 1.7.5 (gdifonts) | 1.8.0 (`libs/imtext.lua`) |
| --- | --- | --- |
| Underlying tech | GDI/`gdifonttexture.dll`, rendered as Ashita primitive textures | `imgui.AddFontFromFileTTF` + `drawList:AddText` |
| Lifetime | Persistent `gdi:create_object(settings)` → handle with `set_text / set_position / set_visible / set_font_alignment` etc. | None. Immediate-mode every frame. |
| Alignment | A font property (`gdi.Alignment.Left/Center/Right`) | Caller's responsibility: measure with `imtext.Measure`, position manually |
| Flags | `gdi.FontFlags.{None,Bold,Italic}` | Same numeric values via `libs.fontconst` (`FLAG_NONE=0`, `FLAG_BOLD=1`, `FLAG_ITALIC=2`) — values are identical |
| Font load timing | Lazy per-object | **Must prewarm at `load` event via `imtext.PrewarmFonts(components.available_fonts)`.** Calling `AddFontFromFileTTF` mid-frame in Ashita 4.16 causes `EXCEPTION_ACCESS_VIOLATION` (atlas mutation while drawList is mid-flight). |
| Settings shape | `{ font_family, font_height, font_color, font_alignment, font_flags, outline_color, outline_width, ... }` | `{ font_family, font_flags, outline_width }` — most other fields ignored. font_size is a per-call argument now. |
| Outline | Texture-baked into the font object | 4-cardinal `AddText` draws around the main one (`imtext.Draw`); single drop-shadow variant (`imtext.DrawShadow`) for hot paths (e.g. hotbar slots) |

**Public API of `libs/imtext.lua`:**
```lua
local imtext = require('libs.imtext');
imtext.PrewarmFonts(families)           -- call once at addon load
imtext.SetConfig(family, isBold, outlineWidth)
imtext.SetConfigFromSettings(font_settings)
imtext.Reset()                           -- transient cache reset on settings change
imtext.Measure(text, fontSize) -> w, h
imtext.Draw(drawList, text, x, y, argbColor, fontSize)        -- 4-cardinal outline
imtext.DrawSimple(drawList, text, x, y, argbColor, fontSize)  -- no outline
imtext.DrawShadow(drawList, text, x, y, argbColor, fontSize)  -- bottom-right shadow, cheap
imtext.GetFont()                         -- ImFont* (for direct imgui.PushFont)
```

#### B. Window backgrounds: Ashita primitives → immediate-mode drawList

| | 1.7.5 (`libs/windowbackground.lua`) | 1.8.0 (`libs/windowbackground.lua`) |
| --- | --- | --- |
| Construction | `M.createBackground(primData, theme, bgScale)` + `M.createBorders(...)` → handle table with `.bg`, `.tl`, `.tr`, etc. | None. Stateless. |
| Lifetime | Persistent primitives held by the module across frames | Immediate-mode `drawList:AddImage` every frame |
| Update | `M.updateBackground(handle, x, y, w, h, options)` per frame | `M.Draw(drawList, x, y, w, h, options)` |
| Borders | 4 separate primitive objects (tl/tr/bl/br) | Single Draw call; UV-sliced from baked corner pieces to keep 21 px line thickness at any scale |
| Cleanup | `M.destroyBackground(handle)` | Nothing to destroy |

**New API:**
```lua
windowBg.Draw(drawList, x, y, w, h, options)         -- bg + borders together
windowBg.DrawBackground(drawList, x, y, w, h, options)
windowBg.DrawBorders(drawList, x, y, w, h, options)
windowBg.GetClipBounds(x, y, w, h, options) -> { left, top, right, bottom }
windowBg.IsWindowTheme(name)  -- 'Window1'..'Window8'
-- options: { theme, padding, paddingY, bgScale, borderScale,
--           bgColor, bgOpacity, borderColor, borderOpacity, borderSize, bgOffset }
```

#### C. Standardized module interface (via `core/moduleregistry.lua`)

Every UI module now implements a uniform contract that `moduleregistry` invokes:

```lua
module.Initialize(settings)        -- one-time at load
module.UpdateVisuals(settings)     -- on settings change
module.Cleanup()                   -- at unload
module.DrawWindow(settings)        -- every frame (immediate-mode)
module.SetHidden(bool)             -- visibility toggle (gated by hasSetHidden flag)
module.ResetPositions()            -- when ResetSettings is invoked
```

`uiModules.Register(name, { module, settingsKey, configKey, hideOnEventKey, hideOnMenuFocusKey, hasSetHidden })` wires every module into the central render loop in `XIUI.lua` `d3d_present`:
```lua
for name, _ in pairs(uiModules.GetAll()) do
    uiModules.RenderModule(name, gConfig, gAdjustedSettings, eventSystemActive, menuOpen);
end
```

#### D. New `TextureManager` lifecycle rules

`libs/texturemanager.lua` gained `FlushPendingReleases()` (called at the **top** of every `d3d_present`) plus `clearOnZone()`. Releasing a D3D texture while the addon still has it queued for draw in the current frame crashes Ashita 4.3. The new pattern:

```lua
-- At top of d3d_present:
TextureManager.FlushPendingReleases();
-- ...rest of frame...
```

`ResetSettings()` is rewritten to defer the heavy visual cascade to the **next** frame (`pendingVisualUpdate = true`), specifically to keep mid-frame Lua GC from triggering `d3d8.gc_safe_release` on still-active textures. See the comment block referencing `ai/lessons.md` in `XIUI.lua`.

### 1.2 New 1.8.0 features

- **ReadyCheck module** — `modules/readycheck/init.lua` (516) + `ui.lua` (407) + `config/readycheck.lua` (70) + 4 WAV files in `modules/readycheck/sound/`. Registered into the module registry, plus a `text_in` event handler (`readycheck.HandleTextIn(e)`) and `readyCheck.HandleCommand(e)` forwarder in the `command` callback.
- **Crossbar palette command integration** — `/xiui palette` now supports `crossbar`, `cb`, `xb` suffixes; `list`, `next`, `prev`, `first` all work across hotbar and crossbar.
- **`RecoverAllPositions`** — replaces `CenterAllPositions`. Moves every window to `{20, 20}` and clears `partyListState` so `alignBottom` won't pull it back. Wired to `/xiui profile reset positions`.
- **Subtarget bar** — settings keys `showSubtargetBar`, `subtargetBar*`. Renders subtarget while subtargeting.
- **EnemyList + CastCost default positions** — `GetDefaultWindowPositions()` now also seeds `EnemyList` and `CastCost`. Inventory trackers (Satchel/Safe/Storage/Locker/Wardrobe) get a 35 px staggered y offset.
- **Mob Info expansion** — many new settings (`mobInfoShowJob`, `mobInfoShowResistances`, etc.).
- **Notification groups** — `notificationGroup1..6` factory-based, `notificationGroupCount`, `notificationTypeGroup` per-type routing. Legacy `notificationsSplit*` retained for migration.
- **Per-party config** — `partyA / partyB / partyC` via `factories.createPartyDefaults`, plus shared `layoutHorizontal` / `layoutCompact` templates.
- **Hotbar factories** — `hotbarGlobal`, `hotbarBar1..6`, `hotbarCrossbar` all produced by `core/settings/factories.lua`.
- **Pet bar avatar settings** — `petBarAvatarSettings` per-avatar offsets/scales (carbuncle, ifrit, shiva, ... + spirits). `petBarReadyBaseRecast` default 30 (retail) — note the comment says **Horizon uses 45**, so this is a setting we likely want flipped on profile init.
- **Per-pet-type defaults** — `petBarAvatar`, `petBarCharm`, `petBarJug`, `petBarAutomaton`, `petBarWyvern` factory tables.
- **NEW submodule: `submodules/xiui-icons/`** — 1.8.0 vendors a 222-file icon pack (organized by job/category: `BLM/`, `Dark Magic/`, `Elemental Magic/`, etc.) under `submodules/xiui-icons/XIUI/assets/hotbar/`. Ships its own `.git` and `LICENSE`. **This is significant for Ferris's migration**: Ferris hand-curated 97 custom hotbar icons under `assets/hotbar/items/` and elsewhere; many of these may now be obsolete because `xiui-icons` provides community-curated versions. **Phase 1 requires an icon-overlap audit** before dumping Ferris's customs back in: prefer `xiui-icons` for anything it ships, layer Ferris customs only where they fill a gap or are genuinely better.

### 1.3 Things removed in 1.8.0

- The entire `submodules/gdifonts/` directory (`.git`, `LICENSE`, `fontobject.lua`, `gdifonttexture.dll`, `include.lua`, `readme.md`, `rectobject.lua`).
- `gdi:destroy_interface()` call at unload.
- `if ClearDebuffFontCache then ClearDebuffFontCache(); end` in unload (gdi font cache is gone).
- `CenterAllPositions()` (replaced by `RecoverAllPositions()`).
- The `hideOnMenuFocusKey = 'hotbarHideOnMenuFocus'` is **kept** in 1.8.0's hotbar registration. **Status: Ferris intentionally dropped it — this is NOT a regression to restore.** See the Hotbar/Crossbar separation audit at the end of this plan: dropping the central key is required so the hotbar module can apply *per-bar-type* menu-hide (`gConfig.hotbarHideOnMenuFocus` for keyboard bars vs `gConfig.hotbarCrossbar.crossbarHideOnMenuFocus` for the crossbar) inside its own draw path. Our merged tree correctly omits the key.

### 1.4 Behavior worth knowing for Horizon (`HzLimitedMode`)

`HzLimitedMode = true` is hard-coded at the top of `XIUI.lua`. It gates several features behind `if ... and not HzLimitedMode then ...` — currently observed in:
- `gConfig.showTargetBarCastBar` gated by `not HzLimitedMode` in the action packet handler (1629).

Anything we know works on Horizon may need this flag flipped, or the gates removed. **This is the same flag in Ferris's fork** so behavior is unchanged so far, but worth a sweep.

---

## Step 1-2 — Ferris fork changes (`XIUI1.7.5` → `XIUIFerrisChanges`)

### 2.1 New files (22) — bring all of these over

These are all net-new and (except where noted) don't touch the render layer, so they can move over with very small fixups (mostly `submodules.gdifonts.*` import path → `libs.*`):

**Core / libs:**
- `core/shared_macro_store.lua` — Shared-vs-Profile macro storage. Two modes: `shared` (one global `SharedMacros.lua` file) vs `profile` (per-profile `macroDB`). Profile file holds a frozen snapshot for restore-on-switch. **No render code.**
- `libs/json.lua` — rxi's `json.lua` (MIT). Used by `palette_json.lua` for export/import. **Drop-in.**

**Config UI (depends on `imtext` after migration):**
- `config/crossbar.lua` — sidebar entry; thin shell that delegates to `crossbar_settings.lua`.
- `config/crossbar_settings.lua` — **70 KB**. Full crossbar settings UI (controller layout, palettes, visuals). **Uses `imgui` directly; no gdi.** Heavy ImGui form work — should port mostly verbatim.
- `config/efp_pets_tab.lua` — "Edit Full Palette" pets tab (pick avatar/elemental/beast/wyvern/puppet family + concrete key).
- ~~`config/palettemanager.lua`~~ — **Correction**: this file already exists in 1.7.5 *and* 1.8.0 as a 27.9 KB stub (both identical). Ferris expanded it to **146 KB**. So it's a **Ferris-only-modified file (group A in §2.2)**, not a new file. Same content as before: Floating Palette Manager window (hotbar + crossbar) + shared create/rename/copy modals. **Uses `imgui` directly; check for `gdi.Alignment` in the body.** Still the **single largest piece of Ferris's work.**

**Hotbar / macro / palette system (the real meat of Ferris's fork):**
- `modules/hotbar/macropalette_macroeditor.lua` — **86 KB**. Multi-line macro editor with icon picker and corner-badge logic. Closure-based extension of `macropalette`. Likely contains `gdi.Alignment` references and `FontManager.create` for the icon-picker text — needs migration.
- `modules/hotbar/macroparse.lua` — Multi-line macro parser. Returns primary action + corner badge per Ferris's priority rules (`/ws,/ma,/pet` → `/ja` → `/item,/equip` → other).
- `modules/hotbar/macro_palette_buckets.lua` — Bucket schema (`global`, `items`, `equipment`, `xiui`, `custom:*`) used by the palette editor.
- `modules/hotbar/macro_xiui_defaults.lua` — Default `/xiui` slash macros (Toggle XIUI Menu, Open Macros, Hotbar Palette Manager, Crossbar Palette Manager, etc.). One-time seed gated by `macroXiuiDefaultsSeeded`.
- `modules/hotbar/macro_global_defaults.lua` — Universal-2-Hour global macro seed.
- `modules/hotbar/universal_two_hour.lua` — Job ID → 2-hour ability name lookup (Horizon-specific list). Drives the pink-star marker, the JA-list sort, and the resolution of the global Universal-2-Hour macro.
- `modules/hotbar/pet_palette_allowlist.lua` — Pet-type filter (avatars / elementals / beasts / wyvern / puppet). Per-character on `hotbarCrossbar.petPalettePetKeys`. Includes legacy-token migration.
- `modules/hotbar/iconmatch.lua` — Fuzzy name-to-icon matcher (normalize + prefix/contain check).
- `modules/hotbar/customiconresolve.lua` — Resolves `assets/hotbar/custom/*.png` by action name (recursive scan, same rules as the macro editor).
- `modules/hotbar/equipment_ws.lua` — WS cache-bust signature (`job + levels + level sync + main/sub/range item ids`). Drives WS list refresh on gear swap.
- `modules/hotbar/palette_json.lua` — **40 KB**. JSON export/import (`xiuiExportVersion 1`, `kind xiui_profile`) for an entire profile: hotbar palettes + crossbar palettes + macro library. Imports support partial application (palettes only, macros only, or both).

**Horizon-specific data tables (`modules/hotbar/database/`):**
- `horizon_abilities.lua` — Static JA lookup (job + level + pet?). Sourced from HorizonXI JA Progression spreadsheet.
- `horizon_bloodpacts.lua` — Synthetic spell-shaped rows for SMN blood pacts (id, en name, mp_cost, smn_lv, kind=rage|ward). Synthetic ids start at 10200.
- `horizon_bloodpacts_xiui.lua` — XIUI-only overlay for blood pacts (status labels, corner icons, `requiresFlow`).
- `horizon_retail_only_job_abilities.lua` — Set of JAs to exclude from Horizon (Bestial Loyalty, Feral Howl, Killer Instinct, Unleash, Snarl, Spur, Run Wild).
- `horizon_spell_omissions.lua` — Spells to exclude from "Show All" (V/VI nukes, etc.).
- `ws_weapon_types.lua` — WS-to-weapon-type + skill requirement + relic flag.

### 2.2 Truly-modified files Ferris touched (39)

Split into two groups based on what 1.8.0 did:

**A. Ferris-only modified (12) — 1.8.0 didn't touch these. Safe to carry over (after gdi cleanup if any):**
- `config/palettemanager.lua` — 27.9 KB stub in both 1.7.5 and 1.8.0 (identical); Ferris expanded to **146 KB**. Single largest piece of Ferris work. **Uses `imgui` directly; check for `gdi.Alignment`.** Phase 1 overwrites the 1.8.0 stub.
- `core/gamestate.lua` — additions for menu/container detection.
- `handlers/imgui_compat.lua` — Ferris's compatibility shim.
- `libs/drawing.lua` — Ferris extensions.
- `libs/target.lua` — Ferris extensions.
- `modules/hotbar/database/horizonspells.lua` — Horizon spell data (Ferris extended this).
- `modules/hotbar/controller.lua` — Crossbar controller handling.
- `modules/hotbar/palette.lua` — Palette state/storage (huge Ferris additions).
- `modules/hotbar/petpalette.lua` — Pet palette logic.
- `modules/hotbar/petregistry.lua` — Pet registry / BP merge.
- `modules/hotbar/skillchain.lua` — Skillchain tracking (`skillchainModule` referenced from XIUI.lua).
- `modules/hotbar/textures.lua` — Custom texture resolution.

**B. Conflict surface (27) — both Ferris and 1.8.0 modified. 3-way merge required:**

| File | Why Ferris touched it | Why 1.8.0 touched it | Strategy |
| --- | --- | --- | --- |
| `XIUI.lua` | sharedMacroStore wire-up, paletteManager, `/xiui cpal*` commands, `imgui.SetMouseCursor`, charSettings.knownWeaponskills | imtext.PrewarmFonts, readyCheck wiring, slotrenderer.FlushTooltip, RecoverAllPositions, TextureManager.FlushPendingReleases, ResetSettings deferral | Take 1.8.0 as base, reapply Ferris's adds (see §3 for the precise list). |
| `config.lua` | Likely new tabs/menu entries for crossbar/palettemanager | Likely ReadyCheck tab + 1.8.0 settings | Take 1.8.0, re-add Ferris's tab registrations + `paletteManager.Draw()` hook. |
| `config/components.lua` | available_fonts edits? | imtext-aware components | Take 1.8.0; merge Ferris's lists. |
| `config/global.lua` | Likely new global settings | Refactor for new settings shape | Take 1.8.0; reapply Ferris-specific options. |
| `config/hotbar.lua` | Crossbar/palette/keybinds UI work | New keyBindings, factory-based defaults, OpenKeybindEditor | Take 1.8.0 as base, layer Ferris's controller/palette additions; verify `OpenKeybindEditor` still works for Ferris's flow. |
| `config/petbar.lua` | Pet-type / pet allowlist UI | Per-pet-type / avatar settings | Take 1.8.0, port Ferris's allowlist UI. |
| `core/settings/factories.lua` | Custom factories for Ferris features | New factories (crossbar, hotbar global/bar, party, notification group, pet types) | Take 1.8.0, add Ferris-specific factories alongside. |
| `core/settings/migration.lua` | sharedMacroStore migration, macroDB shape, knownWeaponskills | HXUI migration, palette migration | Take 1.8.0, append Ferris migration steps; ensure runs after 1.8.0's. |
| `core/settings/user.lua` | Ferris settings (crossbar, palette, macro) | Massive new settings (factories) | Take 1.8.0, merge Ferris keys in. Watch out for: `hotbarCrossbar.petPalettePetKeys`, `knownWeaponskills` (per-char), `macroDB`, `macroStorageScope`, `macroCustomCategories`, `macroCustomNextSeq`, `macroXiuiDefaultsSeeded`, `macroGlobalUniversalTwoHourSeeded`. |
| `handlers/helpers.lua` | Possibly extensions | Thin re-export shim (modularized to libs/) | Take 1.8.0; if Ferris added globals, expose them via `libs/` and re-export here. |
| `handlers/statushandler.lua` | gdi encoding import, debuff text via gdi | Cache lifecycle (`clear_cache`, `clear_zone_cache`) | Take 1.8.0; replace `submodules.gdifonts.encoding` → `libs.encoding`. |
| `libs/dragdrop.lua` | Ferris drag/drop extensions for palette editor | 1.8.0 simplifications | 3-way merge; Ferris likely added drop-zone hooks that `palettemanager.lua` and `hotbar.FinalizeFrame` depend on. |
| `libs/texturemanager.lua` | Ferris cache tuning? | `FlushPendingReleases`, `clearOnZone`, evictions | Take 1.8.0 as base; reapply any Ferris key changes. |
| `modules/castcost/display.lua` | Horizon ability cost handling | Rewrite using `imtext` + new windowBg | Take 1.8.0; port Ferris's logic into new draw shape. |
| `modules/hotbar/actions.lua` | Macro execution / palette dispatch | Refactor for new architecture | 3-way merge — critical. |
| `modules/hotbar/crossbar.lua` | Heavy Ferris extensions | Massive rewrite (–882 lines) | **Hardest port.** Take 1.8.0 as base; layer Ferris's controller / palette / BP logic on top using the new slotrenderer / data interfaces. |
| `modules/hotbar/data.lua` | Macro/palette cache + Horizon DB integration | Refactor (–372 lines) | **Hard.** Many Ferris fields touch macroDB shape, paletteState, cache invalidation hooks (e.g. `InvalidateConfigDerivedCaches`, `StripPaletteMacroBindsFromSettings`, `SetPlayerJob`). Need to re-add atop new structure. |
| `modules/hotbar/display.lua` | Custom slot draw path | Refactor (–470 lines) | **Hard.** Take 1.8.0 draw path; reapply Ferris's pet-palette / macro-badge integration. |
| `modules/hotbar/init.lua` | gdi font setup per slot, Ferris methods | Refactor (–404 lines), exposes more methods (`SetDebugEnabled`, `IsPaletteDebugEnabled`, `HandlePetSyncPacket`, `FinalizeFrame`, etc.) | **Hard.** Replace `FontManager.create` patterns with `imtext`. Re-add Ferris methods (`hotbar.FinalizeFrame` referenced from XIUI.lua). |
| `modules/hotbar/macropalette.lua` | Ferris extended into `macropalette_macroeditor.lua` closure | 1.8.0 refactor | Take 1.8.0; ensure the `macropalette_macroeditor.lua` extension still attaches correctly (it calls `MP.*` methods). |
| `modules/hotbar/playerdata.lua` | `SetKnownWeaponskills`, equipment WS cache | Refactor (–65 lines) | Take 1.8.0; add `SetKnownWeaponskills` + equipment_ws hook. |
| `modules/hotbar/recast.lua` | BP shared-timer (173/174) name lookup | Refactor (–58 lines) | Take 1.8.0; reapply Ferris BP name-based timer resolution. |
| `modules/hotbar/slotrenderer.lua` | Custom slot art / macro badge / palette overlay | **Largest refactor in 1.8.0 (–1158 lines)** plus new `FlushTooltip()` for deferred z-order | **Hardest.** Take 1.8.0; port Ferris's badge / pet-palette / custom-icon resolve logic. Use `imtext.DrawShadow` (single shadow, not full outline) for hot per-slot text. |
| `modules/partylist/display.lua` | Ferris extensions (gdi encoding for names) | imtext + immediate-mode rewrite (462 changes) | Take 1.8.0; replace `submodules.gdifonts.encoding` → `libs.encoding`. |
| `modules/petbar/data.lua` | Ferris pet palette/keying | Per-pet-type settings refactor (–467 lines) | Take 1.8.0; port Ferris key extensions. |
| `modules/petbar/display.lua` | Custom pet image positioning per family | imtext rewrite + per-avatar offsets (–396 lines) | Take 1.8.0; verify Ferris's per-family overrides survived (the 1.8.0 `petBarAvatarSettings` likely subsumes them). |
| `modules/petbar/pettarget.lua` | Custom target text via gdi | Refactor (–307 lines) | Take 1.8.0; replace gdi-based text with `imtext`. |

---

## Step 2-1 — Ferris → 1.8.0 problems & overlaps

### 3.1 Hard breakages (will not run as-is)

1. **Every `require('submodules.gdifonts.include')` will fail** — submodule deleted. **24 files** in Ferris reference it. Each needs to be removed; `gdi.Alignment.*` → caller-side positioning (or remove from settings), `gdi.FontFlags.*` → `libs.fontconst.FLAG_*` (same numeric values).
2. **Every `require('submodules.gdifonts.encoding')` will fail** — file moved. Mechanical fix: replace with `require('libs.encoding')`. Affected files in Ferris:
   - `modules/treasurepool/init.lua`
   - `modules/targetbar.lua`
   - `modules/partylist/init.lua`
   - `modules/partylist/display.lua`
   - `modules/castcost/data.lua`
   - `modules/castbar.lua`
   - `handlers/statushandler.lua`
3. **`FontManager.create / recreate / destroy` and the persistent text-object pattern is dead.** Every module that builds `data.hpText`, `data.mpText`, `data.tpText`, etc. needs to be rewritten for immediate-mode `imtext.Draw`. Affected modules:
   - `modules/playerbar.lua` — hp/mp/tp text with per-stat alignment
   - `modules/petbar/init.lua` — `data.hpText/mpText/tpText` + `set_font_alignment`
   - `modules/petbar/pettarget.lua` — `targetHpText`
   - `modules/partylist/init.lua` — all party text
   - `modules/notifications/init.lua` — per-group `groupTitleFonts` + `groupSubtitleFonts`
   - `modules/hotbar/init.lua` — `lblFonts`, `timerFonts`, `mpFonts`, `qtyFonts`, `abbrFonts` per slot per bar
   - `modules/giltracker.lua` — `gilPerHourText`
   - `modules/expbar.lua`, `modules/castbar.lua`, `modules/enemylist.lua`, `modules/castcost/display.lua`, `modules/mobinfo/display.lua`, `modules/inventory/base.lua`
   - `libs/statusicons.lua` — debuff timer text (`gdi:create_object` / `gdi:destroy_object`)
   - `libs/fonts.lua` — the whole `FontManager` itself
4. **`primitives:new(primData)` for backgrounds is dead.** Anywhere Ferris (or pre-1.8.0 modules Ferris carried) calls `primitives:new` for background tiles needs to switch to `windowBg.Draw(drawList, x, y, w, h, options)`. Mostly Ferris just inherited 1.7.5 code here — most module rewrites in 1.8.0 already handle this.
5. **`gdi:destroy_interface()` at unload** — removed in 1.8.0. Delete from Ferris's `unload` callback.
6. **`if ClearDebuffFontCache then ClearDebuffFontCache(); end`** — remove from unload.
7. **`hideOnMenuFocusKey = 'hotbarHideOnMenuFocus'` was dropped by Ferris in the hotbar Register call. NOT a regression — keep it dropped.** Ferris's `modules/hotbar/init.lua` now branches into keyboard hotbars (`gConfig.hotbarHideOnMenuFocus`) and the crossbar (`gConfig.hotbarCrossbar.crossbarHideOnMenuFocus`) inside its own draw path. If the central moduleregistry hides the whole hotbar entry on menu open, BOTH sides go dark together (defeating Ferris's per-bar-type split). Our merged `XIUI.lua` correctly omits this key.

### 3.2 Overlaps — work duplication / collisions

1. **Palette commands in XIUI.lua.** 1.8.0 unified `/xiui palette` to accept `crossbar / cb / xb` suffixes. Ferris built a parallel `/xiui cpalette / cpal / xcpalette / xcpal` system with richer job/SJ logic, scope toggle, RB+D-pad hints, and a separate `/xiui pal` (no args) toggle for the Palette Manager. **Strategy:** keep both. The 1.8.0 `palette` command stays as the discoverable simple path; Ferris's `cpalette` family stays for advanced job/SJ targeting. They never conflict on the parser — different keywords.
2. **`crossbarEnabled` flag.** Ferris introduced `gConfig.crossbarEnabled` as a separate gate from `gConfig.hotbarEnabled` and uses `if gConfig.hotbarEnabled or gConfig.crossbarEnabled` in several packet handlers. 1.8.0 didn't add this — it gates crossbar via `gConfig.hotbarCrossbar` settings table fields. **Decision needed:** keep Ferris's separate flag (more granular UX) or fold back into 1.8.0's pattern (simpler, but loses standalone crossbar-without-hotbar). Recommend **keep Ferris's flag** and add it to defaults so it's always present.
3. **`GetDefaultWindowPositions` was moved earlier in 1.8.0** (forward-declared and called at load time) and added EnemyList/CastCost/staggered inventory positions. Ferris's version is older. **Take 1.8.0's version verbatim.**
4. **`SaveSettingsToDisk` / `SaveSettingsOnly` / `ChangeProfile` / `ResetSettings`** — Ferris wrapped these to call a new `SaveCurrentProfileFileToDisk()` helper that handles `sharedMacroStore` shared-vs-profile macro storage. 1.8.0 didn't refactor these the same way. **Strategy:** keep Ferris's `SaveCurrentProfileFileToDisk()` wrapper and have it call into 1.8.0's `profileManager.SaveProfileSettings` after the macroDB swap. Also: 1.8.0 rewrote `ResetSettings` to use `SaveSettingsOnly + DeferredUpdateVisuals` (avoids mid-frame GC). The Ferris wrapper must preserve that deferral.
5. **`DuplicateProfile(name, options)`** — Ferris added `options.includeMacroLibrary`. Wrap on top of 1.8.0's `DuplicateProfile(name)`.
6. **`d3d_present` top-of-frame** — both 1.8.0 and Ferris added work here:
   - 1.8.0 added `TextureManager.FlushPendingReleases()` (must be FIRST)
   - Ferris added `imgui.SetMouseCursor(0)` to fix alt-tab cursor
   - **Strategy:** keep both, in that order: FlushPendingReleases first, then SetMouseCursor reset.
7. **`d3d_present` after `configMenu.DrawWindow()`:**
   - 1.8.0 added `slotrenderer.FlushTooltip()` (deferred tooltip z-order)
   - Ferris added `paletteManager.Draw()` and `hotbar.FinalizeFrame()`
   - **Strategy:** keep all three. Order: `configMenu.DrawWindow()` → `paletteManager.Draw()` → `slotrenderer.FlushTooltip()` → `hotbar.FinalizeFrame()` (FinalizeFrame should be last so drag/drop sees palette editor drop zones).
8. **Profile load callbacks** — Ferris added `sharedMacroStore.ApplyAfterProfileLoad`, `xiuiInvalidateHotbarDataCaches`, `xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad` after every profile load (initial load, `ChangeProfile`, `settings_update`, `ResetSettings`). 1.8.0 has its own ordering in those functions. **Strategy:** in 1.8.0's versions of those functions, append Ferris's three calls in the same order (after `RunStructureMigrations`).

### 3.3 Things 1.8.0 fixed that Ferris was also working around

- **`imtext.PrewarmFonts(components.available_fonts)`** at `load` solves the mid-frame `AddFontFromFileTTF` → atlas mutation → `EXCEPTION_ACCESS_VIOLATION` crash. If Ferris had any workarounds for font reloads in the config menu, those can be removed.
- **`TextureManager.FlushPendingReleases()`** at top of frame + `ResetSettings` deferral fixes mid-frame GC → `d3d8.gc_safe_release` → CTD on Ashita 4.3. Any Ferris hot-fixes around `gConfig` replacement or texture clear can be removed in favor of the new pattern.
- **Per-pet-type settings** (`petBarAvatar`, `petBarCharm`, etc.) and `petBarAvatarSettings` per-family in 1.8.0 may already cover features Ferris built into petbar/petpalette. Audit `modules/petbar/data.lua` and `petpalette.lua` after migration.
- **`config/components.lua`'s `available_fonts`** — 1.8.0 reads this for `imtext.PrewarmFonts`. If Ferris added any fonts to the picker, they'll be auto-prewarmed once we take 1.8.0's load callback.

### 3.4 Notable known-unknowns (verify during execution)

- `hotbarData.SetPlayerJob`, `InvalidateConfigDerivedCaches`, `StripPaletteMacroBindsFromSettings` — Ferris's names. Verify they exist on 1.8.0's refactored `modules/hotbar/data.lua`; if not, port them.
- `paletteMod.ValidatePalettesForJob`, `NotifyProfileSettingsLoaded`, `SetCpalJobAnchorIfUnset`, `SetCpalUniversalAnchorIfUnset`, `SetCrossbarCliPreview`, etc. — Ferris's palette API. Mostly lives in Ferris-only `modules/hotbar/palette.lua`, but verify 1.8.0's palette didn't add overlapping names.
- `gConfig.partyListState` — Ferris uses for crossbar; 1.8.0's `RecoverAllPositions` clears it. Confirm shape is the same.
- The 1.8.0 `petBarReadyBaseRecast = 30` default comment says **Horizon = 45**. Patch the default in our fork or document.

---

## Step 3 — Migration plan / what to port

The migration runs in **phases**, in order. Don't move to the next until the previous is at the "smoke-tests cleanly" bar.

> **Working strategy:** treat `XIUI1.8.0` as the trunk. Rebase Ferris's changes onto it file-by-file, **not** the other way around. The 1.8.0 versions of the 27 conflict-surface files are the new base — Ferris's edits get re-applied on top.

### Phase 0 — Tree setup (no code changes) — ✅ EXECUTED
- [x] Backup commit tagged on `backup/master-before-1.8.0` (at `b73fb6a` "Crossbar menu-disable option, party list anchor fixes, manifest pr/25"). The `XIUIFerrisChanges` directory is the on-disk snapshot.
- [x] `XIUI/` working tree replaced with `XIUI1.8.0/*` baseline. Preserved Ferris-local metadata (`.cursor/`, `.gitignore`, `MIGRATION_1.8.0_PLAN.md`, gitignored `scripts/*`). Tracked Ferris script files (`bst_retail_sheet_sync.py`, `feature-pr-manifest.ps1`, `gen_horizon_bloodpacts.py`, `strip-nerf-deltas.ps1`) currently show as deleted — they come back in Phase 1.
- [x] `git status` confirms expected shape: 7 untracked new 1.8.0 files (including new `submodules/xiui-icons/` with 222 icons), 22 deleted Ferris-new `.lua` files matching §2.1, 97 deleted Ferris-custom PNGs, ~263 modified files in `submodules/mobdb/data/` (mostly CRLF noise to be confirmed), real semantic edits across the conflict-surface files.
- [ ] **Pending user OK:** commit Phase 0 as "Reset working tree to upstream XIUI 1.8.0 baseline". Until commit, the tree is staged-equivalent and can still be rolled back via `git checkout -- .`.
- [ ] Optionally smoke-test `XIUI1.8.0` standalone (separate Ashita install) before Phase 1, to confirm base 1.8.0 works on Horizon.

### Phase 1 — Drop in 1.8.0 trunk + bring across pure Ferris additions
*Goal: tree compiles, addon loads, only base 1.8.0 features work; Ferris assets are present but not yet wired up.*

- [ ] **Icon-overlap audit** (new step — discovered during Phase 0): `submodules/xiui-icons/XIUI/assets/hotbar/` ships 222 community-curated icons in 1.8.0. Cross-reference against Ferris's 97 custom PNGs under `assets/hotbar/items/` (and any others under `assets/hotbar/<job>/`). For each Ferris custom: (a) if `xiui-icons` ships an equivalent, drop the Ferris custom; (b) if Ferris's is genuinely better/different, keep it under `assets/hotbar/custom/` (matches `customiconresolve.lua` recursion path). Don't blindly restore all 97.
- [ ] Copy in all 22 Ferris-new files (§2.1) into the matching paths under the new `XIUI` (1.8.0 base). Adjust each import in those files: `submodules.gdifonts.encoding` → `libs.encoding`. (No `submodules.gdifonts.include` should appear in these new files — verify.)
- [ ] Restore Ferris's tracked scripts: `scripts/bst_retail_sheet_sync.py`, `scripts/feature-pr-manifest.ps1`, `scripts/gen_horizon_bloodpacts.py`, `scripts/strip-nerf-deltas.ps1` (from `backup/master-before-1.8.0`).
- [ ] Bring across the 12 Ferris-only-modified files (§B above) **but** rewrite any gdi-font dependency:
  - [ ] `handlers/imgui_compat.lua` — should be pure ImGui compat, no gdi.
  - [ ] `core/gamestate.lua` — likely no gdi.
  - [ ] `libs/drawing.lua`, `libs/target.lua` — likely no gdi.
  - [ ] `modules/hotbar/database/horizonspells.lua` — pure data.
  - [ ] `modules/hotbar/controller.lua` — controller input only.
  - [ ] `modules/hotbar/palette.lua` — palette state. Verify no gdi (it's a state module, should be fine).
  - [ ] `modules/hotbar/petpalette.lua`, `petregistry.lua`, `skillchain.lua`, `textures.lua` — verify each.
- [ ] Smoke-test: addon loads, base 1.8.0 UI renders, hotbar/crossbar empty but no crashes.

### Phase 2 — Reconcile the entry point (`XIUI.lua` + `config.lua`)
*Goal: ReadyCheck + Ferris's macro/palette plumbing both work from the main entry.*

For `XIUI.lua`, take 1.8.0's file and additively layer Ferris's changes:
- [ ] Add `local sharedMacroStore = require('core.shared_macro_store');` next to the other core requires.
- [ ] Add `local paletteManager = require('config.palettemanager');` next to other config requires.
- [ ] Add Ferris's `xiuiInvalidateHotbarDataCaches` and `xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad` helpers verbatim.
- [ ] In `settings.load({})` → `settings.load(T{})` calls (2 of them) — apply Ferris's `T{}` tagging (safer for Ashita).
- [ ] After `gConfig` loads, add the per-character `charSettings.knownWeaponskills` init + `playerdata.SetKnownWeaponskills` call.
- [ ] After `RunStructureMigrations(gConfig, defaultUserSettings)`, **also** call:
  ```lua
  sharedMacroStore.ApplyAfterProfileLoad(gConfig);
  xiuiInvalidateHotbarDataCaches();
  xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad();
  ```
  Do the same in `ChangeProfile`, `ResetSettings`, and the `settings_update` callback.
- [ ] Add Ferris's `SaveCurrentProfileFileToDisk` helper; replace direct `profileManager.SaveProfileSettings(config.currentProfile, gConfig)` calls inside `ChangeProfile`, `ResetSettings`, `SaveSettingsToDisk`, `SaveSettingsOnly`, `RecoverAllPositions` (was `CenterAllPositions` in Ferris) with `SaveCurrentProfileFileToDisk()`.
- [ ] Wrap `DuplicateProfile(name)` → `DuplicateProfile(name, options)` per §3.2 #5.
- [ ] In `d3d_present`, after `TextureManager.FlushPendingReleases()` add Ferris's `imgui.SetMouseCursor(0)` reset.
- [ ] In `d3d_present`'s render block, after `configMenu.DrawWindow()` add `paletteManager.Draw()`. Keep `slotrenderer.FlushTooltip()` after that. Then call `hotbar.FinalizeFrame()` last (if defined).
- [ ] Add Ferris's debug command `/xiui menuname` (small block).
- [ ] Add Ferris's `/xiui pal` toggle (no-args) + the entire `/xiui cpalette / cpal / xcpalette / xcpal` command system. Do **not** replace 1.8.0's unified `/xiui palette` block — they coexist.
- [ ] Add Ferris's `cpaledit` command.
- [ ] In packet handlers: replace `if gConfig.hotbarEnabled` with `if gConfig.hotbarEnabled or gConfig.crossbarEnabled` for the four spots Ferris diverged (`0x0068`, `0x0028` skillchain, `0x00A` zone-in, `0x00B` zone-out, `0x001B` job change).
- [x] ~~Restore the `hideOnMenuFocusKey = 'hotbarHideOnMenuFocus'` line in the hotbar `uiModules.Register`~~ **CORRECTED: keep the line REMOVED.** Ferris intentionally dropped it so `modules/hotbar/init.lua` can branch keyboard vs crossbar menu-hide separately (`gConfig.hotbarHideOnMenuFocus` vs `gConfig.hotbarCrossbar.crossbarHideOnMenuFocus`). Reintroducing the key would collapse both sides into a single shared toggle.

For `config.lua`:
- [ ] Take 1.8.0 as base. Add Ferris's tabs (Crossbar, Palette Manager) and the routing for them. Verify `paletteManager.ToggleHotbarPaletteManager`, `paletteManager.ToggleEditFullPaletteForCurrent`, `configMenu.ToggleCrossbarManagePalettes` are wired correctly.

### Phase 3 — Settings system reconciliation (`core/settings/*`)
*Goal: every Ferris setting key exists in defaults with the right factory, and migrations run from old shape.*

- [ ] `core/settings/user.lua` — take 1.8.0, merge Ferris's keys: `crossbarEnabled`, `macroDB`, `macroStorageScope`, `macroCustomCategories`, `macroCustomNextSeq`, `macroXiuiDefaultsSeeded`, `macroGlobalUniversalTwoHourSeeded`, `knownWeaponskills` (per-char, lives on charSettings not gConfig), any pet-palette-allowlist keys, and the various `cpalette` storage keys (`hotbarCrossbar.slotActions[...]`, `hotbarCrossbar.petPalettePetKeys`).
- [ ] `core/settings/factories.lua` — take 1.8.0; add Ferris's factories for crossbar palette storage if needed.
- [ ] `core/settings/migration.lua` — take 1.8.0; append Ferris-specific migrations (legacy macro shape → bucketed shape, legacy pet allowlist tokens, etc.). Confirm `RunStructureMigrations` is idempotent.
- [ ] `core/settings/modules.lua` — take 1.8.0. Where Ferris had `gdi.Alignment.X` or `gdi.FontFlags.X` in font settings: replace numerics directly (`gdi.Alignment.Left = 0`, `Center = 1`, `Right = 2`; `FontFlags.None = 0`, `Bold = 1`, `Italic = 2`). Better: introduce a tiny local enum in this file (or import `libs.fontconst`) and use those names so the file stays readable.
- [ ] `core/settings/updater.lua` — take 1.8.0; reapply Ferris's font-flag adjustments using `libs.fontconst.FLAG_BOLD` etc. **Do NOT** use the `gdi` import.
- [ ] `core/settings/user.lua`: bump `petBarReadyBaseRecast` default to **45** for our HX fork (or leave at 30 with a comment for retail parity — user's call).

### Phase 4 — Handlers + libs (mostly mechanical de-gdi)
*Goal: anything in `handlers/` and `libs/` that Ferris touched is back to working, with no gdi remnants.*

- [ ] `handlers/helpers.lua` — take 1.8.0 (it became a thin re-export shim).
- [ ] `handlers/statushandler.lua` — take 1.8.0; change `require('submodules.gdifonts.encoding')` → `require('libs.encoding')`.
- [ ] `handlers/tbar_migration.lua` — take 1.8.0 (Ferris hadn't touched it).
- [ ] `libs/dragdrop.lua` — 3-way merge: take 1.8.0 plus Ferris's drop-zone hooks the palette editor needs (verify with palettemanager.lua callsites).
- [ ] `libs/fonts.lua` — take 1.8.0 (5-line shim using `libs.fontconst`). **Delete Ferris's `FontManager` entirely.** Any caller of `FontManager.create / recreate / destroy` is a bug.
- [ ] `libs/statusicons.lua` — take 1.8.0. Replace any persistent debuff-timer `gdi:create_object` with an `imtext.Draw` in the per-frame call.
- [ ] `libs/texturemanager.lua` — take 1.8.0.
- [ ] `libs/button.lua`, `libs/progressbar.lua`, `libs/windowbackground.lua` — take 1.8.0 as-is (Ferris untouched).

### Phase 5 — Module rewrites (the heavy lifting)
*Goal: each conflict-surface module renders correctly on 1.8.0, with Ferris's customizations preserved.*

Do these in order; **don't move on until each smoke-tests in-game.**

#### 5.1 Simpler modules (mechanical merge)
- [ ] `modules/notifications/data.lua`, `display.lua`, `init.lua` — take 1.8.0; replace Ferris's per-group `groupTitleFonts / groupSubtitleFonts` with `imtext.Draw` calls. Ferris's per-group split is now `notificationGroup1..6` in 1.8.0 — confirm migration path.
- [ ] `modules/inventory/base.lua` — take 1.8.0; replace any gdi text with `imtext.Draw`. Add Ferris customizations on top.
- [ ] `modules/mobinfo/display.lua` — take 1.8.0 (large refactor); reapply any Ferris UI tweaks.
- [ ] `modules/treasurepool/data.lua`, `display.lua`, `init.lua` — take 1.8.0; replace encoding import path.
- [ ] `modules/castcost/data.lua`, `display.lua` — take 1.8.0; replace gdi text + encoding import. Add Ferris's Horizon ability-cost handling.
- [ ] `modules/castbar.lua` — take 1.8.0; replace gdi + encoding. Reapply Ferris additions.
- [ ] `modules/playerbar.lua` — take 1.8.0. Reapply Ferris's per-stat text alignment using `imtext.Measure` + caller-side positioning (Left/Center/Right computed from bookend + bar width — see new partylist/display.lua for the pattern).
- [ ] `modules/targetbar.lua` — take 1.8.0; replace gdi + encoding.
- [ ] `modules/enemylist.lua` — take 1.8.0; replace gdi.
- [ ] `modules/expbar.lua` — take 1.8.0; replace gdi.
- [ ] `modules/giltracker.lua` — take 1.8.0; replace gdi + the `gilPerHourText` font alignment.
- [ ] `modules/partylist/data.lua`, `display.lua`, `init.lua` — take 1.8.0; replace gdi + encoding. The new `display.lua` already uses `imtext` correctly.

#### 5.2 Pet bar
- [ ] `modules/petbar/init.lua` — take 1.8.0; replace `data.hpText/mpText/tpText` + `set_font_alignment` calls with per-frame `imtext.Draw` in the display module.
- [ ] `modules/petbar/data.lua` — take 1.8.0; merge Ferris's pet-palette keying.
- [ ] `modules/petbar/display.lua` — take 1.8.0; verify per-avatar offsets from `petBarAvatarSettings` subsume Ferris's customizations.
- [ ] `modules/petbar/pettarget.lua` — take 1.8.0; replace `targetHpText` with immediate-mode `imtext.Draw`.

#### 5.3 Hotbar (the big one)
- [ ] `modules/hotbar/init.lua` — take 1.8.0. **Strip out every `lblFonts/timerFonts/mpFonts/qtyFonts/abbrFonts` table** — all per-slot text now goes through `imtext` in `slotrenderer`. Add back Ferris's methods that XIUI.lua references: `hotbar.FinalizeFrame`, `hotbar.SetDebugEnabled / IsDebugEnabled / SetPaletteDebugEnabled / IsPaletteDebugEnabled`, `hotbar.HandlePetSyncPacket`, etc. — verify each is already in 1.8.0; if missing, port.
- [ ] `modules/hotbar/data.lua` — take 1.8.0. Port the following Ferris-added methods (used elsewhere): `data.InvalidateConfigDerivedCaches`, `data.SetPlayerJob`, `data.StripPaletteMacroBindsFromSettings`, `data.jobId / subjobId` (these likely already exist).
- [ ] `modules/hotbar/display.lua` — take 1.8.0. Verify per-slot draw still calls into slotrenderer correctly; layer Ferris's pet-palette/macro-badge integration.
- [ ] `modules/hotbar/slotrenderer.lua` — **the hardest port.** Take 1.8.0 (–1158 lines refactor) and reapply Ferris's:
  - Macro-corner badge logic (driven by `macroparse.GetMacroPrimaryAndJaBadge`).
  - Custom icon resolution (`customiconresolve.lua`).
  - Pink-star 2-hour marker (`universal_two_hour.lua`).
  - Universal-2-hour macro icon resolution (`macro_global_defaults.IsUniversalTwoHourMacro`).
  - Use `imtext.DrawShadow` (1 shadow vs 4-cardinal outline) for hot per-slot text — it's deliberately the cheaper variant; cost matters when 60 slots × 60 fps × many text labels.
  - Ferris's deferred tooltip handling integrates with 1.8.0's new `FlushTooltip()` — verify ordering.
- [ ] `modules/hotbar/crossbar.lua` — **the second-hardest port** (–882 lines refactor). Take 1.8.0; layer Ferris's controller integration (palette job/SJ scope, RB+D-pad cycle, pet palette allowlist, BP slot rendering). Cross-reference `config/crossbar_settings.lua` for which methods it expects.
- [ ] `modules/hotbar/actions.lua` — take 1.8.0; port Ferris's macro-action / palette-action dispatch (`HandleKeybind`, palette-macro bindings).
- [ ] `modules/hotbar/macropalette.lua` — take 1.8.0. **Verify** Ferris's `macropalette_macroeditor.lua` closure still attaches via the `return function(MP) return function() ... end end` pattern — that depends on internals of macropalette being named the same way (`MP.editingMacro`, `MP.HydrateMacroEditorIconPrefs`, etc.). If 1.8.0 renamed these, the editor closure needs minor edits.
- [ ] `modules/hotbar/playerdata.lua` — take 1.8.0; add `SetKnownWeaponskills` + `equipment_ws` cache hook.
- [ ] `modules/hotbar/recast.lua` — take 1.8.0; reapply Ferris's BP timer 173/174 name-based lookup.

#### 5.4 Configs
- [ ] `config/components.lua` — take 1.8.0; merge Ferris's font/option lists.
- [ ] `config/global.lua` — take 1.8.0; add Ferris's global settings (shared macro scope, etc.).
- [ ] `config/hotbar.lua` — take 1.8.0; layer Ferris's keybind editor / palette UI hooks.
- [ ] `config/petbar.lua` — take 1.8.0; add Ferris's pet palette allowlist UI (uses `efp_pets_tab.lua` for the inner content).
- [ ] `config/expbar.lua`, `partylist.lua`, `treasurepool.lua` — take 1.8.0 (Ferris didn't customize).
- [ ] `config/castbar.lua`, `castcost.lua`, `enemylist.lua`, `giltracker.lua`, `inventory.lua`, `migration.lua`, `notifications.lua`, `playerbar.lua`, `targetbar.lua` — these are Ferris-only-modified; bring forward then de-gdi.

### Phase 6 — Audit pass
- [ ] `rg -n 'submodules\.gdifonts' addons/XIUI` — must return zero hits.
- [ ] `rg -n 'gdi\.|gdi:' addons/XIUI` — must return zero hits (except as a local name in `core/settings/modules.lua` if we choose that route).
- [ ] `rg -n 'FontManager\.' addons/XIUI` — must return zero hits.
- [ ] `rg -n 'primitives:new' addons/XIUI` — should be zero or only in libs/* that we explicitly want.
- [ ] `rg -n 'gdi:destroy_interface' addons/XIUI` — zero.
- [ ] `rg -n 'ClearDebuffFontCache' addons/XIUI` — zero.
- [ ] `rg -n 'set_font_alignment\|set_text\|set_visible\|create_object' addons/XIUI` — zero (these are the gdi font-object methods).
- [ ] Open the live game, log in, run through:
  - [ ] Hotbar with macro palette → switch palettes via `/xiui pal`, `/xiui palette next`, `/xiui cpal scope job/universal`.
  - [ ] Crossbar with controller — RB + D-pad cycling, pet palette switching on `0x0068`.
  - [ ] Macro editor — open via macropalette, edit a multi-line macro with `/ws` + `/ja` corner badge.
  - [ ] JSON export/import — `palette_json.lua`.
  - [ ] ReadyCheck — `/readycheck` (verify TextIn handler works).
  - [ ] Profile change — verify `sharedMacroStore` swap, no texture leak.
  - [ ] `/xiui profile reset positions` — should go to top-left (RecoverAllPositions, 20,20).
  - [ ] Watch chat for any `Module 'X' error: ...` rate-limited messages — these are now logged via the new moduleregistry per-module error wrapping.

### Phase 7 — Commit + push (follow `scripts/PUSH_INSTRUCTIONS.md`)
- [ ] Update `scripts/feature-pr-manifest.ps1` to slice the migration into `pr/01-1.8.0-base`, `pr/02-imtext-migration`, `pr/03-shared-macro-store`, `pr/04-palette-manager`, `pr/05-crossbar`, `pr/06-horizon-databases`, etc.
- [ ] Rebuild PR branches with `.\scripts\create-upstream-pr-branches.ps1 -ResetExisting`.
- [ ] Push `master` + all `pr/*` to fork per the workspace rule.

---

## Appendix A — File-level cheat sheet

### A.1 1.8.0 trunk files to take VERBATIM (Ferris didn't modify them or only changed CRLF):
```
config/expbar.lua            modules/castbar.lua
config/partylist.lua         modules/castcost/data.lua
config/treasurepool.lua      modules/enemylist.lua
core/profile_manager.lua     modules/expbar.lua
core/settings/colors.lua     modules/giltracker.lua
core/settings/modules.lua    modules/init.lua
core/settings/updater.lua    modules/inventory/base.lua
handlers/tbar_migration.lua  modules/mobinfo/display.lua
libs/button.lua              modules/notifications/data.lua
libs/fonts.lua               modules/notifications/display.lua
libs/progressbar.lua         modules/notifications/init.lua
libs/statusicons.lua         modules/partylist/data.lua
libs/windowbackground.lua    modules/partylist/init.lua
                             modules/petbar/init.lua
                             modules/playerbar.lua
                             modules/targetbar.lua
                             modules/treasurepool/data.lua
                             modules/treasurepool/display.lua
                             modules/treasurepool/init.lua
```
(Note: many of these still need a Ferris-side overlay if Ferris ALSO added features — see Phase 5 for exact items. The above are only the "no-overlay-needed" subset.)

### A.2 Brand-new in 1.8.0 (drop in):
```
config/readycheck.lua
libs/encoding.lua            (formerly submodules/gdifonts/encoding.lua)
libs/fontconst.lua
libs/imtext.lua
modules/readycheck/init.lua
modules/readycheck/ui.lua
modules/readycheck/sound/ffxiv-levelup.wav
modules/readycheck/sound/ffxiv-message.wav
modules/readycheck/sound/ffxiv-notification.wav
modules/readycheck/sound/wow-readycheck.wav
```

### A.3 Brand-new in Ferris (drop in to 1.8.0 base):
```
.cursor/                                              (project rules)
scripts/                                              (push tooling)
.gitignore
config/crossbar.lua
config/crossbar_settings.lua
config/efp_pets_tab.lua
config/palettemanager.lua                            (146 KB)
core/shared_macro_store.lua
libs/json.lua
modules/hotbar/customiconresolve.lua
modules/hotbar/equipment_ws.lua
modules/hotbar/iconmatch.lua
modules/hotbar/macropalette_macroeditor.lua          (86 KB)
modules/hotbar/macroparse.lua
modules/hotbar/macro_global_defaults.lua
modules/hotbar/macro_palette_buckets.lua
modules/hotbar/macro_xiui_defaults.lua
modules/hotbar/palette_json.lua                      (40 KB)
modules/hotbar/pet_palette_allowlist.lua
modules/hotbar/universal_two_hour.lua
modules/hotbar/database/horizon_abilities.lua
modules/hotbar/database/horizon_bloodpacts.lua
modules/hotbar/database/horizon_bloodpacts_xiui.lua
modules/hotbar/database/horizon_retail_only_job_abilities.lua
modules/hotbar/database/horizon_spell_omissions.lua
modules/hotbar/database/ws_weapon_types.lua
```

### A.4 Files that must DIE (1.8.0 removed them; Ferris's copies are stale):
```
submodules/gdifonts/.git
submodules/gdifonts/LICENSE
submodules/gdifonts/encoding.lua          (replaced by libs/encoding.lua)
submodules/gdifonts/fontobject.lua
submodules/gdifonts/gdifonttexture.dll
submodules/gdifonts/include.lua           (replaced by libs/imtext.lua)
submodules/gdifonts/readme.md
submodules/gdifonts/rectobject.lua
```
(Removing them from the working tree may also require `git rm` of the submodule entry in `.gitmodules` / `.git/modules/`. The 1.8.0 `name-status` diff shows status `D` for these.)

---

## Appendix B — Mechanical replacement recipes

### B.1 Replace `gdi.Alignment.*` with numeric or import
```lua
-- BEFORE
local gdi = require('submodules.gdifonts.include');
settings.font_alignment = gdi.Alignment.Right;

-- AFTER (option 1, mechanical):
settings.font_alignment = 2;  -- 0=Left, 1=Center, 2=Right (legacy data field; many modules ignore it now)

-- AFTER (option 2, named, if alignment is still consumed):
local fontconst = require('libs.fontconst');
settings.font_alignment = fontconst.ALIGN_RIGHT;
```
**But:** most 1.8.0 modules no longer consume `font_alignment` because alignment is caller-side now (compute `x` from `imtext.Measure` and the bar width). Just delete the field where unused.

### B.2 Replace `gdi.FontFlags.*`
```lua
-- BEFORE
font_flags = gdi.FontFlags.Bold,

-- AFTER
local fontconst = require('libs.fontconst');
font_flags = fontconst.FLAG_BOLD,   -- numerically still 1
```

### B.3 Replace gdi text object with imtext draw
```lua
-- BEFORE (somewhere in init / Initialize)
data.hpText = FontManager.create(settings.vitals_font_settings);
data.hpText:set_font_alignment(gdi.Alignment.Right);
-- ... and later per-frame
data.hpText:set_text(hpString);
data.hpText:set_position(x, y);
data.hpText:set_visible(true);

-- AFTER (in DrawWindow, immediate-mode)
local imtext = require('libs.imtext');
imtext.SetConfigFromSettings(settings.vitals_font_settings);  -- once per draw is OK; cheap
local w, _h = imtext.Measure(hpString, settings.vitals_font_settings.font_size or 12);
imtext.Draw(drawList, hpString, x - w, y, settings.vitals_font_settings.font_color, settings.vitals_font_settings.font_size or 12);
-- For per-slot hot paths (hotbar), prefer:
imtext.DrawShadow(drawList, hpString, x - w, y, color, fontSize);
```

### B.4 Replace `windowBg.createBackground` / `createBorders`
```lua
-- BEFORE (Initialize)
data.bgHandle = windowBg.createBackground(primData, theme, bgScale);
data.borderHandle = windowBg.createBorders(primData, theme, borderScale);
-- per frame: windowBg.updateBackground(data.bgHandle, x, y, w, h, options);

-- AFTER (DrawWindow only, no Initialize state)
local windowBg = require('libs.windowbackground');
windowBg.Draw(drawList, x, y, w, h, {
    theme = theme, padding = 8, paddingY = 8,
    bgScale = bgScale, borderScale = borderScale,
    bgColor = 0xFFFFFFFF, bgOpacity = settings.backgroundOpacity,
    borderColor = 0xFFFFFFFF, borderOpacity = settings.borderOpacity,
});
```

### B.5 Replace encoding import
```lua
-- BEFORE
local encoding = require('submodules.gdifonts.encoding');

-- AFTER
local encoding = require('libs.encoding');
```

---

## Appendix C — Risk register

| Risk | Severity | Notes / mitigation |
| --- | --- | --- |
| Macro editor closure attaches to a renamed internal in 1.8.0 macropalette | **High** | First thing to verify in Phase 5.3; symptoms are silent (editor doesn't open) or crashes on open. |
| `slotrenderer` API changed; Ferris's badge/icon hooks no longer apply | **High** | Largest single porting risk. Treat 5.3 slotrenderer item as a multi-day task. |
| Crossbar `slotActions` key shape changed | **High** | Ferris built rich `BuildUniversalCrossbarStorageKey / BuildPaletteStorageKey` helpers; verify those still match 1.8.0's data shape. |
| Mid-frame texture release crashes during profile change | Medium | 1.8.0's `FlushPendingReleases` + `pendingVisualUpdate` deferral solves this — make sure Ferris's `SaveCurrentProfileFileToDisk` doesn't reintroduce inline visual updates. |
| `imtext.PrewarmFonts` doesn't cover every font Ferris allows | Medium | Verify `components.available_fonts` includes anything Ferris added in `config/components.lua`. |
| `petBarReadyBaseRecast` default 30 vs Horizon 45 | Low | One-line fix. Set default to 45 in our `user.lua`. |
| Ashita 4.3 vs 4.16 split | Low | Both versions already have `handlers/imgui_compat.lua`; behavior gated via `bIsAshita43`. Test on both. |
| `HzLimitedMode` gates features we want enabled on Horizon | Low | Audit `rg -n 'HzLimitedMode' addons/XIUI` after migration. Document each gate. |

---

## Appendix D — Hotbar vs Crossbar separation audit (post smoke-test)

User flagged: "I had separated a lot of it that was previously connected." Re-verified after the smoke-test fix pass and the `config/hotbar.lua` Ferris overlay. **Result: separation is intact.** Catalogued every shared/separate touchpoint below so we don't re-fuse them in a later pass.

### D.1 Enable / lifecycle toggles — SEPARATE (correct)
- `gConfig.hotbarEnabled` — keyboard hotbars (bars 1-6) on/off.
- `gConfig.crossbarEnabled` — controller crossbar (L2/R2 UI) on/off.
- `modules/hotbar/init.lua:387-406` draws the two halves independently:
  - `showHotbar` → `display.DrawWindow(settings)` / `display.HideWindow()`
  - `showCrossbar` → `crossbar.DrawWindow(...)` / `crossbar.SetHidden(true)`
- Either, both, or neither can be active.

### D.2 Movement / drag locks — SEPARATE (correct, just fixed in smoke-test pass)
- `gConfig.hotbarLockMovement` — locks keyboard bars only.
- `gConfig.crossbarLockMovement` — locks the controller crossbar only.
- `modules/hotbar/crossbar.lua:1591` (move anchor) reads `crossbarLockMovement`.
- `modules/hotbar/slotrenderer.lua:1530` (right-click clear) routes through `IsMovementLockedForDropZone(params.dropZoneId)` so each zone (`hotbar_*`, `crossbar_*`, `paled_*`) applies its own policy. Palette-editor drop zones are unlocked regardless of either toggle.

### D.3 Hide-on-menu — SEPARATE (correct, do NOT recombine)
- `gConfig.hotbarHideOnMenuFocus` — keyboard bars hide when a game menu is open.
- `gConfig.hotbarCrossbar.crossbarHideOnMenuFocus` — crossbar hides when a game menu is open.
- `gConfig.hotbarCrossbar.crossbarDisableInMenu` — additionally suppresses controller input routing while in menus (Ferris-only; lives in `modules/hotbar/controller.lua`).
- **XIUI.lua hotbar Register block (line 307-313) MUST NOT carry `hideOnMenuFocusKey`.** The central `core/moduleregistry.lua` would otherwise hide the whole module, collapsing both halves into a single toggle. Per-bar branching happens inside `modules/hotbar/init.lua:384-392`.
- Migration plan §1.3 / §3.1.7 / Phase 2 checklist updated to flag this as an *intentional* drop (not a regression).

### D.4 Visual settings — SHARED `hotbarGlobal` (correct by design)
- `gConfig.hotbarGlobal` holds visual defaults consumed by both subsystems when a bar opts into "use global settings": skillchain colors/highlights, palette cycle button (`hotbarPaletteCycleButton`, controller-only but lives here), default font tiers, etc.
- Override paths: `hotbarBar1..6` per-bar visual overrides; `hotbarCrossbar` per-crossbar settings table (combo-mode bars, expanded triggers, font sizing, scope iconography).
- Shared controls in `config/hotbar.lua` for the parts that legitimately apply to both:
  - `DrawSharedDisableXiMacrosControls`
  - `DrawSharedSkillchainHighlightControls`
  - `DrawLogPaletteNameCheckbox`
  - Unified palette modal (`create` / `rename` for hotbar AND crossbar palettes)
- `config/crossbar.lua` + `config/crossbar_settings.lua` consume those shared helpers via `require('config.hotbar').<helper>` — no duplicated UI code.

### D.5 Window position state — SEPARATE keys (correct)
- `gConfig.windowPositions['Hotbar']`, `['Hotbar2']`, ... (per-bar saved positions).
- `gConfig.windowPositions['Crossbar']` (crossbar window position).
- `gConfig.appliedPositions['Crossbar']` tracking flag used by `crossbar.lua` for the "Reset Crossbar Position" deferred re-apply.
- Master "lock all window positions" toggle `gConfig.lockPositions` is intentionally shared across every module (treats every window equally).

### D.6 Palette / macro storage — SEPARATE buckets (correct)
- Hotbar palettes: `palette.CreatePalette` / `RenamePalette` family.
- Crossbar palettes: `palette.CreateCrossbarPalette` / `RenameCrossbarPalette` / `palette.IsUsingFallback(job, storSj, 'crossbar')` family.
- Universal-crossbar palettes: `palette.CreateUniversalCrossbarPalette` / `RenameUniversalCrossbarPalette`.
- `palette.GetCpalAnchor(scope)` / `cpalette` CLI command family operates *only* against crossbar storage; keyboard-bar palette flow uses `/xiui palette` / `/xiui pal`.
- Job-specific confirm state machine in `config/hotbar.lua` (Section "JobSpecificConfirmState") detects `isCrossbar` and writes to `gConfig.hotbarCrossbar.bars[barKey]` vs `gConfig.hotbarCrossbar.jobSpecific`; correctly skips the keyboard-bar path.

### D.7 Status icons (Palette Manager Active/Inactive column) — NEW location
- Ferris's `palettemanager.lua` originally loaded `TextureManager.getCustomIcon('checkmark.png')` / `getCustomIcon('x.png')` → `<addon>/assets/hotbar/custom/`.
- **Now loaded via `TextureManager.getFileTexture('checkmark')` / `getFileTexture('x')` → `<addon>/assets/checkmark.png` / `<addon>/assets/x.png`.** Path updated in `config/palettemanager.lua` (status-icon section near the top). `getFileTexture` auto-appends `.png` and resolves relative paths under `assets/`.

### D.9 Smoke-test pass 2 (4 issues, 2026-05-22)

1. **Tops and bottoms of the crossbar (especially text) were being clipped.** The Pass 1 smoke-test fix zeroed *horizontal* `WindowPadding` to recover the left/right diamond slots, but the ImGui window itself was still sized to *just* the slot grid (`{width, height}`). Decoration that draws above the slots (L2 / R2 trigger icons at `groupY - iconH/2`, R1 cpal-anchor pulse at `r2IconY - r1Height - 4`, palette modifier refresh glyph at `windowY - 24`, combo text at `windowY - 4`) and below (action labels, palette name at `windowY + height + 4`) were all rendering *outside* the content rect → clipped.
   - **Fix:** Ported Ferris's deferred decor-pad scheme into `modules/hotbar/crossbar.lua`: `CROSSBAR_WINDOW_TOP_DECOR_PAD = 80`, `GetCrossbarWindowBottomPad(settings)` (10–72 px depending on font sizes / label visibility), `ApplyCrossbarWindowPositionOnce()`, `SaveCrossbarWindowSlotTopPosition()`. `M.DrawWindow` now opens the ImGui window `TOP_DECOR_PAD` pixels higher and `(top + bottom)` pixels taller than the slot grid; `state.windowY` continues to mean *slot grid top* everywhere else in the module so the rest of the layout code is untouched.
   - **Profile compat:** `gConfig.windowPositions.Crossbar.y` now means slot-top instead of window-top. Existing profiles saved under the old code happen to have slot-top == window-top (because no pad existed), so on first load under the new code the window opens at `(savedY - PAD)` and the slot grid lands at `(savedY - PAD + PAD) == savedY` — slot screen Y is preserved. Subsequent saves go through `SaveCrossbarWindowSlotTopPosition` which writes slot-top back.
   - This finishes one of the three remaining Pass 2 items (smart window-position save/restore).

2. **"Disable Crossbar While In Menu" wasn't dimming anything.** `modules/hotbar/controller.lua` already stopped routing controller input when `IsMenuOpen() && crossbarDisableInMenu`, but Ferris's matching *visual* dim never got ported — the crossbar stayed at full opacity so the player had no visible cue that input was paused.
   - **Fix:** Added `local gamestate = require('core.gamestate')` to `modules/hotbar/crossbar.lua`, and in `M.DrawWindow` immediately after the `visibilityOpacity` block: `if gamestate.IsMenuOpen() and settings.crossbarDisableInMenu ~= false then visibilityOpacity = visibilityOpacity * 0.35 end`. That multiplier propagates into every slot via the existing `animOpacity` param and the background / border / trigger alpha scales below it.

3. **Double-click on an empty Edit Full Palette slot didn't open the macro editor.** Two gaps:
   - `modules/hotbar/slotrenderer.lua` had no double-click tracking at all (1.8.0's base only knows single-click → execute). `imgui.IsMouseDoubleClicked` is unreliable here because the drag/drop system swallows the first click on slots that participate in drag.
     - **Fix:** Ported Ferris's manual click tracker: file-scope `lastClickButtonId / lastClickTime / DOUBLE_CLICK_INTERVAL = 0.35`. Replaced the `IsMouseReleased(0)` handler with a 4-branch dispatcher (double-click → `params.onDoubleClick`, suppressActionOnClick → record click and do nothing, normal `params.onClick`, fallback `bind`-execute). Editor slots also pass `ignoreCancelledMicroDrag` (suppresses the `WasDragAttempted` guard) so a tiny mouse jitter between press and release doesn't block the double-click pipeline.
   - `modules/hotbar/crossbar.lua` `GetCbInteractionPaletteEditor` (the editor entry factory) had no `onDoubleClick` and the DrawSlot params never set `suppressActionOnClick` for editor slots.
     - **Fix:** Added an `onDoubleClick` closure to the cached editor entry: reads fresh draft slot data via `data.GetDraftSlotData(comboMode, slotIndex)` (nil for empty slots → starts a fresh "creating new" session seeded with the active palette type's defaults) and routes through `data.SetPendingPaletteSlotEdit(slotData, comboMode, slotIndex)`. `config/palettemanager.lua` consumes the pending edit the next frame and calls `macropalette.OpenEditorForSlotData` (avoids opening a modal inside the hotbar's draw pass). Threaded `p.onDoubleClick = isEditor and interaction.onDoubleClick or nil` and `p.suppressActionOnClick = isEditor and true or false` into the DrawSlot params block. Live HUD slots leave both nil/false so single-click → execute behaviour is unchanged.

4. **`Classic FFXIV` (`ClassicFFXIV`) job icon theme appearing in the dropdown.** The folder is user-custom; not appropriate for the public icon set list.
   - **Fix:** Removed `'ClassicFFXIV'` from the `paletteIconThemes` array in `config/crossbar_settings.lua` (the "Palette & Controller Icons" section under Crossbar → Global Visual Settings). Updated the help text to drop the `ClassicFFXIV` folder reference. Narrowed the three allowlist guards (`ResolveCrossbarPaletteJobIconTheme` in `config/crossbar_settings.lua`, `GetCrossbarPaletteJobIconTheme` in `config/palettemanager.lua`, `GetPaletteJobIconThemeFromSettings` in `modules/hotbar/crossbar.lua`) so any profile that still has `ClassicFFXIV` selected gracefully falls back to `Classic`. Added a one-shot migration in the dropdown init: `if paletteJobIconTheme == nil or paletteJobIconTheme == 'ClassicFFXIV' then paletteJobIconTheme = 'Classic' end` so the saved value also rolls forward on first open. Updated factory comment in `core/settings/factories.lua`.

### D.10 Anything still suspicious / Phase 3 followups
- `XIUI.lua` hotbar Register passes `hideOnEventKey = 'hotbarHideDuringEvents'` but no such setting exists; the actual global event-hide check (`gConfig.hideDuringEvents`) runs separately in `d3d_present`. Dead reference, harmless. Consider cleaning up in Phase 3 polish.
- No crossbar-side `preview` equivalent to `gConfig.hotbarPreview`. If a "Preview Crossbar With Test Data" toggle is wanted later, it would be a new setting on `gConfig.hotbarCrossbar` (not a shared key).

### D.11 Smoke-test pass 3 (4 issues, 2026-05-22 evening)

1. **L1 palette cycle silently failed when R1 worked.** Both branches of the cycle check (`(cycleButton == 'L1' and lbHeld) or (cycleButton ~= 'L1' and rbHeld)`) were correct — but `lbHeld` / `rbHeld` were read freshly out of `currentButtons` each poll, and the latched `state.{left,right}ShoulderHeld` were unconditionally overwritten from the poll. On setups where FFXI's native gamepad bindings consume the L1 bit before it reaches Ashita's `xinput_state` snapshot, the poll saw L1 cleared every frame even though the user was physically holding it. R1 was usually free, so it worked.
   - **Fix:** `modules/hotbar/controller.lua` `HandleXInputState`: poll now ONLY sets the latched shoulder state to `true` (catches missed events), never clears it. Releases are exclusively driven by `HandleXInputButton` (which fires reliably for both L1 and R1). The cycle check then reads the latched values. Added more diagnostic info to the existing DebugLog lines so any further regressions surface in `/xiui debug controller`.
   - Side effect: the `r1Edge and lbHeld` scope-toggle and the `r1Edge and not lbHeld` cpal-anchor double-tap both become more reliable under the same scenario.

2. **Unavailable abilities lost the "Lv##" badge and the gray-out + "X" was missing for pet/macro slots.** `modules/hotbar/slotrenderer.lua`'s 1.8.0 base only checked `actionType in {'ma','ja','ws'}` and only ever rendered a plain `"X"` for unavailable actions — Ferris had pet + macro in the allowlist, embedded effective levels in the cache key for Level Sync, and parsed the `IsActionAvailable` reason into a `"Lv65"` style badge.
   - **Fix (allowlist):** Extended both the DrawSlot availability block and the DrawTooltip block to also cover `'pet'` and `'macro'`. Pet pacts get gated by their SMN level requirement; macros resolve through `IsActionAvailable`'s `/pet|/ma|/ws|/ja` validation so a macro that pets a pact above your SMN level reads as unavailable too.
   - **Fix (cache key):** Cache key is now `bindKey:job:subjob:mainLv:subLv:partyMain:partySub`. Without the level fields, a spell cached as "available" at L75 stayed available after a Level Sync down to L40, until manual cache clear. The existing `statushandler.lua` Level Sync transition still calls `slotrenderer.ClearAvailabilityCache()` for explicit on/off events; the level fields cover the cases the buff transition misses (party-sync changes from re-forming, sync target leveling, etc.).
   - **Fix (label):** The MP-cost corner now extracts `Lv(%d+)` (and legacy `Lvl%.(%d+)`) from `unavailableReason` and renders `"Lv65"` in the same red as the fallback `"X"`. WS unavailability returns `"N/A"` reason, which doesn't match either pattern, so it falls through to `"X"` (matches the user's "I think it just X'ed because those aren't based on a real level" intuition).
   - **Fix (cache hygiene):** Added size-bounded `PutMpCostCache` / `PutAvailabilityCache` helpers (8192 / 4096 entry caps with wholesale reset on overflow). Adding effective levels to the availability key inflates cache cardinality (one entry per spell per (job, subjob, mainLv, subLv, partyMain, partySub) tuple); the size cap keeps long sessions bounded.

3. **Palette Manager icons not appearing.** The path-side fix landed in pass 2 (loader now calls `TextureManager.getFileTexture('checkmark')` / `getFileTexture('x')` → `<addon>/assets/<name>.png`), but the icons themselves only existed in `XIUIFerrisChanges/assets/`, not in the working `XIUI/assets/` directory — first-run loaded an empty texture and `DrawStatusIcon` rendered the fallback colored dot.
   - **Fix:** Copied `checkmark.png` and `x.png` from `XIUIFerrisChanges/assets/` to `XIUI/assets/`. Code path was already correct from pass 2.

4. **Palette name showed `(1/N)` count even with only one enabled palette.** `modules/hotbar/crossbar.lua` `DrawPaletteName` called `GetCrossbarPaletteIndex` + `GetCrossbarPaletteCount` (both of which already filter to RB-cycle-enabled rows) but unconditionally formatted `(idx/total)` even when `total == 1`. It also didn't route through the universal-scope cycle correctly.
   - **Fix:** Switched to `palette.GetCrossbarPaletteLabelIndexAndTotal(paletteName, jobId, subjobId)` which already handles the universal vs job scope split (universal scope uses `GetUniversalCrossbarPalettesForCycle`, job scope uses RB-cycle rows). Only renders the `(idx/total)` suffix when `total > 1`; below that the bar still shows the palette name but drops the always-`1/1` noise.

### D.12 Crossbar Pass 2 — DrawDoubleTapPreviewWindow ported

`enableDoubleTap` + `showDoubleTapPreview` now light up two floating ImGui preview windows (`CrossbarPreviewL2x2`, `CrossbarPreviewR2x2`) that mirror the L2x2/R2x2 slots at user-configurable scale and opacity. Drawn AFTER `M.End()` of the main crossbar so each preview is its own ImGui window with its own draw list and persisted position; layered above the main bar via the standard "no NoBringToFrontOnFocus" pattern. When the matching double-tap chord is active, the preview swaps to the BASE L2/R2 slots as a reference (the main bar is already showing the double-tap content). New helpers in `modules/hotbar/crossbar.lua`: `MakePreviewSettings(settings, scale)`, `DrawPreviewSide(...)`, `DrawDoubleTapPreviewWindow(windowKey, mode, ps, baseOp, dimFactor, activeCombo, settings)`. Move anchor uses `doubleTapPreviewLocked` as an independent lock — main-crossbar lock state doesn't affect preview repositioning and vice versa.

Closes the second of three Pass 2 remaining items (smart window-position save/restore was the first).

### D.13 Remaining Phase 2/3 work (after this session)

**HIGH (only affects users who enable the setting):**
- ~~`useSharedExpandedBar` layout. `GetDisplayModes` needs a `settings` arg + a `'center'` return for L2_THEN_R2 / R2_THEN_L2 when `useSharedExpandedBar`. `M.DrawWindow` needs the multi-branch refactor: narrow `width = groupWidth`, screen-centered `SetNextWindowPos`, `lastWideCrossbarWindowX` stash for "exiting chord" restore, suppress right-column rendering / divider / right-side triggers, render `DrawTriggerIconsSharedExpandedCenter` instead of `DrawTriggerIcons`.~~ **DONE — see D.15.**

**MEDIUM (readability polish on crossbar slot text):**
- ~~`AddOutlinedForegroundText`, `AddSoftEllipticalBackdrop`, `AddSoftEditorLabelBackdrop` from `slotrenderer.lua`.~~ **SKIPPED per user (2026-05-22) — current text rendering is satisfactory.**
- ~~`DrawGdiTimerCooldownForeground` / `AddGdiLikeCooldownForegroundText` for heavier cooldown timer text on the crossbar.~~ **SKIPPED per user (2026-05-22).**
- ~~`AddEditorMultilineCenteredOnSlotLikeCorner` + `EditorLabelSnappedCenterX` + `MeasureEditorLabelTextSize` for Edit Full Palette label backdrops + pixel-snapped centering.~~ **SKIPPED per user (2026-05-22).**

**Phase 3 verification (code present, smoke tests pending):**
- Full `/xiui` command set (confirmed by audit grep — `cpal`, `cpaledit`, `cpalette`, all aliases handled in `XIUI.lua:1500-1620+`).
- ReadyCheck wiring (registered in `XIUI.lua`, module under `modules/readycheck/`) — user confirmed this is unchanged 1.8.0 code, no action required.
- Hotbar/crossbar palette flow (`palette.lua` + `palettemanager.lua` ported).
- Profile import/export (`palette_json.lua` + config UI buttons ported).
- `hideOnMenuFocus` regression smoke test (per-bar split in `modules/hotbar/init.lua:381-385`; no central key — confirmed intentional).

### D.14 Performance + completeness audit pass (2026-05-22 late evening)

A focused readonly audit ran across `slotrenderer.lua`, `crossbar.lua`, `controller.lua`, and `actions.lua` after the D.11 fixes landed. Findings + applied fixes:

**HIGH (correctness, applied):**

1. **`playerdata.RefreshCachedLists` was only being called from `display.lua` (keyboard hotbars).** Crossbar-only setups (`hotbarEnabled=false, crossbarEnabled=true`) never warmed the ability/WS caches, so `actions.IsActionAvailable` → `IsAbilityInCache` / `IsWeaponskillInCache` always returned `false` → every JA / WS slot read as unavailable on the crossbar even on jobs that knew them. **Fix:** added `local playerdata = require('modules.hotbar.playerdata')` to `crossbar.lua` and call `playerdata.RefreshCachedLists(data)` once at the top of `M.DrawWindow`. The refresh is signature-gated internally (equip+job+subjob); steady-state cost is a signature compare, only doing the heavy ability-scan on real changes. Cheap on cache hit, correct on cache miss.

2. **`actions.IsActionAvailable` used RAW character levels (`player:GetMainJobLevel()`) for spell / JA / pact gates** instead of effective post-Level-Sync levels. The slotrenderer's availability cache key was already on effective levels (D.11), so cache hits returned the right answer for the WRONG reason — but the underlying availability check would tell a synced-down player that a too-high-level spell was available. **Fix:** `M.IsActionAvailable` now reads `party:GetMemberMainJobLevel(0)` / `GetMemberSubJobLevel(0)` (which reflect post-sync effective levels) and falls back to `player:GetMainJobLevel()` only if party packet hasn't populated. The two-source approach matches what `equipment_ws.lua` already does for its WS cache signature.

**MEDIUM (perf, applied):**

3. **Per-slot `GetMemoryManager` walks in DrawSlot.** Before, every MA/JA/WS/pet/macro slot called `AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()` etc. — ~7 FFI getters per slot × 16-32 visible slots × 60 fps. **Fix:** added a `GetFrameAvailability()` helper in `slotrenderer.lua` that lazily snapshots `(jobId, subjobId, mainLevel, subLevel, partyMain, partySub)` once per frame; `M.BeginFrame` invalidates it. DrawSlot + DrawTooltip both route through the snapshot. Per-frame MM walk dropped from `N_slots × M_getters` to a constant `~7 getters` regardless of slot count.

4. **`string.match` on every unavailable-slot frame.** The MP-cost render path ran `unavailableReason:match('^Lv(%d+)$')` + a legacy fallback every frame for every unavailable slot. **Fix:** parse the display text ONCE at availability-cache insert time and store `entry.displayText` (`'Lv65'` or `'X'`). DrawSlot reads `cached.displayText` — no string allocation in the hot path. Pre-parsing also covers the "pending" case with a sane default.

5. **`MakePreviewSettings` shallow-copied the full settings table every frame.** With `enableDoubleTap + showDoubleTapPreview`, this fired 2× per frame. **Fix:** cache the scaled settings on a `(settings ref, scale, layout-signature)` tuple. Signature uses only the geometry-affecting fields (`slotSize`, `slotGapV/H`, `diamondSpacing`, `groupSpacing`, `buttonIcon*`, `triggerIconScale`), so slider drags invalidate immediately but steady state hits the cache.

6. **Double-tap preview wasted draw calls when invisible.** Added an early-return `if baseOp <= 0.02 then return end` after the visibility-opacity * user-opacity calculation. Skips the 16-slot + 2-window render path entirely when the preview would be effectively invisible (menu dim + 0.35 multiplier can already drop baseOp below threshold).

**LOW (perf, NOT applied — judgment call):**

7. **Palette label cache.** Tried caching `DrawPaletteName`'s formatted output on `(paletteName, job, subjob, scope)` — would have gone stale on PaletteManager CRUD without a roster-version invalidation hook on `palette.lua`. Lookup is microseconds at typical 1-10 palette counts; not worth the staleness risk. Cache code reverted.

8. **Availability cache full-table reset on overflow.** Wholesale-reset at 8192 entries causes a one-time miss storm; an LRU would amortize better. Not urgent at realistic key cardinality (~200-500 binds × few level-state combos << 8192).

**Other gaps verified present (no action needed):**
- All double-tap preview config UI (toggle + scale + opacity + lock) is in `config/crossbar_settings.lua`.
- All `useSharedExpandedBar`, `crossbarDisableInMenu`, `showStackQuantity` UI toggles wired.
- `handlers/statushandler.lua` Level Sync detection still calls `playerdata.ClearCache` + `slotrenderer.ClearAvailabilityCache`.
- Horizon data files (`horizonspells.lua`, `horizon_bloodpacts.lua`, `petregistry.lua`) wired through `actions.lua`, `playerdata.lua`, `recast.lua`, `data.lua`.
- Petbar resize/snap-anchor symbols (`PetBarResizeAnchoredBottom`, `petBarSyncResizeAnchorNextFrame`, cluster drag) all present.

**Shoulder-button latching (D.11) verified no-regression:** two booleans on `state`, no per-frame allocations or table growth.

### D.15 Shared-expanded-bar layout + bloodpact skillchain port (2026-05-22 late evening)

Closes the last two HIGH-priority items from D.13. User requested:
- `p3-shared-expanded-bar` → port.
- `GetCrossbarSkillchainVisualsFromGlobal` / Ferris SMN ability skillchain data → check + port if missing.
- `p3-slot-text-polish` → skip (current text is satisfactory).
- ReadyCheck → not Ferris's function, no action.

**Shared-expanded-bar layout (`useSharedExpandedBar`):**

`modules/hotbar/crossbar.lua`

- `GetDisplayModes(activeCombo, settings)` gained a `settings` arg. When `settings.useSharedExpandedBar == true` and the user holds L2+R2 or R2+L2, it returns `('Shared', 'R2', true, 'center')` instead of the side-expanded `(L2R2/R2L2)` pair. The `'center'` sentinel signals DrawWindow to collapse both diamonds into a single centered 8-slot strip.
- Added `state.lastWideCrossbarWindowX` + `state.wasSharedCenterChordLayout` bookkeeping. The shared-center window is force-X-centered every frame, so save-position must NOT overwrite the wide-bar X — and exiting the chord must restore the stashed X (otherwise the bar visibly snaps to wherever the narrow centered window happened to land).
- `M.DrawWindow` was restructured: `activeCombo` + `GetDisplayModes` now resolve BEFORE the window size/position calls (chord branch needs to know whether to shrink + recenter). Width logic: `hideRightForSharedCenter` shrinks `width` to one `groupWidth`. Window position: chord forces `(screenW - width) * 0.5` X; exit-chord re-anchors to `lastWideCrossbarWindowX` for one frame; save-position only writes Y while chord is up.
- Right-side draw paths (`DrawRightSide` in `state.animation.active` + steady-state + activeOnly branches) all gated on `(not hideRightForSharedCenter)`. The non-animated steady-state branch also gained a `hideRightForSharedCenter` case that draws ONLY the left column as a single centered strip.
- Center decor: divider suppressed in chord (no left/right split to divide). Scope icon / combo text / palette name still render but `centerX` switches to `state.windowX + width * 0.5` so they sit over the visible bar.
- New helper `DrawTriggerIconsSharedExpandedCenter(activeCombo, groupLeftX, groupY, groupWidth, settings, drawList)` replaces `DrawTriggerIcons` in the chord branch. Renders an `L2 + R2` chord glyph centred on the single visible diamond, with each icon tinted brighter when its trigger is part of the active combo (and animated by `animation.getPressScale`).

**Bloodpact / pet-macro skillchain prediction on crossbar:**

`modules/hotbar/skillchain.lua` already exports `GetSkillchainForBloodPact(targetServerId, pactName)` backed by `bloodPactResonationMap`, and `display.lua` (keyboard hotbar) was already routing `actionType == 'pet'` slots + `actionType == 'macro'` with a `/pet` primary line through it. **`crossbar.lua` was only routing `actionType == 'ws'`** — so SMN ability slots and any /pet macros on the crossbar never showed a skillchain icon even though the same bind on a keyboard hotbar would. **Fix:** `crossbar.lua` now requires `macroparse` and both `DrawLeftSide` / `DrawRightSide` route slots through the same `ws`/`pet`/`macro→(ws|pet)` dispatch as display.lua. The editor preview path still suppresses skillchain icons (unchanged — by design).

`GetCrossbarSkillchainVisualsFromGlobal` itself (the per-frame visual settings snapshot helper from Ferris) is **not needed in the current architecture**: `slotrenderer.lua` already reads `skillchainHighlightColor` / `skillchainIconScale` / `skillchainIconOffsetX` / `skillchainIconOffsetY` from `gConfig.hotbarGlobal` at the call site, and `crossbar.lua` passes the color through `p.skillchainColor`. The visuals settings are wired; only the per-slot skillchain-name resolution was incomplete.

**Lint:** clean across all touched files (`modules/hotbar/crossbar.lua`).


### D.16 Magic Burst Highlight (2026-05-22 night)

New feature, parallel to the skillchain highlight: when a skillchain closes on the player's
target, briefly highlight any spell / magical-pact-rage / `/ma|/pet`-macro slot whose element
matches the SC's burstable elements (the Magic Burst window).

**User-locked design (questions answered):**

- Window: open at `now + 0.0s`, close at `now + 7.0s` (full 7s active window — opens
  immediately on the SC packet so the visual cue lands the moment the chain fires, then
  matches retail's ~7s MB cutoff at the back end). On a new WS WITH attributes → MB
  cleared (matches FFXI: the new WS overwrites resonance even if it doesn't chain). On a
  new SC → MB overwritten with the new SC's burstable elements. WS WITHOUT attributes
  (Spirits Within, etc.) → MB untouched.
- Color: fixed cyan-blue (`0xFF44D4FF` ARGB), distinct from the gold skillchain border. User
  can recolor via Hotbar Settings.
- No cast-time gate — every element-matching spell lights up, player decides what fits.
- Scope: any spell row with `element` ∈ 0..7 AND `targets` carrying the enemy bit (`32`),
  which automatically picks up offensive WHM (Banish/Holy/Cure-on-undead), BLM, BLU
  elementals, Ninjutsu (Katon line), and `/ma` macros via `macroparse`. SMN magical Blood
  Pact Rages routed by a CURATED name → element map (`bloodPactElementMap` in `skillchain.lua`)
  because `horizon_bloodpacts.lua` stores `element = 0` as a placeholder for every row and
  can't be trusted. Physical pacts (Punch, Rock Throw, Crescent Fang, etc.) intentionally
  omitted from the map so they never false-positive.

**`modules/hotbar/skillchain.lua`**

- New `magicBurstMap[targetIndex] = { Elements, ScName, WindowOpen, WindowClose }` kept
  separate from `resonationMap` because the two windows have different lifetimes (resonance =
  next-SC prediction 3.5–9.8s; MB = actual burst window 1.5–7.0s). Sharing one map would
  conflate them and corrupt either feature.
- `magicBurstElements[Resonation.X] = { elemIds... }` table maps each SC result to its
  burstable elements per retail rules (Lv1 → 1 element; Lv2 → 2; Lv3 → 4). Light/Darkness/
  Radiance/Umbra all alias to the same 4-element sets.
- `bloodPactElementMap[pactName] = elemId` — curated short list of the spell-named "Magic"
  Blood Pact: Rages only: `Fire II/IV`, `Blizzard II/IV`, `Aero II/IV`, `Stone II/IV`,
  `Thunder II/IV`, `Water II/IV`. Named flavor rages (Heavenly Strike, Inferno, Judgment
  Bolt, Wind Blade, Geocrush, Grand Fall) and Astral Flow 1HRs (Diamond Dust, Aerial Blast,
  Earthen Fury, Tidal Wave, Searing Light, etc.) are deliberately OMITTED per user spec —
  MB highlight is scoped to the BLM-shadow magic pacts only. Extend cautiously and never
  add physical pacts (Punch / Rock Throw / Crescent Fang / etc.).
- Lazy `spellElementByLowerName` lookup built from `database.horizonspells.lua` on first
  request, mirroring the lookup pattern in `actions.lua`. MB-eligibility filter is element
  0..7 AND `bit.band(targets, 32) ~= 0`, which automatically excludes Protect/Raise/-na/etc.
  (all element=6/Light but no enemy target bit).
- `HandleActionPacket` extended:
  - SC-fire branch → write `magicBurstMap[idx]` with `Elements` from `magicBurstElements`,
    `ScName` from `resonationNames`, window `[now+0.0, now+7.0]`. Overwrites any prior MB
    on this target ("new SC switches the highlight", per user spec).
  - WS-with-attributes branch → `magicBurstMap[idx] = nil`. WS without attributes never
    reaches this branch (absent from `weaponskillResonationMap`/`pactAttributes`), so MB
    is untouched — exact match for the Spirits Within mechanic.
  - SC-with-`Resonation.None` branch (rare; targeted clear) → also clears MB.
- `ClearState` / `ClearTargetState` extended to also clear `magicBurstMap`.
- New public API:
  - `M.GetBurstElementForSlot(slotData)` → element id (0-7) or nil; routes by `actionType`
    (`'ma'`, `'pet'`, `'macro'` via lazy-required `macroparse`).
  - `M.GetMagicBurstForElement(targetServerId, element)` → SC name (e.g. `'Fusion'`) or nil.
  - `M.GetMagicBurstForSlot(targetServerId, slotData)` → convenience wrapper used by
    display.lua + crossbar.lua so each call site is one line.
  - `M.GetMagicBurstWindow(targetServerId)` → raw MB entry for any future on-target UI badge.

**`modules/hotbar/slotrenderer.lua`**

- New `DrawMagicBurstHighlight(drawList, x, y, size, scName, color, opacity, scaleOv, oxOv, oyOv)`
  mirrors `DrawSkillchainHighlight` (same dashed border + SC-name icon corner) with two
  intentional differences:
  - Border color comes from `magicBurstHighlightColor` (cyan-blue default) instead of gold.
  - Icon placed in the BOTTOM-LEFT corner instead of top-right (skillchain owns top-right,
    MP cost typically owns top-left, quantity owns bottom-right → bottom-left is the free
    corner). Allows both highlights to be visible if they ever co-occur.
  - Marching-ants phase shifted by half a dash so the two patterns don't visually merge.
- DrawSlot pass extended: after `params.skillchainName` check, an analogous block reads
  `params.magicBurstName` and calls `DrawMagicBurstHighlight`. Reuses `skillchainIconScale`/
  `OffsetX`/`OffsetY` from `gConfig.hotbarGlobal` so users only tune corner placement once.

**`modules/hotbar/display.lua`** (keyboard hotbar)

- `DrawSlot(...)` signature gained `magicBurstName` (trailing optional). Wired through to
  `p.magicBurstName` + `p.magicBurstColor` on the shared params table.
- The per-frame target resolution block now considers `skillchainEnabled OR magicBurstEnabled`
  so both features share one `targetServerId` resolve.
- Per-slot loop: after the existing skillchain dispatch, a one-line call to
  `skillchain.GetMagicBurstForSlot(targetServerId, bind)` produces `slotMagicBurstName`,
  passed through to `DrawSlot`.

**`modules/hotbar/crossbar.lua`**

- `DrawSlot` signature gained trailing `magicBurstName`. `p.magicBurstName` is suppressed in
  editor preview (same rule as `p.skillchainName` — no live target there).
- `DrawLeftSide` / `DrawRightSide` / `DrawBarSet` all gained trailing `magicBurstEnabled`.
  Per-slot logic resolves `slotData` once per slot now (shared between SC + MB paths) and
  produces `slotMagicBurstName` via the same `GetMagicBurstForSlot` helper as display.lua.
- `DrawWindow` resolves `magicBurstEnabled` alongside `skillchainEnabled` and threads it into
  every DrawLeftSide / DrawRightSide / DrawBarSet call (animated + steady-state + activeOnly
  + shared-center-chord branches, plus the normal-mode DrawBarSet).

**`core/settings/factories.lua`**

- Added under `hotbarGlobal`:
  - `magicBurstHighlightEnabled = true`
  - `magicBurstHighlightColor = 0xFF44D4FF` (ARGB cyan-blue)

  No migration required — Ashita's `settings.load(defaults)` auto-fills missing keys.

**`config/hotbar.lua` (`DrawSharedSkillchainHighlightControls`)**

- Added a color picker for the existing `skillchainHighlightColor` (previously not exposed in
  the UI even though factories shipped it).
- Added a `Magic Burst Highlight` checkbox + `Magic Burst Border Color` picker. The skillchain
  Icon Scale / Offset X / Y help text was updated to note they're shared by both highlights.

**Visual logic:**

- WS slots → skillchain highlight only (no element).
- Spell slots (`/ma`, Ninjutsu, BLU elemental, BLM, WHM offensive) → MB highlight only.
- SMN spell-named magic pact rages on `/pet` slots (Fire II/IV, Blizzard II/IV, Aero II/IV,
  Stone II/IV, Thunder II/IV, Water II/IV) → MB highlight via the curated map. Named flavor
  rages and Astral Flow 1HRs → no MB by design. Physical pacts on `/pet` slots → no MB.
  Physical pacts can still get the skillchain highlight via `bloodPactResonationMap`
  (unchanged from D.15).
- `/ma`-primary or `/pet`-primary macros → MB highlight (whichever applies).
- `/ws`-primary macros → skillchain highlight (unchanged).
- Editor preview (`Edit Full Palette`) → both highlights suppressed (no live target context).

**Lint:** clean across all touched files (`modules/hotbar/skillchain.lua`,
`modules/hotbar/slotrenderer.lua`, `modules/hotbar/display.lua`,
`modules/hotbar/crossbar.lua`, `core/settings/factories.lua`, `config/hotbar.lua`).
