# Shared list: one entry per upstream PR / logical feature (multiple files per commit).
# Paths are fork-relative. create-upstream-pr-branches.ps1 maps to XIUI/<path> for tirem diffs.
#
# 25-slice structure (INVENTORY_FERRIS_ON_1.8.0.md — consolidated 2026-05-23):
#   Merges applied vs INVENTORY 29-slice draft:
#     pr/20+pr/21 → pr/20-segment-overrides  (data + palette hooks in one PR)
#     pr/23 (SMN assets) folded into pr/04
#     pr/26+pr/27 → pr/24-party-list-fixes   (buff index fix + align-bottom in one PR)
#     pr/29 eliminated: personal item PNGs excluded; customiconresolve/iconmatch/textures → pr/11
#   Pure 1.8.0 baseline files NOT in any Ferris slice:
#     libs/imtext.lua, libs/encoding.lua, libs/fontconst.lua (1.8.0 render core)
#     config/readycheck.lua, modules/readycheck/ (1.8.0 ReadyCheck module, unmodified)
function Get-FeaturePRManifest {
    return @(
        @{
            Branch  = 'pr/01-horizon-static-databases'
            Files   = @(
                'modules/hotbar/database/horizon_abilities.lua',
                'modules/hotbar/database/ws_weapon_types.lua',
                'modules/hotbar/database/horizon_spell_omissions.lua',
                'modules/hotbar/database/horizon_retail_only_job_abilities.lua'
            )
            Subject = 'Horizon static databases: abilities, weaponskills, spell omissions, retail-only JAs'
            Body    = @'
What changed
- horizon_abilities.lua: job ability unlock levels from HorizonXI JA Progression (including BST pet
  commands with level gates); comments reference retail-only omissions moved to the separate file.
- ws_weapon_types.lua: weaponskill to weapon category, required skill level, relic-only flags. Used
  by Show All sort (weapon category A->Z, skill req low->high) and equipment-based availability.
- horizon_spell_omissions.lua: spell names excluded from Show All (post-75, retail-only, etc.);
  kept separate from horizonspells.lua so the core spell DB stays untouched.
- horizon_retail_only_job_abilities.lua: named JAs that exist on retail but not on Horizon
  (Bestial Loyalty, Feral Howl, Killer Instinct, Unleash, Snarl, Spur, Run Wild). HasAbility-driven
  lists and macro hints treat them as unavailable.

Why
- Pure data files; no runtime dependencies. Must land first — pr/04, pr/05, pr/06, pr/10, pr/11 all
  depend on accurate Horizon ability/spell/WS rules. Show All and availability checks use these files
  to filter retail-only content without editing the main spell DB.
'@
        },
        @{
            Branch  = 'pr/02-foundational-compat'
            Files   = @(
                'XIUI.lua',
                'config.lua',
                'core/settings/user.lua',
                'core/settings/migration.lua',
                'core/settings/factories.lua',
                'handlers/actiontracker.lua',
                'handlers/debuffhandler.lua',
                'handlers/petbuffhandler.lua',
                'handlers/imgui_compat.lua',
                'libs/texturemanager.lua',
                'modules/hotbar/init.lua'
            )
            Subject = 'Foundational: entry point, settings, DeferRelease, independent hotbar/crossbar enable'
            Body    = @'
What changed
- XIUI.lua: Independent crossbarEnabled toggle alongside hotbarEnabled. Packet handlers (0x0068 pet
  sync, 0x0028 skillchain, 0x00A zone-in, 0x00B zone-out, 0x001B job change) fire when either bar
  is enabled — not hotbar-only — so crossbar-only setups still get palette/pet/skillchain updates.
  SaveCurrentProfileFileToDisk() swaps frozen macroDB snapshot, saves profile, persists SharedMacros.
  Post-load hook trio: ApplyAfterProfileLoad / xiuiInvalidateHotbarDataCaches /
  xiuiApplyDefaultCrossbarPaletteScopeAfterProfileLoad after every settings load or reset.
  Palette Manager + FinalizeFrame draw order: configMenu -> paletteManager -> FlushTooltip ->
  hotbar.FinalizeFrame(). WS cache init: SetKnownWeaponskills() with pcall guard after charSettings
  load so Show All WS colors are correct on login. imgui.SetMouseCursor(0) in d3d_present for
  alt-tab hardware cursor recovery. TextureManager.FlushPendingReleases() at top of d3d_present.
  hideOnMenuFocusKey intentionally absent from hotbar Register block (separate per-bar-type toggle).
- config.lua: Crossbar tab registration, Palette Manager routing, smart window sizing, non-blocking
  profile create/rename/delete modals (BeginPopup instead of BeginPopupModal); hardware cursor stays
  visible over FFXI while profile prompts are open.
- core/settings/user.lua: crossbarEnabled, crossbarLockMovement, 6 macro storage scope keys,
  petBarResizeAnchor, petTargetSnapTopGap, petTargetSnapCachedHeight. Retains all 1.8.0 additions.
- core/settings/migration.lua: 6 Ferris migrations + EnsureMacroDatabaseCoherence +
  MigrateSlotDualMacroBindings. Runs after 1.8.0's MigrateSlotMacroRefs; idempotent.
- core/settings/factories.lua: createCrossbarDefaults() rewrite: universal palettes, segmentOverrides,
  double-tap preview, paletteJobIconTheme, magicBurst defaults. Re-injected 1.8.0's showStackQuantity
  lines. mpCostAnchor defaults to topLeft.
- handlers/actiontracker.lua, debuffhandler.lua, petbuffhandler.lua: Ferris-only overlays carried
  forward unchanged (1.8.0 did not touch these files).
- handlers/imgui_compat.lua: Ashita 4.3/4.16 compatibility shim; focus-regain hardware cursor
  recovery; hover detection helpers used by pet target cluster drag.
- libs/texturemanager.lua: TextureManager.DeferRelease(value) public API — holds a Lua reference
  to a D3D texture for one extra d3d_present frame before releasing, preventing
  EXCEPTION_ACCESS_VIOLATION when palette deletion triggers a cache clear mid-frame. Extends
  1.8.0's existing pendingReleases / FlushPendingReleases pattern. Also: custom_icons.maxSize = 0
  no-eviction tweak prevents macro picker stutter from LRU evict+reload cycles.
- modules/hotbar/init.lua: M.FinalizeFrame() for deferred drag/drop resolution. Separated hotbar
  vs crossbar menu-hide logic. GetCrossbarDisableXiMacrosEffective(). lastPaletteVisualRefreshSig
  dedup. ValidatePalettesForJob with applyDefaultCrossbarScope. Universal 2hr reset/sync on
  zone/job change. 1.8.0's AnyBarIsPetAware() optimization preserved.

Why
- Foundation layer that must land before all feature slices. Establishes independent hotbar/crossbar
  enable so crossbar-only setups receive all state updates. DeferRelease prevents reproducible CTD
  on palette deletion (EXCEPTION_ACCESS_VIOLATION when D3D texture freed while still queued for
  AddImage). Post-load hook trio ensures macro scope, caches, and crossbar palette scope are
  coherent after any settings mutation. Non-blocking profile modals keep cursor visible throughout.
'@
        },
        @{
            Branch  = 'pr/03-shared-macro-store'
            Files   = @(
                'core/shared_macro_store.lua',
                'libs/target.lua',
                'modules/hotbar/universal_two_hour.lua',
                'modules/hotbar/macro_global_defaults.lua',
                'modules/hotbar/macro_xiui_defaults.lua'
            )
            Subject = 'Shared macro store, dual per-slot bindings, and Universal 2 Hour Global macro'
            Body    = @'
What changed
- core/shared_macro_store.lua: Two-mode macro storage — shared (global SharedMacros.lua across all
  profiles) vs profile (per-profile gConfig.macroDB). Frozen snapshot in shared mode for profile
  switch. Separate id namespace from profile macros. ApplyAfterProfileLoad integration.
- libs/target.lua: subtarget-active detection treats a standalone subtarget as active even without
  a primary target, so Universal 2 Hour /ja targeting (stpc/stnpc) matches in-game behavior.
- modules/hotbar/universal_two_hour.lua: Maps job ID -> 2-hour ability name. Arming window (~7.5s)
  after execute with late-window opacity ramp for shimmer. Subtarget-glow eligibility cleared on
  zone/job change. ShouldGlowUniversalTwoHourSlot() for slot renderer gating.
- modules/hotbar/macro_global_defaults.lua: Sentinel resolution for Universal 2 Hour Global macro.
  /ja bind targets: stpc for most jobs, stnpc for RNG. One-time seed migration gated by flag.
  Locked Global-row macro cannot be deleted or moved through normal palette paths.
- modules/hotbar/macro_xiui_defaults.lua: Default /xiui slash macros (Toggle XIUI Menu, Open
  Macros, Palette Manager, etc.). One-time seed gated by macroXiuiDefaultsSeeded.

Why
- One global shared macro library vs per-profile gConfig.macroDB; each physical hotbar/crossbar slot
  holds independent macroBindProfile and macroBindShared arms (active arm follows scope). Deletes,
  DnD, JSON import, and Edit Full Palette use the same data paths. Players get one pinned Global
  macro that always reflects the current main job 2-hour name, icon, and correct /ja targeting
  without hand-maintaining per-job copies. Default /xiui macros seed discoverability.
'@
        },
        @{
            Branch  = 'pr/04-smn-bloodpacts-data'
            Files   = @(
                'modules/hotbar/database/horizon_bloodpacts.lua',
                'modules/hotbar/database/horizon_bloodpacts_xiui.lua',
                'modules/hotbar/database/horizonspells.lua',
                'scripts/gen_horizon_bloodpacts.py',
                'modules/hotbar/petregistry.lua',
                'assets/pets/bloodpact.png',
                'assets/pets/ward.png',
                'assets/pets/drg_wyvern.png',
                'assets/pets/jug.png',
                'assets/hotbar/SMN/AvatarsFavor.png',
                'assets/status/Tetsouou/35.png',
                'assets/pets/avatars/alexander.png',
                'assets/pets/avatars/atomos.png',
                'assets/pets/avatars/caitsith.png',
                'assets/pets/avatars/carbuncle.png',
                'assets/pets/avatars/diabolos.png',
                'assets/pets/avatars/fenrir.png',
                'assets/pets/avatars/garuda.png',
                'assets/pets/avatars/ifrit.png',
                'assets/pets/avatars/leviathan.png',
                'assets/pets/avatars/odin.png',
                'assets/pets/avatars/ramuh.png',
                'assets/pets/avatars/shiva.png',
                'assets/pets/avatars/siren.png',
                'assets/pets/avatars/titan.png',
                'assets/pets/spirits/darkspirit.png',
                'assets/pets/spirits/earthspirit.png',
                'assets/pets/spirits/firespirit.png',
                'assets/pets/spirits/icespirit.png',
                'assets/pets/spirits/lightspirit.png',
                'assets/pets/spirits/thunderspirit.png',
                'assets/pets/spirits/waterspirit.png',
                'assets/pets/spirits/windspirit.png'
            )
            Subject = 'SMN: Horizon blood pact tables, pet registry merge, and SMN/pet UI assets'
            Body    = @'
What changed
- horizon_bloodpacts.lua: Synthetic spell-shaped rows (ids starting 10200) with level/MP/element
  from Horizon progression data.
- horizon_bloodpacts_xiui.lua: XIUI overlays on top of blood pact rows: status labels, corner icons,
  requiresFlow flag for Astral Flow-only pacts.
- horizonspells.lua: Extended with blood pact integration hooks and Horizon-specific spell data.
- gen_horizon_bloodpacts.py: Regeneration source script for the Lua tables; run when source data
  changes to rebuild horizon_bloodpacts.lua without manual editing.
- petregistry.lua: Merges retail avatar metadata with Horizon blood pact stats and XIUI overlays.
  GetBloodPactByName / RebuildBloodPactIndex for consistent blood pact lookup. Astral Flow-gated
  pacts (requiresFlow): pink asterisk in picker lists with tooltip "only during Astral Flow".
  GetBloodPactsExpanded (Show All): AF-only pacts sort before Commands, then BP:Rage, then BP:Ward
  (within each band: availability, level, name). Single resolution point for all BP display/gating.
- SMN/pet UI assets: bloodpact.png, ward.png for blood pact / ward type indicators. drg_wyvern.png,
  jug.png for DRG wyvern and BST jug pet types. AvatarsFavor.png for SMN crossbar corner.
  Tetsouou/35.png status icon (Frost Armor). Full avatar PNG set (14 avatars) and full spirit PNG
  set (8 spirits) for pet bar and palette display.

Why
- Blood pact availability and costs match Horizon progression; data can be regenerated when source
  tables change. Single registry lookup for BP display and gating across hotbar, macro editor, and
  pet palette. Full avatar/spirit art assets ship alongside the code that uses them.
'@
        },
        @{
            Branch  = 'pr/05-smn-actions-bloodpacts'
            Files   = @(
                'modules/hotbar/actions.lua',
                'modules/hotbar/recast.lua',
                'modules/hotbar/macroparse.lua'
            )
            Subject = 'SMN: blood pact action resolution, recast sniffers, and macro primary parser'
            Body    = @'
What changed
- actions.lua: BloodPactRage/BloodPactWard handling. GetBloodPactByName integration for icon
  resolution. Horizon-aware resolveSpellIndexForMa. spellsByLowerNameLookup lazy multimap for O(1)
  name lookups. noIconCache extended key for blood pact slots. LoadItemIconByName via
  actiondb.GetItemId. Effective level reads party:GetMemberMainJobLevel(0) / GetMemberSubJobLevel(0)
  (post-Level-Sync) instead of raw player:GetMainJobLevel() so synced-down players see correct
  availability. NotifySlotExecutionEffects skips Universal 2 Hour arming shimmer while the bind is
  on cooldown.
- recast.lua: Blood pact shared timer (173/174) name-based lookup. Macro text sniffers:
  sniffRecastTargetFromMaMacroText, sniffRecastTargetFromPetMacroText, sniffRecastTargetFromJaMacroText.
  BuildCommandString uses resolved ability names and per-job target tokens. Lazy recast architecture
  preserved (no periodic M.Update() reintroduced).
- macroparse.lua: New file. Multi-line macro parser. Priority order: /ws,/ma,/pet -> /ja ->
  /item,/equip -> other. Returns primary action type + JA badge for corner rendering. Drives
  skillchain/MB routing for macros, recast sniffing, and crossbar SMN blood pact dispatch.

Why
- Hotbar and macro layers resolve correct icons, names, and cooldowns for blood pact abilities.
  Macro parser enables skillchain prediction and Magic Burst highlight routing for /pet and /ma
  primary macros on the crossbar, matching the keyboard hotbar's existing behavior.
'@
        },
        @{
            Branch  = 'pr/06-playerdata-show-all'
            Files   = @(
                'modules/hotbar/playerdata.lua',
                'modules/hotbar/actiondb.lua',
                'modules/hotbar/equipment_ws.lua',
                'handlers/statushandler.lua'
            )
            Subject = 'Player data: Show All lists, spell sort, availability, equipment WS cache, Level Sync invalidation'
            Body    = @'
What changed
- playerdata.lua: GetAllSpells, GetAllAbilities, GetAllWeaponskills with status tiers and hover
  reason strings. ABILITY_TYPE enum (24 entries). Spell sort: level then name within magic type;
  WS sort: weapon category A->Z, skill req low->high (non-relic before relic). JA two-hour sorts
  first; pink asterisk + tooltip for Universal 2 Hour hint. Trait + CategoryPlaceholder filters.
  Horizon filtering throughout using horizon_abilities.lua and horizon_spell_omissions.lua.
  GetExpandedAbilities via actiondb.GetAbilityId; playerHasLearnedNonWsAbilityByName O(1);
  WS scans via actiondb.GetWeaponSkillAbilityIds(). RefreshCachedLists called at DrawWindow top
  for crossbar-only setups (fixes crossbar JA/WS slots showing unavailable without hotbar on).
- actiondb.lua: GetWeaponSkillAbilityIds() lazy session-cached list. Collapses O(1024) ability
  scans to O(1) or O(~50-100) per cache miss for WS availability and icon resolution paths.
- equipment_ws.lua: New file. WS cache-bust signature: job + levels + level sync + main/sub/range
  item IDs. Drives WS list refresh on gear swap without full rescan.
- handlers/statushandler.lua: Level Sync buff detection (LEVEL_SYNC_BUFF_ID = 269); transition
  block clears playerdata cache + slotrenderer availability cache. Encoding import updated to
  libs.encoding (replaces deprecated gdifonts path from 1.7.5).

Why
- Macro editor and hotbar show consistent availability and readable lists on Horizon without labeling
  retail-only additions as usable. Crossbar-only setups correctly show JA/WS availability without
  requiring the keyboard hotbar. Availability caches invalidate on Level Sync toggle so synced-down
  players see correct spell/ability lists.
'@
        },
        @{
            Branch  = 'pr/07-slotrenderer-uth-skillchain'
            Files   = @(
                'modules/hotbar/slotrenderer.lua',
                'modules/hotbar/display.lua'
            )
            Subject = 'Slot renderer: imtext port, UTH rainbow border, skillchain highlight, editor clip, availability badges'
            Body    = @'
What changed
- slotrenderer.lua: Complete GDI-font -> imtext/drawList port. Key additions:
  DrawSkillchainHighlight: gold dashed marching-ants border + SC-name icon top-right corner.
  DrawUniversalTwoHourRainbowMarchingBorder + DrawUniversalTwoHourSubtargetGlow: pure ImGui drawList;
  shimmer suppressed on cooldown; subtarget glow eligibility gated by universalTwoHour module.
  Unavailable ability feedback: GetFrameAvailability() snapshots (jobId, subjobId, mainLevel,
  subLevel, partyMain, partySub) once per frame via M.BeginFrame — replaces ~7 FFI getters x 16-32
  slots x 60 fps with one compare per frame. displayText pre-parsed at cache-insert as unavailableReason.
  Allowlist expanded to cover ma, ja, ws, pet, macro action types. Size-bounded caches (8192
  availability, 4096 MP cost). labelAboveSlot flag: live HUD respects params.labelAboveSlot; crossbar
  passes true for top diamond slot. slotOverlayDrawList() returns imgui.GetWindowDrawList() for
  crossbar window (keeps overlays within window z-order, not above modal dialogs). IsMovementLockedForDropZone
  routes crossbar_* -> crossbarLockMovement, paled* -> always unlocked. dropPriority support for
  deferred drop resolution (EFP palette editor uses priority 10). DeferRelease on ClearAllCache,
  ClearSlotRenderingCache, ClearAvailabilityCache so D3D handles are not freed mid-frame. Double-click
  tracker (lastClickButtonId, lastClickTime, DOUBLE_CLICK_INTERVAL 0.35s) with 4-branch dispatcher.
  MakePreviewSettings cached on geometry signature; preview early-exit when baseOp <= 0.02.
- display.lua: Keyboard hotbar render path with Ferris additions on 1.8.0 perf base. macro JA badge
  cache suffix. GetBindIcon cache-miss path. mpCostAnchor topLeft default. Skillchain prediction for
  BP+macros via macroparse. RefreshCachedLists at DrawWindow top. Deferred icon cache clear via
  DeferRelease. ClearNoIconCache hook. 1.8.0 reusable slotParams/slotInteraction tables preserved.

Why
- Central hot path for all slot rendering; must land before any DrawSlot caller (pr/08, pr/09,
  pr/14, pr/18). Availability feedback ported to imtext path: grayed/Lv65/X labels for unavailable
  spells, JAs, WS, pet commands, and macros. UTH visual arming cue matches Horizon targeting semantics.
  Frame snapshot reduces availability cost to constant regardless of slot count.
'@
        },
        @{
            Branch  = 'pr/08-magic-burst-highlight'
            Files   = @(
                'modules/hotbar/skillchain.lua',
                'modules/hotbar/slotrenderer.lua',
                'modules/hotbar/display.lua',
                'modules/hotbar/crossbar.lua',
                'core/settings/factories.lua',
                'config/hotbar.lua'
            )
            Subject = 'Magic Burst highlight: MB window state, slot border, crossbar wiring, and settings UI'
            Body    = @'
What changed
- skillchain.lua: magicBurstMap state tracked alongside resonationMap (different lifetimes; separate
  keys). MB_WINDOW_OPEN_DELAY = 0.0s, MB_WINDOW_DURATION = 7.0s after skillchain close. Eligible
  elements resolved via magicBurstElements map covering all 14 SC tiers (Lv1 single-element through
  Lv3 Light/Darkness multi-element sets). SMN Magic Blood Pact Rages curated via bloodPactElementMap
  (12 pacts: Fire II/IV, Stone II/IV, Aero II/IV, Water II/IV, Thunder II/IV, Blizzard II/IV —
  physical and off-element pacts deliberately excluded). spellElementByLowerName lazy cache resolves
  element from horizonspells DB. Public API: GetBurstElementForSlot, GetMagicBurstForElement,
  GetMagicBurstForSlot, GetMagicBurstWindow. MB window clears on zone change (same hook as SC clear).
- slotrenderer.lua: DrawMagicBurstHighlight() — animated dashed border drawn via ImGui drawList
  alongside SC border; configurable color with pulsing opacity. params.magicBurstName branch in
  DrawSlot. Both SC and MB borders can appear simultaneously (distinct positions: SC top-right,
  MB bottom-left corner icon placement).
- display.lua, crossbar.lua: GetMagicBurstForSlot dispatch wired through all render branches;
  suppressed in palette editor preview. Crossbar routes actionType=='pet' and /pet-primary macros
  through skillchain.GetSkillchainForBloodPact for SMN Blood Pact MB eligibility (matches keyboard
  hotbar behavior; previously crossbar only checked actionType=='ws').
- core/settings/factories.lua: hotbarGlobal.magicBurstHighlightEnabled = false default;
  magicBurstHighlightColor default (cyan-blue).
- config/hotbar.lua: DrawSharedSkillchainHighlightControls includes Magic Burst checkbox + inline
  color picker nested under the Skillchain section. Shared icon scale/offset help text applies to
  both SC and MB highlight systems.

Why
- Gives players an at-a-glance Magic Burst opportunity cue without manually tracking SC results.
  Parallel to the existing skillchain highlight system; reuses the same imtext drawList path and
  hotbarGlobal settings. SMN Blood Pact coverage limited to Magic-element pacts to avoid false
  positives from physical pacts that cannot MB regardless of skillchain.
'@
        },
        @{
            Branch  = 'pr/09-hotbar-display'
            Files   = @(
                'modules/hotbar/display.lua',
                'modules/hotbar/actiondb.lua'
            )
            Subject = 'Hotbar display: keyboard hotbar render path with SC/MB dispatch and macro badge cache'
            Body    = @'
What changed
- display.lua: Keyboard hotbar slot rendering on 1.8.0 imtext base. Skillchain prediction for blood
  pact and macro slots via macroparse primary action resolution. Magic Burst GetMagicBurstForSlot
  dispatch per slot. macro JA badge cache suffix for correct badge resolution on shared-vs-profile
  scope. mpCostAnchor topLeft as default when bar settings omit the key. RefreshCachedLists at
  DrawWindow top so Show All lists are warm without explicit user action. Deferred DeferRelease on
  ClearIconCache and ClearIconCacheForSlot. 1.8.0 reusable slotParams/slotInteraction tables preserved.
- actiondb.lua: GetWeaponSkillAbilityIds() lazy list used by display and playerdata to avoid O(1024)
  scans on every WS availability check.

Why
- Keyboard hotbar slots show skillchain and Magic Burst eligibility for /ma, /pet, and macro primary
  commands matching crossbar behavior. Icon cache clears are deferred through DeferRelease to
  prevent mid-frame D3D access violations.
'@
        },
        @{
            Branch  = 'pr/10-macro-system'
            Files   = @(
                'modules/hotbar/macro_palette_buckets.lua',
                'modules/hotbar/macroparse.lua',
                'modules/hotbar/macro_xiui_defaults.lua',
                'modules/hotbar/macro_global_defaults.lua',
                'core/settings/migration.lua'
            )
            Subject = 'Macro system: palette buckets, macro parser, default seeds, and dual-binding migration'
            Body    = @'
What changed
- macro_palette_buckets.lua: Bucket schema: global, items, equipment, xiui, custom:N. Custom buckets
  support create/rename/delete with slot cleanup via ApplyMacroPaletteBucketRemovedToSlotAction
  (sweeps profile + shared gConfig, clears all slot arms bound to removed bucket key).
- macroparse.lua: Multi-line macro text parser. Priority: /ws,/ma,/pet -> /ja -> /item,/equip ->
  other. Returns primary action type and command string for JA badge, skillchain/MB routing, and
  recast sniffing. Pure logic; no render code.
- macro_xiui_defaults.lua: Default /xiui slash macros seeded once (Toggle XIUI Menu, Open Macros,
  Open Palette Manager, etc.); gated by macroXiuiDefaultsSeeded flag in migration.
- macro_global_defaults.lua: Universal 2 Hour Global macro sentinel. Job -> 2-hour name map.
  /ja bind targets with per-job targeting tokens. Migration seed runs after XIUI defaults.
- core/settings/migration.lua: MigrateSlotDualMacroBindings upgrades legacy single-arm slot records
  to macroBindProfile + macroBindShared dual-arm format. MigrateSlotMacroRefs (1.8.0) preserved.

Why
- Organizes macro library by category; custom types for user-defined groupings with full cleanup
  on delete. Macro parser drives corner badge, SC/MB routing, and recast sniffing from a single
  consistent source. Default seeds give new users discoverability and a working 2-hour macro
  out of the box. Migration idempotently upgrades existing profiles.
'@
        },
        @{
            Branch  = 'pr/11-macro-editor'
            Files   = @(
                'modules/hotbar/macropalette.lua',
                'modules/hotbar/macropalette_macroeditor.lua',
                'modules/hotbar/playerdata.lua',
                'modules/hotbar/customiconresolve.lua',
                'modules/hotbar/iconmatch.lua',
                'modules/hotbar/textures.lua'
            )
            Subject = 'Macro editor: Show All UI, spell colors, Copy, JA badge sync, spell dedup, and custom icon resolution'
            Body    = @'
What changed
- macropalette.lua: Show All toggles and filters (magic type, ability job, WS weapon, pet type).
  Two-color spell rows (magic-type color + status color). Group headers. Hover reasons on unavailable
  entries. Ability/BP rows: pink asterisk tooltips for main-job 2-hour (Global macro note) and
  Astral Flow-only pacts. Copy: duplicate selected macro into editor as a new entry. Locked Global-row
  handling: Universal 2 Hour macro cannot be deleted or edited through palette duplicate/remove paths.
  Custom type (+) in popup only; red remove and Rename on the type row; delete confirms macro count;
  rename modal; delete and rename save paths. Custom grid section header uses Elementals for spirit
  pets. Move Macro: MoveMacroToPalette API, palette picker popup. RewriteMacroPaletteBindingsInConfig
  + RewriteMacroPaletteBindingsInDraft update all bindings on move. OpenEditorForSlotData accepts
  opts.bindTargetSlot for double-click-new-macro EFP flow.
- macropalette_macroeditor.lua: New 86 KB closure-factory extension (return function(MP) pattern).
  SaveMacro syncs dropdown/text buffers into editingMacro before validation so saves match UI state.
  Main slot icon: implicit refresh on macro text edit no longer forces overwrite; Sync refreshes
  main icon. JA badge: separate manual vs implicit sync; Sync JA badge clears manual overrides and
  resolves from /ja line; icon picker marks manual badge on Change. Auto-bind new macro to
  pendingNewMacroBindTarget slot via data.SetDraftSlotData when set by EFP double-click.
  Show All combo rows: single InvisibleButton hit target with draw-list text/icons so overlapping
  widgets do not swallow clicks.
- playerdata.lua: Spell dedup on spell id before building display list removes duplicate rows for
  spells that appear under multiple magic-type categories. GetPlayerSpells reads unlearnable flags
  from horizonspells.lua; Show-All-off consistently shows only known/available spells without gaps.
- customiconresolve.lua: New file. Resolves assets/hotbar/custom/*.png by action name (recursive
  scan with caching). Allows users to drop custom-named PNGs into the custom/ folder and have them
  appear on matching macro/action slots automatically.
- iconmatch.lua: New file. Fuzzy name-to-icon matcher used by customiconresolve for partial-name
  and case-insensitive resolution.
- textures.lua: Custom texture resolution layer. custom_icons.maxSize = 0 no-eviction tweak
  (prevents macro picker stutter from LRU evict+reload on large custom icon sets).

Why
- Large spell/ability lists stay navigable; Copy speeds palette workflows; icon and badge behavior
  matches user expectations. Custom icon resolution lets users add their own named PNGs to
  assets/hotbar/custom/ and see them on matching slots without editing Lua. Spell dedup and
  unlearnable-flag filtering prevent spurious duplicate rows and missing spells in the picker.
'@
        },
        @{
            Branch  = 'pr/12-profile-json'
            Files   = @(
                'modules/hotbar/palette_json.lua',
                'libs/json.lua',
                'modules/hotbar/palette.lua',
                'modules/hotbar/init.lua',
                'config.lua'
            )
            Subject = 'Profile JSON: whole-profile backup/transfer with export, import, merge, and post-import refresh'
            Body    = @'
What changed
- palette_json.lua: New 40 KB module. Whole-profile JSON export/import (xiuiExportVersion 1, kind
  xiui_profile). Exports all keyboard palettes, all crossbar palettes, and the full macro library
  in one annotated JSON file. Merge vs replace import; file list + paste input; exports folder
  helpers. Post-import hooks call InvalidateCachesAfterExternalSlotMutation and
  RefreshActivePaletteVisualsAfterExternalEdit so the active bar refreshes immediately.
- libs/json.lua: rxi's json.lua (MIT). JSON encode/decode used by palette_json.
- palette.lua: InvalidateCachesAfterExternalSlotMutation; RefreshActivePaletteVisualsAfterExternalEdit
  after external edits (e.g. import). ValidatePalettesForJob merges factory crossbar defaults into
  gConfig.hotbarCrossbar before reading enableUniversal/defaultCrossbarPaletteScope.
- init.lua: OnPaletteChanged dedupe includes bar/combo id for same-name refreshes so every bar
  reloads after import.
- config.lua: Profiles window Backup/Transfer (export/import modal), larger Profiles window size,
  merge/replace and import toggles.

Why
- Before: no structured way to move an entire character's bars and macros between copies or accounts.
  After: one JSON file per profile for full backup or migration. Import refreshes the visible UI
  immediately without requiring a manual palette switch or relog.
'@
        },
        @{
            Branch  = 'pr/13-palette-manager-ui'
            Files   = @(
                'config/palettemanager.lua',
                'config/hotbar.lua',
                'config/components.lua',
                'assets/checkmark.png',
                'assets/x.png'
            )
            Subject = 'Palette Manager: expanded UI, status icons, +M macro button, non-blocking popups'
            Body    = @'
What changed
- config/palettemanager.lua: Floating Palette Manager window expanded from stub to full 146 KB
  implementation. Override/Pet rows, scroll-safe layout, horizontal resize, job label and warnings
  when editing a palette that is not active, quick palette switcher, crossbar edit appearance
  decoupled from in-game crossbar visuals. Active/Inactive column uses centered image icons
  (checkmark.png / x.png) via TextureManager.getFileTexture instead of text labels. +M button on
  each palette row pre-populates a new macro with the /xiui cpal switch command for that palette
  (eliminates manual macro authoring for palette switches). New palette popup converted from blocking
  BeginPopupModal to BeginPopup (hardware cursor stays visible). Crossbar Copy To adds destination
  scope Job/Subjob [J] vs Global [G] with destination lists wired for each mode. Scroll-safe clip
  rect for clipped preview rows.
- config/hotbar.lua: Shared palette create/rename modal helpers for hotbar AND crossbar. Persists
  last-selected job/storage-subjob tier across opens; resets only on character job/subjob change.
  Auto-names new palettes based on tier selection. DrawSharedDisableXiMacrosControls,
  DrawSharedSkillchainHighlightControls, DrawLogPaletteNameCheckbox shared helpers. AlwaysClamp on
  Rows/Columns sliders per 1.8.0 slider policy.
- config/components.lua: MANAGER_BUTTON_STYLE table + 4 push/pop helpers + DrawStyledTab variant
  parameter for consistent styled tabs/buttons in Palette Manager and config UI.
- assets/checkmark.png, assets/x.png: New UI assets for palette list Active/Inactive column icons.

Why
- Central hub for palette CRUD, crossbar scope management, and profile portability. Non-blocking
  popups keep hardware cursor visible throughout palette creation and copy operations. +M button
  and named status icons reduce friction in day-to-day palette management.
'@
        },
        @{
            Branch  = 'pr/14-crossbar-core'
            Files   = @(
                'modules/hotbar/crossbar.lua',
                'modules/hotbar/palette.lua',
                'core/settings/factories.lua',
                'core/settings/migration.lua',
                'core/settings/user.lua'
            )
            Subject = 'Crossbar core: visual cutoff fix, WindowPadding, shared expanded bar, inactive dim, palette scope icon'
            Body    = @'
What changed
- crossbar.lua: CROSSBAR_WINDOW_TOP_DECOR_PAD = 80px — crossbar ImGui window opens higher and
  taller than slot grid so L2/R2 trigger icons, R1 pulse, palette name, action labels, and combo
  text are not clipped. ApplyCrossbarWindowPositionOnce/SaveCrossbarWindowSlotTopPosition persist
  slot-grid top Y (not window top); profile-compat on first load. imgui.PushStyleVar WindowPadding
  {0,0} before Begin/End recovers leftmost/rightmost diamond slot clipping and hitbox inset.
  useSharedExpandedBar: when L2+R2 chord held, both diamonds collapse to single centered 8-slot
  strip; GetDisplayModes returns 'Shared'; window force-centers; lastWideCrossbarWindowX stashed
  for exit-chord restore. DrawTriggerIconsSharedExpandedCenter for combined glyph.
  inactiveSideWhileTriggerDim = 0.15 (vs inactiveSlotDim 0.5) when activeCombo != NONE; threaded
  through 11 call sites for clearer visual focus on active half during trigger hold.
  GetInfinityPaletteIconTexture (lazy session-cached), GetPaletteJobIconThemeFromSettings,
  ShouldShowPaletteScopeIcon, DrawPaletteScopeIconAboveDivider — visual cue for Global vs Job
  palette scope above crossbar divider. GetCrossbarPaletteLabelIndexAndTotal: only renders
  (idx/total) suffix when total > 1 (suppresses '(1/1)' noise with one enabled palette).
  IsMovementLockedForDropZone routes crossbar_* -> crossbarLockMovement. MakePreviewSettings cache
  on geometry signature; double-tap preview early-exit. playerdata.RefreshCachedLists at DrawWindow
  top for crossbar-only setups. SMN crossbar: actionType=='pet' and /pet-primary macros routed
  through skillchain.GetSkillchainForBloodPact matching keyboard hotbar.
  ClassicFFXIV removed from paletteIconThemes dropdown; GetPaletteJobIconThemeFromSettings and
  GetCrossbarPaletteJobIconThemeFromSettings allowlists narrowed; one-shot migration falls back to
  Classic on first open.
- palette.lua: Cpal anchor API: SetCpalJobAnchorIfUnset/SetCpalUniversalAnchorIfUnset,
  GetCpalAnchor, ClearCpalAnchor, RestoreCpalAnchor. CLI preview state, clear on active palette
  / cycle. GetCrossbarSjOnlyPaletteNamesOrdered. Universal palette rename/delete syncs segmentOverrides
  refs. CopyCrossbarPaletteToUniversal / CopyUniversalCrossbarPaletteToJob with overwrite option.
  Cycle ordering. ValidatePalettesForJob with scope application.
- core/settings/factories.lua, migration.lua, user.lua: crossbarLockMovement, crossbarDisableInMenu,
  useSharedExpandedBar, inactiveSideWhileTriggerDim, paletteJobIconTheme defaults and migrations.

Why
- Foundational crossbar fixes: clipping (top/bottom decor + WindowPadding zero) must land before all
  crossbar UX slices. Shared expanded bar and inactive-side dim are layout/visual choices that all
  subsequent crossbar PRs depend on. Must merge before pr/15, pr/16, pr/17, pr/18.
'@
        },
        @{
            Branch  = 'pr/15-crossbar-cpal-r1-return'
            Files   = @(
                'XIUI.lua',
                'modules/hotbar/palette.lua',
                'modules/hotbar/controller.lua',
                'modules/hotbar/crossbar.lua'
            )
            Subject = 'Crossbar: /xiui cpal anchor with pulsing R1 x2 indicator and R1 double-tap return'
            Body    = @'
What changed
- modules/hotbar/palette.lua: Cpal anchor API — SetCpalJobAnchorIfUnset/SetCpalUniversalAnchorIfUnset
  record the active palette before the first /xiui cpal switch; GetCpalAnchor/ClearCpalAnchor/
  RestoreCpalAnchor allow controller code to retrieve, clear, or jump back to origin. Separate
  anchors for job-tier and universal scope. GetCrossbarSjOnlyPaletteNamesOrdered for 6-letter
  MAINSUB # indexing.
- XIUI.lua: Anchor set immediately before SetActivePaletteForCombo/SetActiveUniversalCrossbarPalette
  in the /xiui cpal handler so origin is always saved on the first switch. Full /xiui cpal /
  cpalette / xcpal / xcpalette command family: list, toggle, scope (job|universal), cycle on|off,
  global/g/gname, compact MAIN+SUB, explicit job, bare-job shorthand. /xiui pal, /xiui menuname,
  /xiui cpaledit. Chat lines follow logPaletteNameCrossbar; optional RB+D-pad cycle hint.
- modules/hotbar/controller.lua: R1 double-tap (two presses within 400ms, no L1 held) restores
  cpal anchor. R1+DPAD palette cycling clears anchor (cycling already serves a similar return
  function). L1/R1 shoulder-held latch state is set-only from poll, cleared exclusively by
  HandleXInputButton release events (fixes L1 cycle failing when FFXI consumes the L1 xinput bit
  before Ashita's snapshot; same fix makes R1 scope toggle and R1 double-tap more reliable).
- modules/hotbar/crossbar.lua: When a cpal anchor is live, draw a pulsing R1 icon above the R2
  label with a subtle dark-pill background and gold 'x2' hint; icon scales to ~130% at pulse peak
  (~2.5 Hz sin wave); disappears when anchor is cleared.

Why
- /xiui cpal macros can switch the active crossbar palette programmatically; the R1 indicator tells
  the player an anchor is set, and double-tapping R1 returns to the original palette without another
  macro. L1 cycle fix resolves users reporting L1 broken while R1 worked.
'@
        },
        @{
            Branch  = 'pr/16-crossbar-game-menu-block'
            Files   = @(
                'core/gamestate.lua',
                'config/crossbar.lua',
                'core/settings/factories.lua',
                'modules/hotbar/controller.lua',
                'modules/hotbar/crossbar.lua'
            )
            Subject = 'Crossbar: optional disable in game menus with visual dim feedback'
            Body    = @'
What changed
- core/gamestate.lua: IsMenuOpen() scans memory for the active FFXI menu name; IGNORED_MENUS list
  passes combat-related menus so the crossbar stays live during battle while inventory/storage menus
  block it.
- config/crossbar.lua: Disable Crossbar While In Menu checkbox under Hide When Menu Open (default on).
  When unchecked, trigger input passes through so FFXI inventory Quick Jump (trigger + D-pad) still
  works. Also hosts Lock Crossbar toggle (reads crossbarLockMovement, separate from hotbar lock).
- core/settings/factories.lua: crossbarDisableInMenu = true default.
- modules/hotbar/controller.lua: Skip XInput/DInput crossbar processing when IsMenuOpen() and
  crossbarDisableInMenu is enabled.
- modules/hotbar/crossbar.lua: visibilityOpacity *= 0.35 when menu is open and disable-in-menu is
  enabled, giving visual feedback that input is blocked.

Why
- Prevents accidental crossbar slot execution while FFXI inventory or storage menus have focus.
  Visual dim confirms input is blocked without requiring the player to open settings. Optional
  setting preserves trigger navigation for Quick Jump when preferred.
'@
        },
        @{
            Branch  = 'pr/17-crossbar-doubletap-preview'
            Files   = @(
                'modules/hotbar/crossbar.lua',
                'config/crossbar_settings.lua',
                'core/settings/factories.lua',
                'libs/drawing.lua'
            )
            Subject = 'Crossbar: floating double-tap preview windows for L2x2 and R2x2 bars'
            Body    = @'
What changed
- modules/hotbar/crossbar.lua: Two independent floating ImGui windows (CrossbarPreviewL2x2,
  CrossbarPreviewR2x2) always display the 8-slot diamond for the corresponding double-tap bar
  including live cooldowns. Slot backgrounds render at base opacity; icon/text dims with
  inactiveSideWhileTriggerDim when any trigger is held (both previews dim equally). When a
  double-tap is live the preview swaps to show the base L2 or R2 bar as reference. Windows omit
  NoBringToFrontOnFocus so they stay in front of the main crossbar; WindowPadding zeroed to prevent
  clip-rect edge clipping. Drag anchors sit above the window via anchorSide=top. MakePreviewSettings
  cached on geometry signature; early-exit when baseOp <= 0.02. Skillchain and Magic Burst borders
  enabled in preview slot rendering; MP cost and quantity displays suppressed.
- config/crossbar_settings.lua: Show Double-Tap Crossbars Preview checkbox, Preview Scale slider
  (0.30-1.0), Preview Opacity slider (0.20-1.0), Lock Preview Positions toggle — all nested under
  Enable Double-Tap.
- core/settings/factories.lua: showDoubleTapPreview=false, doubleTapPreviewScale=0.60,
  doubleTapPreviewOpacity=1.0, doubleTapPreviewLocked=false defaults.
- libs/drawing.lua: DrawMoveAnchor gains anchorSide='top' option (with windowWidth for centering)
  so the drag handle can be placed above the target window rather than to its left.

Why
- Players can see their double-tap bar contents and cooldowns at a glance without activating the
  double-tap. Preview swaps to base bar while double-tap is live so both bars are always visible.
  SC/MB borders show eligibility in preview; quantity and MP cost omitted to reduce preview noise.
'@
        },
        @{
            Branch  = 'pr/18-crossbar-edit-palette-draft'
            Files   = @(
                'config/palettemanager.lua',
                'modules/hotbar/crossbar.lua',
                'modules/hotbar/data.lua',
                'modules/hotbar/macropalette.lua',
                'modules/hotbar/macropalette_macroeditor.lua',
                'modules/hotbar/slotrenderer.lua',
                'modules/hotbar/init.lua',
                'libs/dragdrop.lua',
                'XIUI.lua'
            )
            Subject = 'Crossbar Edit Full Palette: draft layer, drag-drop, undo, Move Macro, and deferred drop UX'
            Body    = @'
What changed
- data.lua: Draft layer (draftByKey + draftTouchedKeys). Empty-slot sentinel distinguishes cleared
  palette slots from sparse untouched ones so overlay swap reads do not resurrect live binds.
  GetCrossbarSlotRawForSwapOverlay for palette row reads. SwapActiveMacroArmsInPlace,
  FinalizeCrossbarRawSlotForStorage, NormalizeCrossbarSlotRawForSwap. SyncDraftSlotFromLive merges
  HUD edits into draft only when HUD palette storage key matches draft (liveKey == rk) so hops
  between active palettes do not overwrite unrelated drafts. 6 EFP public functions. BeginDraftUndoGroup
  / EndDraftUndoGroup / UndoDraft / CanUndoDraft stack. resolveSlotMacro returns nil for minimal
  macro binding tables (macroRef + macroPaletteKey only, no displayName/action) when the referenced
  macro no longer resolves — slot draws empty instead of showing abbreviation '?' (orphan cleanup
  after macro delete). RewriteMacroPaletteBindingsInConfig + RewriteMacroPaletteBindingsInDraft
  update all bindings on Move Macro.
- crossbar.lua: GetCbInteractionPaletteEditor: getDragData uses GetCrossbarSlotRawForSwapOverlay;
  onDrop handlers use SwapActiveMacroArmsInPlace + FinalizeCrossbarRawSlotForStorage + proper
  ClearDraftSlotData; all drop branches pair BeginDraftUndoGroup with EndDraftUndoGroup; all drop
  and onRightClick handlers call ClearCrossbarIconCacheForSlot (via DeferRelease). Stale
  slotrenderer.InvalidateSlotByKey calls removed (not applicable to 1.8.0 immediate-mode renderer;
  their crashes previously prevented EndDrag from firing and left isDragging stuck true). onDoubleClick
  closure: seeds fresh macro from active palette defaults and passes bindTargetSlot to
  macropalette.OpenEditorForSlotData. Editor slot params: editorClipRect for clipped preview,
  dropPriority=10 so palette editor wins over live crossbar zone.
- libs/dragdrop.lua: deferredDropCandidates, FlushDeferredDrops() with dropPriority + registration-
  order tiebreaker. Re-applied 1.8.0 simplification (centralized tooltip in slotrenderer.FlushTooltip).
- macropalette.lua: OpenEditorForSlotData accepts opts.bindTargetSlot; stashed as
  MP.pendingNewMacroBindTarget for SaveMacro auto-bind.
- macropalette_macroeditor.lua: SaveMacro auto-binds new macro to pendingNewMacroBindTarget slot
  via data.SetDraftSlotData when set by EFP double-click flow.
- init.lua: M.FinalizeFrame() calls FlushDeferredDrops before drag renderer so palette editor drop
  zones are resolved in correct priority order.
- XIUI.lua: hotbar.FinalizeFrame() called after palette manager draw.
- config/palettemanager.lua: Consumes data.pendingPaletteSlotEdit next frame for double-click
  new-macro flow. Editor clip rect culling. Label rendering (minimal vs full multiline). Scroll-safe
  layout. Job-shared copy. Override/Pet rows for segment editing.

Why
- Removes duplicate/wrong swap behavior when draft clears overlapped live-only slots. Drag-drop
  visual artifact (square stuck on cursor) fixed by removing stale InvalidateSlotByKey calls that
  crashed the drop handler mid-frame. Undo works correctly after slot swaps. Double-clicking an
  empty EFP slot creates a new macro and auto-binds it to that slot. Orphan '?' placeholder
  eliminated after macro delete. Move Macro avoids broken binds after relocating a library row.
'@
        },
        @{
            Branch  = 'pr/19-crossbar-settings'
            Files   = @(
                'config/crossbar.lua',
                'config/crossbar_settings.lua',
                'config/hotbar.lua',
                'config/efp_pets_tab.lua',
                'config.lua'
            )
            Subject = 'Crossbar settings: separated config files, EFP pets tab, skillchain/MB UI, AlwaysClamp sliders'
            Body    = @'
What changed
- config/crossbar.lua: New file. Crossbar sidebar entry shell routing to crossbar_settings.lua.
  Lock Crossbar toggle (independent from hotbar lock). Disable Crossbar While In Menu checkbox.
- config/crossbar_settings.lua: New 70 KB file. Full crossbar settings UI extracted from hotbar.lua:
  controller layout, palette management (Job vs Global scope, palette lists), visuals (inactive dim,
  trigger icon scale, label above slot), double-tap preview sliders, disable-in-menu, palette scope
  icon theme (ClassicFFXIV removed; one-shot migration falls back to Classic). Show Double-Tap
  Crossbars Preview section. Shared skillchain + MB controls via DrawSharedSkillchainHighlightControls.
- config/hotbar.lua: Crossbar UI sections removed (~815 lines moved to crossbar.lua +
  crossbar_settings.lua). Ferris additions retained: DrawSharedDisableXiMacrosControls,
  DrawSharedSkillchainHighlightControls (SC color picker + MB checkbox + MB color picker),
  DrawLogPaletteNameCheckbox. AlwaysClamp on Rows/Columns sliders per 1.8.0 slider policy.
  Layout Mode dropdown removed from Hotbar tab. Edit Full Palette entry moved to Crossbar tab.
  AlwaysClamp also applied to castbar Fast Cast sliders and notification group sliders.
  Show Stack Quantity checkbox re-applied from 1.8.0. Slot Y Padding slider retained.
- config/efp_pets_tab.lua: New file. EFP pet family tabs (Avatars, Elementals, Beasts, Wyvern,
  Puppet). Avatar vs spirit elemental distinction. SMN sort and pet-bar omit rules.
- config.lua: Crossbar tab registration. Crossbar tab dispatches to config/crossbar.lua.

Why
- User explicitly separated hotbar and crossbar configuration concerns; Lock Crossbar and
  Edit Full Palette entry belong in the Crossbar tab. ClassicFFXIV removal prevents user-custom
  theme from appearing in a public dropdown. AlwaysClamp compliance brings all Ferris-touched
  config files into line with 1.8.0 slider policy.
'@
        },
        @{
            Branch  = 'pr/20-segment-overrides'
            Files   = @(
                'modules/hotbar/data.lua',
                'modules/hotbar/palette.lua',
                'core/settings/factories.lua',
                'core/settings/migration.lua'
            )
            Subject = 'Crossbar segment overrides: per-job storage, resolution, palette rename/delete sync, and copy paths'
            Body    = @'
What changed
- data.lua: hotbarCrossbar.segmentOverrides keyed by job and effective combo mode. Job-Shared
  (jobsegment:...) and Global palette sources resolve before legacy universal override. Draft editing
  uses draftByKey + draftTouchedKeys for redirected segment buckets; undo tracks touched keys.
  GetCrossbarStorageKeyForCombo and display name respect CLI preview state. Clear CLI preview on
  job change.
- palette.lua: When a universal crossbar palette is renamed or deleted, segmentOverrides entries
  that referenced it (scope=global + globalPalette) are updated or cleared so stale names cannot
  linger. CopyCrossbarPaletteToUniversal: copy a Job/Subjob-tier palette into the all-jobs
  universal [G] namespace (overwrite optional). CopyUniversalCrossbarPaletteToJob: copy a Global [G]
  palette into a specific Job/Subjob-tier palette (overwrite optional). Cycle ordering for segment
  override palettes. GetCrossbarSjOnlyPaletteNamesOrdered. crossbarCliPreview state.
- core/settings/factories.lua: segmentOverrides = {} default; mpCostAnchor top-left for new configs.
- core/settings/migration.lua: Crossbar segment override migration steps.

Why
- Lets per-job crossbar segments point at shared tiers or global palettes without duplicating slot
  data. Rename/delete stays consistent with segment UI. New copy paths support moving palettes
  between per-job storage and global crossbar storage without manual file editing. Draft/undo works
  correctly for segment-redirected slots.
'@
        },
        @{
            Branch  = 'pr/21-segment-overrides-efp-ui'
            Files   = @(
                'config/palettemanager.lua',
                'modules/hotbar/crossbar.lua'
            )
            Subject = 'Segment overrides EFP UI: override rows, crossbar editor segment integration'
            Body    = @'
What changed
- config/palettemanager.lua: Override and Pet rows in Edit Full Palette for segment override
  management. Scroll-safe layout for segment rows. Job-shared copy flow. Warning when editing a
  palette that is not the currently active segment palette. Quick palette switcher for segments.
  Crossbar edit appearance controls decoupled from in-game crossbar visuals.
- modules/hotbar/crossbar.lua: Palette editor row APIs for segment integration. Trigger glyphs for
  segment editing context. editorClipRect passed into DrawSlot for clipped preview of segment
  override palettes.

Why
- Provides a UI for managing which palette a crossbar segment points to, with contextual warnings
  and copy operations. Depends on pr/18 (EFP draft infrastructure) and pr/20 (segment override
  data storage).
'@
        },
        @{
            Branch  = 'pr/22-pet-palette-allowlist'
            Files   = @(
                'modules/hotbar/pet_palette_allowlist.lua',
                'config/efp_pets_tab.lua',
                'modules/hotbar/petpalette.lua',
                'modules/hotbar/petregistry.lua',
                'modules/hotbar/macropalette.lua',
                'core/settings/factories.lua',
                'modules/castcost/display.lua'
            )
            Subject = 'Pet palette: Avatars and Elementals split, EFP pet tabs, BST jug Ready cost display'
            Body    = @'
What changed
- pet_palette_allowlist.lua: New file. Type tokens: avatars, elementals, beasts, wyvern, puppet.
  Legacy "summons" still matches avatars+elementals and upgrades in the editor. Slot Configure and
  Pet Palette use the same type name constants.
- config/efp_pets_tab.lua, palettemanager.lua, crossbar.lua, petregistry.lua: Edit Full Palette
  pet family tabs (Avatars, Elementals, Beasts, Wyvern, Puppet). Avatar vs spirit elemental
  distinction. SMN sort and pet-bar omit rules applied consistently.
- macropalette.lua: Custom grid section header uses Elementals label for spirit pets. Add custom
  type (+) only in popup; red remove and Rename on the type row; delete confirms macro count.
- core/settings/factories.lua: petPalettePetKeys defaults; comments for new type tokens.
- modules/castcost/display.lua: BST Ready jug shows pet charge cost as 'Cost: N' (TP-gold color)
  instead of mislabeled MP when hovering spell rows fed from petregistry helpers.

Why
- SMN 'summons' split into avatars vs elementals for configuration and EFP so each family can be
  separately enabled/positioned. Custom macro categories can be managed from the type row with full
  cleanup of that palette bucket and revert of affected slots. BST Ready charge cost reads like
  gameplay (charges, not MP).
'@
        },
        @{
            Branch  = 'pr/23-pet-bar-resize-anchor'
            Files   = @(
                'modules/petbar/display.lua',
                'modules/petbar/data.lua',
                'modules/petbar/pettarget.lua',
                'config/petbar.lua',
                'core/settings/migration.lua',
                'core/settings/user.lua',
                'handlers/imgui_compat.lua',
                'handlers/helpers.lua'
            )
            Subject = 'Pet bar: global resize anchor, anchored-bottom math, snap-top fix, and cluster drag'
            Body    = @'
What changed
- display.lua / data.lua: Global gConfig.petBarResizeAnchor (top vs bottom pinned edge when
  auto-resize changes height). PetBarResizeAnchoredBottom prefers that value and falls back to
  legacy per-type alignBottom until migration runs. Stable bottom-edge math for align-bottom resize.
  Preview Mode stripes the anchored edge. Cache lastPetBarTargetWindowHeight for snap placement.
  petBarTargetHitRect for cluster drag. petBarSyncResizeAnchorNextFrame for cluster drag anchor sync.
- pettarget.lua: Snap-with-top places Pet Target above the pet bar using last-frame window height
  plus offsets. Skips ApplyWindowPosition when snap wins. Snap Y/X defaults corrected (no sideways
  offset for top preset). Input-blocking (NoInputs flag) when snapped so pet bar input events do
  not pass through. petTargetSnapCachedHeight persisted across sessions. clearPetTargetSpatialState()
  on hide paths.
- config/petbar.lua: Resize anchor combo above Preview Mode. Pet Target anchor help/presets
  ASCII-only labels.
- migration.lua / user.lua: Migrate petBarResizeAnchor from legacy per-type alignBottom. Repair
  petTargetSnapOffsetX >= 100 when anchor is top. Default petBarResizeAnchor in factory defaults.
- handlers/imgui_compat.lua: Hover detection helpers used by pet target cluster drag.
- handlers/helpers.lua: ApplyWindowPosition returns true on the frame it applies a saved position
  so callers can distinguish load/relog from user drag.

Why
- Resize behavior is one global HUD choice regardless of Pet Target snapping or disconnected target
  window. Top snap aligns vertically above the pet bar instead of drifting sideways from old preset
  offsets. Cluster drag moves pet bar and pet target together as a single unit.
'@
        },
        @{
            Branch  = 'pr/24-party-list-fixes'
            Files   = @(
                'modules/partylist/display.lua',
                'handlers/helpers.lua'
            )
            Subject = 'Party list: 1-based buff iteration crash fix and align-bottom anchor drift fix'
            Body    = @'
What changed
- modules/partylist/display.lua:
  Buff/debuff split: loop changed from i=0 to i=1 through #memInfo.buffs. buffs[0] was always nil,
  classified as a debuff, and passed nil into native DrawStatusIcons — causing an intermittent crash
  on login or character swap. Break on nil, -1, and 255 terminators. Local-hoist buff/debuff arrays.
  (Note: this is also a bug in upstream 1.8.0; consider submitting to tirem/XIUI separately.)
  Align-bottom anchor: bottom edge stays fixed when party size changes height. Height-correction
  SetWindowPos syncs windowPositions immediately. On profile/character load, height correction runs
  when saved Y matches applied Y even if height differs (solo vs full party). User drag resets the
  bottom anchor and persists via SaveSettingsOnly() instead of ashita_settings.save() (which
  reloaded the profile and wiped in-memory positions before they could be written).
- handlers/helpers.lua: ApplyWindowPosition returns true on the frame it applies a saved position
  so callers (including partylist align-bottom logic) can distinguish load/relog from user drag.

Why
- Buff fix: eliminates intermittent crashes on login and character swap unrelated to hotbar/crossbar
  changes. Align-bottom fix: party and alliance lists no longer drift on reload, character swap, or
  profile switch; dragged positions stick and do not bleed across profiles.
'@
        },
        @{
            Branch  = 'pr/25-cursor-visibility-popup-ux'
            Files   = @(
                'handlers/imgui_compat.lua',
                'config.lua',
                'config/global.lua'
            )
            Subject = 'Cursor visibility after alt+tab; profile and global popups non-blocking'
            Body    = @'
What changed
- handlers/imgui_compat.lua: Restore the hardware mouse cursor when the FFXI window regains focus
  after alt+tab or a focus-loss event; previously the cursor could disappear until the user moved it.
  Ashita 4.3/4.16 compatibility shim for imgui API differences.
- config.lua: New Profile, Rename Profile, and Delete Profile modals converted from BeginPopupModal
  to BeginPopup (non-blocking); hardware cursor stays visible over FFXI while the popup is open.
  Profile duplicate extends with options.includeMacroLibrary.
- config/global.lua: Same popup-modal-to-popup conversion for any global config dialogs.

Why
- Invisible cursor after alt+tab was a consistent pain point; non-blocking popups keep the cursor
  visible throughout the interaction and match the Palette Manager popup pattern established in
  pr/13.
'@
        }
    )
}
