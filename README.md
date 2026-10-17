# Pztk x Glyalith

Standalone Windows desktop prototype for diagnosing **NaowhForever** (all discovered modules) and **Naowh Smart Reminders**, preparing source patches, encounter notes and reminder packs. It is not a WoW addon.

**[Download Windows x64 ZIP](https://github.com/zolo777dh/Pztk-x-Gly/releases/download/v0.1.4/Pztk-x-Glyalith-0.1.4-Windows-x64.zip)** · [Release and checksum](https://github.com/zolo777dh/Pztk-x-Gly/releases/tag/v0.1.4)

[История всех изменений / Changelog](CHANGELOG.md)

## Try the Windows app

1. Extract the entire `Pztk-x-Glyalith-0.1.4-Windows-x64.zip` archive to a writable folder.
2. Open `Pztk x Glyalith.exe` inside the extracted folder. Keep its DLLs, `resources` and other files alongside it. Node, Python and Lua are not required on the user's PC.
3. Click **Open disposable demo** to try the interface without touching real addons.
4. Click **+** beside Addons and choose a folder containing an addon `.toc`, for example `Interface\AddOns\NaowhSmartReminders`. Add the Forever root separately. Development checkout layout and individually installed module folders can both be connected.
5. Select the correct client profile and **Scan Project**. Import BugSack error text or a BugGrabber SavedVariables file. Existing logs are historical evidence; rescan alone does not prove a runtime error is fixed.
6. Select a file, open **Patch Assistant**, edit the complete file or request AI assistance, then **Validate & preview**. **Create Backup & Apply** verifies a ZIP before writing. Test the result in game.
7. Open **Project Tools → Backup & patch history → Restore** to undo a patch. Restoration creates another backup and refuses changed files.

The prototype is unsigned. The packaged desktop has been launched in Windows CI and under Linux Electron. Its behavior on your own Windows installation and inside the game still needs user verification.

## Available features

- Dark blue/yellow three-pane desktop UI based on the supplied visual reference, with separate build profiles for Retail `12.1.5.70448` and Forever `1.60.1.70425` (English game data).
- Lua 5.1 syntax analysis, recursive TOC/XML dependency and case checks, discovery of all module TOCs, and a small set of advisory legacy API rules. UTF-8 strings are handled as Lua bytes. This is **not a complete build-specific WoW API database**, type checker, taint simulator or in-game runtime.
- BugSack text import and literal-only parsing of Lua SavedVariables; no SavedVariables code is executed. Inspect stored profiles and Smart Reminders `observed` data. Files reflect the last `/reload`, logout or exit. There is no direct game-memory/live-widget access.
- Full-file patch previews and unified diffs; Lua syntax validation; SHA256 freshness checks; BOM/CRLF preservation; verified per-patch ZIP backups and rollback. Manual source snapshots include Lua/TOC/XML source files (not media, account settings or the entire WoW installation). Binary/non-UTF-8 source edits are refused.
- Local encounter plans with assignments, reminder rows, JSON import/export and up to 20 saved revisions.
- `NSRPACK2:` reminder-only export using LibSerialize plus standard raw DEFLATE and the matching print alphabet. Encoded strings have been accepted by the **actual Smart Reminders DecodePack** implementation. Initial export uses approximate pull-relative text reminders, for all players or a role. Encounter ID must be confirmed. Stage/boss-mod timing mappings are not inferred from spell IDs. Generated timing must be tested in game.
- Unlicensed pack inspection. Only the supported reminder-only subset can be copied into an editable plan; full profiles remain read-only. Account-licensed/derived packs are refused rather than unwrapped. No licensing restrictions are removed.
- Warcraft Logs report/fight selection, event pagination, caching and multiple-report import; cached timeline JSON import/export.
- **Encounter Lab:** compare several pulls of the same encounter/difficulty. Select boss and defensive spell IDs, player-name filter, cast/begincast anchor and matching window. Each defensive cast is matched to the nearest boss event once; repeated same-player/spell casts for one occurrence contribute the closest press. Display mean, median, range, population standard deviation and coverage. Occurrences are ordinal, so phase alignment requires review. Missing observations are not zeroes; unknown client builds remain unverified. Observed usage is not proof of an optimal or necessary defensive.
- General reference-file import: HTML, JSON and CSV. Embedded JSON with `presets`/`assignments` is recognized without class-specific rules. Static tables and flat JSON object arrays can be explicitly mapped to encounter, ability, boss/press time, occurrence, difficulty and independent-pull columns. Script-only rendered HTML may have no extractable data and is refused. No scripts, handlers or remote HTML resources execute.
- The user's Holy Paladin document is retained as an **example reference**, not a universal rule or source of recorded defensive presses. Its recommendations remain distinct from actual log measurements. New documents are parsed on import and can use different classes/encounters/columns.

## Hybrid AI

In Settings, configure an **OpenAI-compatible** endpoint/model. A local model is not bundled. For example, install Ollama on Windows, run `ollama pull qwen2.5-coder:7b`, keep its server running, and use `http://127.0.0.1:11434/v1` with model `qwen2.5-coder:7b`. Hardware requirements depend on the chosen model. For cloud assistance enter your provider's HTTPS API base, model ID and key.

**Analyze selected file** first shows a bounded source fragment (up to 24,000 source characters), build and trimmed issue details. Choose the focus line for large files. **Send fragment** sends only that displayed context. A complete enclosing function is preferred; clipped single-line generated data is analysis-only. Returned fragments are merged into the original source, preserving other lines. **Test local/cloud connection** checks the configured server and model list; no cloud key is sent to localhost. Desktop requests use Electron’s system network/proxy stack with TLS verification enabled. Returned source is never applied automatically; it still requires preview, validation and a backup. Keys are **memory-only for the current session**, cleared on exit/disconnect; endpoint and model settings persist. Automated note drafting and automatic dependency-wide repair are not implemented. No automatic Git commits or pushes are performed in connected addon repositories.

**Describe a feature** is available from Diagnostics, Patch Assistant and Project Tools. Describe the desired behavior in Russian or English, optionally choose an existing Lua file, then prepare and review the exact context. The app supplies a bounded file index, loader and up to four source fragments. **Generate code proposal** asks your configured local/cloud model for a single-file change with a unique exact source anchor. The result identifies the Lua file, insertion line and position, then opens a syntax-checked diff. Ambiguous anchors, unprovided paths, stale source and invalid Lua block the proposal. If the model needs new modules, several files or more context, it should explain that instead of proposing a write. Generated code still needs in-game review.

**Suggest Fix** checks verified local rules without a model. The first rule covers the reported ConsumableBar `ns.ModuleOn` nil call when the matching macro-settings implementation is available in the complete source tree or in the separately connected sibling NaowhForever_Utilities folder. It offers a compatibility fallback to loaded macro settings; this does not repair the core loader or establish why `ModuleOn` was absent. Check earlier errors and addon versions. Other errors can use the hybrid model workflow.

**Connect several folders at once:** the + button opens a multi-selection folder picker (Ctrl/Shift on Windows). You can also select a common directory: addon TOCs at that level and in immediate subfolders are discovered and added as separate list entries, with no duplicates. The first connected folder is scanned initially; choose the others to scan them. Browser development mode accepts one folder path per line. Refresh also discovers new addon folders under the original selected directory. Folders explicitly removed from the list stay excluded from refresh until manually reconnected.

Right-click a connected addon for **Refresh / Delete folder**. Refresh reindexes new/deleted files and subfolders, rescans, and invalidates old patch/feature plans. Reimport runtime logs afterward. Delete folder removes only its workspace registration; disk files and ZIP backups are kept. `NaowhForever_JourneysData` can be connected by its TOC folder or indexed under the full addon repository.

## Warcraft Logs setup and limits

In Settings choose the credential type you actually have:

- **V1 Client Key** uses the legacy `/v1/report/fights` and `/v1/report/events` GET API with its `api_key` parameter. A V1 key is never sent as a V2 bearer token. V1 availability and access still depend on Warcraft Logs.
- **V2 Access Token** uses the GraphQL API with Bearer authorization. A manually supplied token can expire.
- **V2 Client ID / Client Secret** obtains an OAuth client-credentials token and renews it when needed. Private user reports may require a user-authorized V2 token and `/api/v2/user`; client-credentials access is not an account login.

Enable **Remember Warcraft Logs key** and Save Settings to persist credentials using Electron safeStorage (Windows DPAPI, tied to your Windows account). The encrypted credential file is separate from workspace.json, exports and addon backups. No plaintext fallback is used; without system encryption only session storage is allowed. **Forget saved key** removes the encrypted file and clears credentials. Cloud AI keys remain session-only.

**Test WCL connection** checks the selected API; **Check report access** checks a specific report URL. HTTP 401/403/404 and non-JSON responses now have separate diagnostics. The supplied report link with `?fight=57` is parsed correctly. Live access to the user's report is not verified in this cloud environment: outbound WCL connections are restricted and no private key was supplied. Pagination, authentication, token renewal and normalization are tested with controlled responses.

Open Encounter Notes → Encounter Lab → Multiple WCL links. Load report metadata, select exact fights and import them. Then compare compatible cached pulls. Cast start/completion and actor IDs remain distinct. Event IDs in WCL are not automatically boss-mod trigger IDs. For M+ runs reported as a single fight, boss-only segmentation/encounter mapping must be confirmed; v0.1 does not infer a boss encounter ID from a whole-run ID.

## Data and source safety

Workspace state, notes, caches and verified backups live in Electron's user data folder, normally `%APPDATA%\Pztk x Glyalith\workspace`. **Project Tools → Open backup folder** opens the actual location. Game source writes happen only through a reviewed patch. SavedVariables are read-only in this version; use supported addon import dialogs for pack updates. There is no network service in the packaged desktop app.

## Develop

Node 22+ and npm are needed for source development. Dependencies are pinned in `package-lock.json`.

```sh
npm ci
npm run build
npm start
```

Browser development (two terminals): `npm run dev` for the local-only backend, and `npm run dev:ui` for Vite. The backend accepts JSON requests only from the exact local UI origin. It must not be exposed to a network. Production uses Electron's isolated preload IPC with Node integration disabled.

```sh
npm test
npm run test:ui        # development servers + Chromium required
npm run package:win    # Windows x64 ZIP, can also cross-package on Linux
```

Set `DOCTOR_CHROMIUM` to a Chromium executable for browser tests. To run the real-addon codec compatibility test additionally set `DOCTOR_ADDON_TEST_ROOT` to the Smart Reminders checkout and `DOCTOR_LUA51` to Lua 5.1. The compatibility check is explicitly skipped if those external prerequisites are unavailable. `tests/desktop.mjs` is a Linux/Xvfb Electron smoke test.

If Electron downloads require the environment HTTPS proxy, use a supported download proxy or download the official versioned Electron ZIP and `SHASUMS256.txt`, verify the published checksum, then pass its directory via `DOCTOR_ELECTRON_ZIPS`. Never disable TLS or checksum verification. Prepared cloud caches contain verified Electron 38.8.4 Linux/Windows archives.

Use the existing isolated workspaces; do not create Git worktrees unless explicitly requested. The selected addon repositories remain unchanged during app development and tests; patch/restore tests run only in temporary folders or the disposable demo.

See `THIRD_PARTY_NOTICES.md` for bundled library notices.
