# Version 0.1.2 validation

## Passed in the current environment

- Frozen-lockfile dependency restoration with `npm ci --ignore-scripts`, activation of the official Electron archive after published SHA256 verification, and Vite production build with a desktop Content Security Policy.
- **28/28 core tests, no skips**, with `DOCTOR_ADDON_TEST_ROOT` and `DOCTOR_LUA51` set. They exercise real filesystem writes, exact-byte ZIP recovery, BOM/CRLF preservation, stale-source refusal, backup failure, path traversal/symlink refusal, literal-only SavedVariables parsing, Unicode, session-token non-persistence, note history, pack serialization, real-addon decoding, WCL pagination/cache normalization, generic HTML/JSON/CSV parsing and five-pull averaging.
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

## Packaging

Electron 38.8.4 Windows x64 is cross-packaged into a ZIP containing `Pztk x Glyalith.exe`, its runtime DLLs/resources, `START-HERE.txt` and application source/runtime dependencies in app.asar. ZIP compression uses native zlib for Windows extractor compatibility. README.md and VALIDATION.md are also copied beside the executable. The icon/version metadata is set. It is **unsigned**. Downloaded Electron inputs were verified against the official `SHASUMS256.txt` before activation or packaging. Local workspace data, cached user tokens, backups, test fixtures and development dependencies are excluded.

## Not yet established

- Native execution on Windows and addon behavior inside Retail/Forever. The user performs these checks.
- Live Warcraft Logs/AI integration with real credentials. Tests use controlled WCL responses; private-report OAuth and Forever API product coverage need real-report validation. A local LLM is not bundled.
- Complete build-specific WoW API coverage, taint/combat-lockdown simulation, fully automatic multi-file repair, automatic M+ whole-run boss segmentation, phase-aware statistical alignment and model-generated note drafting.
- Complete addon-suite green status for Smart Reminders: the prior environment setup found seven fixture failures (`ns.L` / `ns`), assigned to the user. This app does not modify those fixtures.

The provided HTML is an example of input structure, not a verified defensive log or universal class template. Its observed boss-event times and recommended priorities are labeled separately. General tabular imports require explicit column mapping and confirmation that press-time columns contain actual recorded presses.
