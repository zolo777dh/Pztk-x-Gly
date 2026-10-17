# Version 0.1.6 validation

## Passed in the current environment

- Frozen-lockfile dependency restoration with `npm ci --ignore-scripts`, activation of the official Electron archive after published SHA256 verification, and Vite production build with a desktop Content Security Policy.
- **55/55 core tests, no skips**, with `DOCTOR_ADDON_TEST_ROOT` and `DOCTOR_LUA51` set. They exercise real filesystem writes, exact-byte ZIP recovery, BOM/CRLF preservation, stale-source refusal, backup failure, path traversal/symlink refusal, literal-only SavedVariables parsing, Unicode, session-token non-persistence, note history, pack serialization, real-addon decoding, WCL pagination/cache normalization, generic HTML/JSON/CSV parsing and five-pull averaging.
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
