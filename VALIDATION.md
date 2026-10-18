# Version 0.1.13 validation

## Passed in the current environment

- Frozen-lockfile dependency restoration with `npm ci --ignore-scripts`, activation of the official Electron archive after published SHA256 verification, and Vite production build with a desktop Content Security Policy.
- **95/95 core tests, no skips**, with `DOCTOR_ADDON_TEST_ROOT` and `DOCTOR_LUA51` set. They exercise real filesystem writes, exact-byte ZIP recovery, BOM/CRLF preservation, stale-source refusal, backup failure, path traversal/symlink refusal, literal-only SavedVariables parsing, Unicode, session-token non-persistence, note history, pack serialization, real-addon decoding, WCL pagination/cache normalization, generic HTML/JSON/CSV parsing and five-pull averaging, plus the uploaded LittleWigs/EXBoss source snapshot.
- Generated NSRPACK2 data was accepted by the unchanged `NaowhSmartReminders/NaowhUI_SmartReminders_Packs.lua` **DecodePack**, using native Lua 5.1 and its actual codec libraries. This validates the wire format, not in-game triggering.
- Browser UI smoke: disposable demo → source edit → validate/preview → verified backup/apply → rollback; note save/export; supplied reference HTML; a structurally different CSV mapped to columns; five cached synthetic pulls with mean defensive offset **−3.00 s**. The CSV produces **−2.50 s**. Browser screenshots are in `test-results/`.
- Desktop Electron launch under Linux/Xvfb, production build load, secured preload IPC and demo scan. Tested at 1672×941 and browser layout at 1280×800 without horizontal overflow.
- Application analyzer ran read-only on both selected repositories: NaowhForever 748 Lua files, 14 discovered TOCs (including source-tree modules not necessarily shipped), 0 findings; Smart Reminders 16 Lua files, 1 TOC, 1 advisory TOC-interface warning for declared 120100 versus selected 120105. These limited checks do not establish game compatibility.
- Git status of both original addon repositories remained clean. All app patch/restore tests used temporary folders or the disposable demo.

- New repair checks cover bounded context/fragment merging with CRLF, giant generated-line replacement refusal, provider error messages, injected transport, refresh/delete persistence and source preservation, exact feature anchors, stale context, invalid generated Lua, and behavior branches of the local ConsumableBar compatibility proposal executed in Lua (Fengari).
- Read-only real-module check: NaowhForever_JourneysData, 8 Lua files, no syntax errors; large QuestSpots context limited to 23,967 source characters. A real NaowhForever ConsumableBar error resolves to the correct path and produces a Lua-validated proposal; the source hash remains unchanged.
- Extended UI smoke covers feature request → exact file/anchor → diff, AI context preview, context-menu refresh/delete and persistence, and the removed brand subtitle.
- Desktop checks exercise Electron net.fetch against a controlled local model-list server, clean IPC error messages, and bundled codec access.

- Batch-folder tests cover simultaneous selection, common-directory discovery, duplicates, persistent registrations, new-module discovery on refresh, and removed-folder exclusion. The UI connects two addon folders in one action.
- The preceding v0.1.1 Windows CI completed successfully, including packaged desktop launch, secured IPC, local model transport, pack codec and native ZIP extraction.

- ConsumableBar local proposals also verify macro settings in a separately connected sibling Utilities folder, matching the ordinary WoW AddOns layout. Only registered source roots are read.

## Packaging

Electron 38.8.4 Windows x64 is cross-packaged into a ZIP containing `Pztk x Glyalith.exe`, its runtime DLLs/resources, `START-HERE.txt` and application source/runtime dependencies in app.asar. ZIP compression uses native zlib for Windows extractor compatibility. README.md and VALIDATION.md are also copied beside the executable. The icon/version metadata is set. It is **unsigned**. Downloaded Electron inputs were verified against the official `SHASUMS256.txt` before activation or packaging. Local workspace data, cached user tokens, backups, test fixtures and development dependencies are excluded.

## Not yet established

- Installation and behavior on the user’s own Windows machine, and addon behavior inside Retail/Forever. The user performs these checks.
- Live Warcraft Logs/AI integration with real credentials. Tests use controlled WCL responses; private-report OAuth and Forever API product coverage need real-report validation. A local LLM is not bundled.
- Complete build-specific WoW API coverage, taint/combat-lockdown simulation, fully automatic multi-file repair, automatic M+ whole-run boss segmentation, phase-aware statistical alignment and model-generated note drafting.
- Complete addon-suite green status for Smart Reminders: the prior environment setup found seven fixture failures (`ns.L` / `ns`), assigned to the user. This app does not modify those fixtures.

The provided HTML is an example of input structure, not a verified defensive log or universal class template. Its observed boss-event times and recommended priorities are labeled separately. General tabular imports require explicit column mapping and confirmation that press-time columns contain actual recorded presses.

## Published 0.1.3 bundle

Windows CI [39057209745](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39057209745) packaged the application, launched it to verify secured IPC, local AI transport and the bundled codec, and extracted the ZIP with native Windows tools before publication. The downloaded release matched SHA256 `39868ad40f2124835032f4d1b6b9536f25f1fe0836f2602746d5293f8d2a98f8`, passed all ZIP CRC checks (78 entries), and included the correct Windows x64 PE and versioned ASAR. The downloaded ASAR passed the Linux Electron desktop smoke too. Game behavior remains a user check.

## WCL authentication update

Controlled tests cover V1 Client Key report/event GET requests, fight 57 URL parsing, complete paginated cast timelines and actor/spell provenance; V2 OAuth client-credentials token creation/cache/renewal; distinct V1/V2 credential modes; encrypted save/restart/forget; refusal of plaintext fallback and preservation of unreadable ciphertext; and separate HTTP 404, expired-token and non-JSON diagnostics. The UI smoke selects V1, saves a session key, and forgets it. Windows CI now exercises DPAPI save, desktop restart, decryption, masked UI fields and explicit credential deletion. Live WCL calls remain unverified because the cloud network blocks that destination and the user's key is not available here.

Published 0.1.4 verification: Windows run [39057972118](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39057972118) passed, including the native DPAPI save/restart/decrypt/forget flow, packaged startup, IPC, local model transport, codec and ZIP extraction. The downloaded ZIP matched SHA256 `e79a66d3f579808bfbe21f74a7ae3162a2f3b99f948ad3aa19b6c4ae451429f1`, passed all CRC checks, contained the correct x64 executable and version 0.1.4 source, and its ASAR passed the Linux Electron smoke. No live WCL report/key validation is claimed.

## NSR and AI provider update

The previous decoder's `Decoded pack exceeds limits` error was reproduced with 52,000 table entries. The repaired codec retains entry/depth/expanded-size/time bounds and passes export of a 4,000-reminder plan; both fixtures were accepted by the unchanged real NSR DecodePack under native Lua 5.1. Tests also cover deep valid tables, cyclic references, expansion/decompression limits, per-profile bounds and non-mutating bounded previews. The browser exported all 4,000 reminders, downloaded the complete JSON despite its shortened preview, and cleared stale decoded content after invalid input.

OpenAI Responses and Claude Messages are tested using controlled responses, including distinct authentication headers, independent provider keys/models, model-list checks, incomplete-output refusal and prevention of sending source after its destination changes. Browser tests cover provider selection, clearing key input on switch and retaining separate model settings. Live credential-backed OpenAI/Claude calls remain unverified. At the time of release 0.1.5 the external parser ZIP and EXE exceeded the attachment tool's transfer limit. The user subsequently supplied seven transferable parts; this blocker is resolved by the WCL integration described below.

Published 0.1.5 verification: Windows run [39072250061](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39072250061) succeeded in 2m 16s. The downloaded release matched SHA256 `d8b962d99519b2e1da047081a775a6aa63fff24d73b7f14300f2064c7cab4119`, passed all 78 ZIP entry CRC checks, and contained a Windows x64 executable and version 0.1.5 ASAR. The downloaded ASAR also passed the Linux Electron startup, secured IPC, demo scan, local model transport and bundled NSR codec smoke. This does not establish in-game behavior or external parser integration.

## WCL Lab integration and model picker

The seven supplied archive volumes were reassembled and the ZIP passed CRC verification. Its single EXE was inspected as a self-contained .NET 8 Windows x64 bundle; original version 0.13.0, SHA256 `e6112185b625dd4e3caf595a0e6ae33f9e344459df27308764a469560300ea16`. The shipped resource preserves that executable. CLI command dispatch, report names and DPAPI record format were statically inspected before implementing the adapter. Fixture export uses the engine's built-in synthetic data; its CLI help mentions a folder argument that this version's command dispatch does not consume.

Local core tests exercise a real controlled child process, cancellation/failure/zero-exit-with-missing-report handling, verified extraction/cache repair, interrupted history, bounded previews, path refusal, encrypted credential linking and previous-profile restoration with outside-change detection. Cast import tests check millisecond alignment, report provenance, duplicate removal, malformed-input atomic refusal and synthetic identity refusal. Model-list tests cover account-specific headers, more than 30 models, Claude pagination and non-advancing cursors.

The new browser checks passed controlled engine launch → report/CSV preview → cast import → Encounter Lab; cancellation and credential disconnect; and OpenAI/Claude/local model selection, saved model propagation and feature text preservation. Engine execution itself requires Windows and is checked separately in Windows CI. Real live WCL/AI credentials and Forever-specific event/profile coverage remain unverified.

Native Windows testing found an upstream 0.13.0 fixture incompatibility: built-in fixture JSONL uses `sourceId`/`abilityId`, while the offline reader requires raw WCL `sourceID`/`abilityGameID`. The adapter exposes that failure rather than marking it successful. The native integration check verifies this known failure separately and prepares an explicitly API-shaped synthetic fixture to exercise offline analysis without live credentials. No input files from the user are rewritten.

Published 0.1.6 verification: [Windows run 39073999755](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39073999755) passed in 2m 8s. It launched the original bundled engine, verified DPAPI linking/disconnection, passed its built-in self-tests, generated its sample export, separately verified the known incompatible-sample refusal, and successfully reanalyzed API-shaped synthetic data. It also launched the packaged desktop, ran the engine's installation check through the WCL UI, tested saved WCL credentials across a restart, and extracted the ZIP with Windows tools. The downloaded release matched SHA256 `77b415b14f9016782a29256a74646faa2f82d26dd836a575c2ec0db50f7ea9ac` and passed CRC checks for all 78 entries. Its x64 executable, 0.1.6 ASAR, original engine hash, model picker and native field mappings were verified; the downloaded ASAR passed the Linux Electron smoke. Real WCL/AI account calls remain unverified.


## Search and defensive planner (0.1.7)

Core tests validate literal Unicode/CRLF search, nested-root deduplication, libraries/new files and unchanged source. Browser tests exercise Ctrl+F navigation/case/scroll and Ctrl+Shift+F across two roots with draft retention. Global search reads on-disk sources; session drafts are not persisted across app restarts.

Planner tests cover five independent pulls with −3 s mean/97 s mean press, separate specs/dungeons, CSV m:ss mapping, explicit recorded-data confirmation, reference-only no-mean behavior, duplicate/conflict handling, count-weighted summaries with unknown spread, nearest-cast matching by selected player, context filtering, destination collisions, missing IDs and unsupported trash timing. Original profiles are unchanged and persistent exports survive service restart. The unchanged supplied NSR DecodePack and real Integrations.ValidRule accepted boss/trash and named-profile exports under native Lua 5.1; numeric binding keys, list indices, preserved active presets/disabled states and unrelated profiles were checked.

Browser flow: import original NSR string → attach recorded CSV → calculate five-pull mean → confirm mapping → before/after preview → reviewed NSR string → decode and verify retained settings. Changing inputs clears the previous export. The reference Holy Paladin HTML remains a suggested-priority input, never a source of invented defensive presses. NSR supports one lead time per ability/preset, so exports pool observed offsets; occurrence-specific means stay in the report. Whole-run segmentation, phase-aware alignment, talent/cooldown feasibility, mitigation effectiveness and an optimal rotation are not established. ExBoss is required for the supplied trash integration. Export compatibility is validated for the supplied Retail NSR schema, not as proof of Retail/Forever in-game triggering.


Published 0.1.7 verification: [Windows run 39076463792](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39076463792) passed in 2m 22s. Checks included the bundled engine, native DPAPI restart/forget, packaged planner import → five-pull mean → NSR export over secured IPC, search shortcut, and Windows ZIP extraction. The downloaded release matched SHA256 `7f934e68dfc18f8bf2d7e16237fc96d95ee73ad4bcf01b9964bc098d4ebf64c6`, passed all 78 ZIP CRC checks and x64 PE verification, contained the 0.1.7 planner/search and original engine hash, and its ASAR passed the Linux Electron smoke and planner roundtrip.


## Derived-pack attribution fix (0.1.8)

The blanket rejection of `derivedFrom` was stricter than the unchanged addon: its ExportPack explicitly creates that attribution for curator hand-back and its DecodePack accepts and describes it. Ordinary derived packs now decode/re-encode without dropping that metadata. Account license suffixes (`:LIC1:`) and explicit licensed payloads remain blocked; malformed attribution types have a separate error.

Regression tests cover serializer-produced derived input, non-mutating roundtrip, malformed metadata, continued refusal of signed/account-licensed payloads, note export attribution, persistence/restart and planner exports. Native Lua 5.1 runs the unchanged NSR DecodePack and real trash validator on generated derived single/named packs and asserts retained source name/author. Browser testing includes the planner’s attribution notice and derived profile export, plus reminder-only inspection → editable plan → save → export with the original attribution intact. Live account-license verification remains the addon's responsibility.


Published 0.1.8 verification: [Windows run 39077009398](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39077009398) passed in 2m 29s, including the packaged derived-profile planner roundtrip with original source/author assertions, DPAPI, bundled WCL engine and native ZIP extraction. The downloaded release matched SHA256 `059bac20cde2177a857dc2082f268fbc1f237bfe15a619d0810125357ecc9e4f`, passed CRC checks for all 78 files and x64 PE checks. Its published 0.1.8 codec retains attribution and account-license checks; the downloaded ASAR passed the Linux Electron smoke and derived planner roundtrip.


## Visible application version fix (0.1.9)

Inspection of the downloaded 0.1.7/0.1.8 ASARs confirmed correct package versions but a stale literal `version: '0.1.6'` in the service's init response. This was a display defect in those releases. Init now reads the package version through a module-relative URL, including from app.asar. Desktop smoke compares Electron app.getVersion(), the secured IPC init response and the rendered Application version label, so packaging alone cannot hide a mismatched interface version.


Published 0.1.9 verification: [Windows run 39077998575](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39077998575) passed, including the comparison of Electron package version, secured IPC init.version and the visible Application version label. The earlier run was cancelled by a newer README-only commit, which was preserved. The downloaded 0.1.9 ZIP matched SHA256 `58e50b51db084f0e19fe15266d881cb9db42605479349a8783a7ecd0204e2f72`, passed all 78 CRC and x64 PE checks, and its ASAR passed the Electron smoke with all three versions equal to 0.1.9.


## NSR visual profile editor (0.1.10)

Editor mutations operate on a separately persisted copy of the decoded pack and numeric-key paths. Revision checks plus serialized per-draft writes prevent stale concurrent saves. Unknown fields, other profiles/specs/settings/reminders and derivedFrom attribution are retained. Mutation audit entries are bounded summaries; the imported source and the complete edited pack remain available. Referenced-set deletion and destination collisions are refused. Legacy binding migration and account-license validation remain in NSR; a named Default profile is refused because NSR will not land it.

Seven new core tests exercise ordered sets/Together flags, moving bindings, preservation of unknown data and original strings, refusal of linked-set deletion, concurrent revision conflicts, structured-reference preview/apply, no invented lead times, spec-tag checks, resuming drafts, other named profiles, aura-rule preservation and addon-comment labels without executing Lua. The unchanged addon DecodePack and Integrations.ValidRule accept edited/reference-derived exports under Lua 5.1, with numeric spell keys and list indices intact.

The browser test covers automatic editor opening, named encounters/IDs, priority reordering and fields, reference preset/assignment import, export and decoding, retained unknown fields/settings/other specs/reminders/attribution, reopening the edited copy, transfer of a recorded CSV to the planner and reopening generated output in the editor. It also tests the Project Tools inspector entry. Screenshots show the set and encounter forms. Existing source-patch/backup/restore and planner browser checks remain covered. Desktop smoke now imports a profile in the packaged UI, creates/edits a defensive set and decodes its exported string, retaining the original reminders and attribution.

The desktop does not have the live WoW Encounter Journal. Names are display labels from available profile metadata, connected NSR reference comments, imported tables and cached casts; ambiguous/unavailable names remain explicit IDs. Manual labels do not change timer identity. Boss-mod spell-key mapping, talents, available spells and in-game behavior still require verification. Aura-sound and other profile sections are preserved, not exposed as general raw-code editing. Structured priority-reference HTML/JSON and recorded timing tables are distinct; the former cannot establish mean defensive press times.


## Session, model and NPC database changes (0.1.10)

Controlled tests verify fresh startup with empty project/active timeline lists and preserved notes, profiles, settings and backup identity. Folder reconnection reuses the previous ID. Browser checks exercise Ctrl+A, Ctrl+click, Shift ranges, Shift-drag with auto-scroll and grouped refresh/delete, confirming original files remain. Saved reference/analysis data is retained while old pulls are not automatically reselected.

API model lists come from authenticated provider endpoints per key, never a bundled catalog. Tests separate keys A/B, filter non-text/incompatible entries and reject a selected model absent from the list for its current key. Browser checks cover provider changes and model selection. This establishes request/list behavior against controlled fixtures, not a real user's paid entitlement or quota.

The factual NPC catalog covers eight user-specified dungeons: 248 NPC entries and 1,029 associated spell IDs. Data sources, source filenames, revisions and generation instructions are included in resources/CATALOG-SOURCES.md. Map/challenge IDs and journal/dungeon encounter IDs are separate. The Guardian Druid browser flow creates a profile from scratch, configures Zaen Bladesorrow's Envenom with a defensive set and timing, then configures a trash rule and decodes the exported NSR string. The unchanged real NSR decoder also accepts Guardian (104) bindings with numeric spell keys. Manual trigger-type selection covers boss helpers/lieutenants that lack an independently identified encounter.

English labels use imported/connected references, known names and a persistent tooltip cache. Controlled resolver tests verify cache restoration, no credential forwarding and unresolved-ID behavior. Live tooltip access in this cloud was HTTP 403, so the full external name lookup is not claimed verified here.

Method page requests were denied by the cloud network gateway with HTTP 403. Seven important Altar of Fangs names were transcribed from the user's screenshot without numeric mappings. Local confirmation is explicit and persisted. HTML import parsing is tested against controlled fixtures with and without spell links, section boundaries and failure preservation; the live Method markup and the other seven important lists have not been validated. The primary NPC → ability → defensive set → export workflow does not require Method.


## Published 0.1.10 verification

[Windows run 39113433334](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39113433334), release commit `f07f3c07ceaeeaff83c80b1a5280dd4ad0f5c1db`, completed successfully. It passed core tests (external real-addon/Lua checks retain their explicit CI prerequisites), the native bundled WCL engine checks, packaged Electron launch/IPC/model transport/NSR editor roundtrip, DPAPI persistence and native Windows Expand-Archive extraction before publishing.

The downloaded release matched SHA256 `4b1d9d713a81f7f559a0c69867a0d87454fc367051c816285407198f71685bd0`, passed CRC checks for all 78 ZIP entries, and contains a Windows x64 PE. Its extracted app.asar passed the Electron desktop smoke under Linux, including package/service/visible version equality at 0.1.10, empty startup folder/timeline lists, the bundled eight-dungeon NPC catalog, and the editor's placeholder plus **all 40 named specialization choices**. The desktop test now asserts that count.

All **82/82** core tests passed without skips in this cloud with real NSR and native Lua 5.1. The new exhaustive editor test creates independent sets and boss bindings for every one of the 40 spec IDs, exports them in one profile, and verifies acceptance by unchanged NSR DecodePack. The shared spell in this structural fixture is not a class recommendation. Browser verification also covers the primary NPC/ability/preset flow for a boss and trash, manual important-ID confirmation, two explicit dungeon pull assignments, named spec selection, fresh sessions and retained data.

Earlier Windows attempts exposed a test's comparison of a caller-supplied temporary path with its canonical long Windows path. The assertion now compares the canonical project roots used by the service. No application path checks were weakened. The initial user-cleared README remains unchanged.


## Simplified planner and batch diagnostics (0.1.11)

The default planner now exposes named specialization/dungeon selectors and creature → scoped ability → preset assignment, with automatic saves and direct NSR export. Recorded-log tools and full editing remain under a collapsed Advanced tools section. HTML imports normalize numeric/string spell IDs, object or dictionary presets and ordinary defensive tables across the document. Tests use multiple class formats and a static Discipline Priest table; the user's exact `discipline-priest-smart-reminders-defensive-plan.html` was not attached in this turn and its specific markup has not been inspected.

85/85 core tests passed without skips with external NSR and Lua 5.1. The new catalog assignment route rejects NPC/spell/timer IDs outside the selected dungeon/NPC before mutation. All eight dungeon assignments preserve existing data and their export passes the unchanged NSR decoder and integration rule validator, including NPC provenance metadata. A new browser test follows the simple Discipline Priest import, boss and trash assignment, dungeon switching and export, retaining other specs/settings/attribution. The existing advanced editor, analysis and WCL Lab browser checks also passed.

WCL Lab status exposes only runs started in this process; completed output files and credential data remain available on disk, and interrupted old run metadata is repaired without repopulating the live list. Tests explicitly assert empty lists after reopening while preserving result files. Addon selection is shared with Diagnostics Scan, which scans only the captured selected IDs with one captured client profile, aggregates findings without ID collisions across projects and opens the correct source root. Browser verification selects two of three addons, scans under Forever and checks requests, unselected exclusion and finding navigation.

The exhaustive simple-planner browser test passed for all 40 named specializations: import an independent HTML preset for each selected spec, verify that only that spec's sets are offered, assign a boss ability and decode one export retaining all 40 sets and bindings. Its spell inputs are structural fixtures, not recommended class loadouts. The source Electron smoke also passed after the final UI changes, including the simple HTML import/assignment/export flow and existing advanced editor checks.

## Published 0.1.11 verification

[Windows run 39115777968](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39115777968) succeeded for commit `89f777ab5c5a4472134d7b019ca45ed3071e1390`. It passed core tests with external-addon prerequisites explicitly skipped in CI, native WCL engine checks, packaged desktop launch/IPC/DPAPI, simple planner HTML import → assignment → NSR export, advanced editor checks and native Windows ZIP extraction before publishing.

The downloaded release matched SHA256 `ebd14533f0b1ec39f8cbb72a28780dc287726ba1b441ca7b2344ed62fa9f7d7b`, passed CRC checks for all 78 entries and Windows x64 PE validation. The downloaded app.asar then passed the Electron desktop smoke under Linux, including visible/service/package version equality at 0.1.11, empty startup WCL runs and the simple and advanced NSR workflows. Actual reminder triggering still requires the user's in-game check.


## HTML ids arrays and Mythic+ mechanic selection (0.1.12)

The uploaded `restoration_shaman_priority_presets_EN.html` reproduces the former empty-set error: its object rows use `label`, `ids` arrays and `when`; none of those IDs reached the old scalar-ID importer. The shared normalizer now reads that shape and the document's spell catalog/spec metadata. It does not select a file-specific parser or supply class presets. All 40 named specs passed the same ids-array browser import/assignment/export flow using structural inputs.

The complete uploaded file passed core and browser checks: five original sets plus one alternative Together combination, all original spell IDs, deduplication, retained conditions and catalog names, assignment to Zaen's Murder in a Row (1218347), NSR export/reimport and source-note rendering. Different overlap combinations remain separate presets because the actual addon supports only one Together group per preset. Native Lua 5.1 loaded unchanged NSR DecodePack and accepted the exported profile. All 89 core tests passed without skips. The uploaded file is not bundled or published; a minimal structural reproduction is used by CI when the external path is absent.

The catalog generator statically inspects known Mythic/Retail difficulty branches in LittleWigs options and intersects boss mechanic IDs with each NPC's seasonal MDT spell table. No downloaded Lua is executed. The resulting selectable catalog has 246 NPCs and 794 associations, with original associated IDs retained separately. Tests assert unique IDs/names, seasonal MDT membership for every choice, explicit exclusion of lower-difficulty metadata, and one Murder in a Row choice rather than its effect variants. This verifies the documented source snapshots, not a live difficulty validation from authenticated Warcraft Logs for every entry. See resources/CATALOG-SOURCES.md.

The source Electron smoke passed after the new ids-array import, Together export and single-mechanic UI assertions, preserving existing IPC, version, clean-session, WCL and editor checks.

## Published 0.1.12 verification

[Windows run 39117371836](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39117371836) succeeded for commit `1e11aedd6cdb0fa8700bc65fb628377704f09549`. Native checks covered core behavior (external-addon prerequisites remain explicit), the bundled WCL engine, packaged Electron launch/IPC/DPAPI, generic HTML ids-array import, Together flags in the exported NSR profile, one Murder in a Row choice and Windows ZIP extraction before publication.

The downloaded release matched SHA256 `0bc159a063319bb41f94d55004ad8c5e88ea44874cd0573fd9123f7a69b6af36`, passed all 78 ZIP CRC checks and Windows x64 PE validation. Its downloaded app.asar passed the Electron desktop smoke under Linux with all versions equal to 0.1.12 and the new import/export/catalog assertions. In-game spell availability, timer events and reminder firing remain separate checks.


## Uploaded provider catalogs (0.1.13)

Both user archives were read as source data, with archive and per-file hashes retained in resources/npc-catalog.json. Five requested dungeon module bodies in Midnight.zip match the earlier public snapshot after line-ending normalization; three returning dungeon folders are absent and use the pinned upstream modules. EXBossData's Mythic+ contract and configured triggers cover all eight maps. Only four literal data tables are consumed; no Lua scripts or Factory/defensive packs are run or imported.

95/95 core tests passed without skips. Provider regression tests cover reachable Mythic/Retail handlers, replacement of legacy definitions, absence of unused/Normal/Heroic cooldown evidence, distinction between CastBar and regular timers, English mechanic labels versus boss headers, Unicode literal parsing, event/spell separation, contract exclusions, exact-match precedence and rejection of ambiguous duration joins. Snapshot assertions restore Same-Day Delivery 474765 independently of MDT membership, map Nalorakk and Lightblossom creature encounters, retain Avatar of Sethraliss, and restrict each grouped-boss creature's abilities.

The provider UI test passed assignment/export of the restored LittleWigs key, inspection of Nalorakk's 1243569/1297792 cross-reference, default selection of Spirit of Hunger's actual EXBoss timer 1238687 for displayed cast 1238725, export under instance map 2825 (not challenge mode 586), and per-creature Lightblossom ability choices. The exported boss/trash profile also passed unchanged NSR DecodePack and integration ValidRule under native Lua 5.1. The final source Electron smoke passed the restored key and trash alias through the actual desktop IPC/UI, plus the existing version, clean-session, WCL and profile editor checks. In-game timer availability and firing remain unverified here.

## Published 0.1.13 verification

[Windows run 39133938286](https://github.com/zolo777dh/Pztk-x-Gly/actions/runs/39133938286) succeeded for commit `5ac89ef10f6665b359a1da76b2926cf72cc3bf76`. It passed core behavior (external-addon prerequisites remain explicit), the bundled WCL engine, packaged Electron launch/IPC/DPAPI, restored LittleWigs 474765 assignment, EXBoss timer alias 1238687 with instance map 2825, NSR export and native Windows ZIP extraction before publication.

The downloaded release matched SHA256 `a5b3d230e5f0f88cb5920d92380a7a8c94f39a6d1b12c81fb8d8ec234fe0bdaf`, passed all 78 ZIP CRC checks and Windows x64 PE validation. Its downloaded app.asar passed the desktop smoke under Linux with package/service/visible version 0.1.13 and the new provider-key assertions. Both uploaded source archives are represented by factual data and hashes, not bundled Lua modules or defensive packs.
