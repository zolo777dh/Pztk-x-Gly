# Pztk x Glyalith

Standalone Windows desktop prototype for diagnosing **NaowhForever** (all discovered modules) and **Naowh Smart Reminders**, preparing source patches, encounter notes and reminder packs. It is not a WoW addon.

**[Download Windows x64 ZIP](https://github.com/zolo777dh/Pztk-x-Gly/releases/download/v0.1.8/Pztk-x-Glyalith-0.1.8-Windows-x64.zip)** · [Release and checksum](https://github.com/zolo777dh/Pztk-x-Gly/releases/tag/v0.1.8)

[История всех изменений / Changelog](CHANGELOG.md)

## Available features

- Dark blue/yellow three-pane desktop UI based on the supplied visual reference, with separate build profiles for Retail `12.1.5.70448` and Forever `1.60.1.70425` (English game data).
- Lua 5.1 syntax analysis, recursive TOC/XML dependency and case checks, discovery of all module TOCs, and a small set of advisory legacy API rules. UTF-8 strings are handled as Lua bytes. This is **not a complete build-specific WoW API database**, type checker, taint simulator or in-game runtime.
- BugSack text import and literal-only parsing of Lua SavedVariables; no SavedVariables code is executed. Inspect stored profiles and Smart Reminders `observed` data. Files reflect the last `/reload`, logout or exit. There is no direct game-memory/live-widget access.
- Full-file patch previews and unified diffs; Lua syntax validation; SHA256 freshness checks; BOM/CRLF preservation; verified per-patch ZIP backups and rollback. Manual source snapshots include Lua/TOC/XML source files (not media, account settings or the entire WoW installation). Binary/non-UTF-8 source edits are refused.
- Local encounter plans with assignments, reminder rows, JSON import/export and up to 20 saved revisions.
- `NSRPACK2:` reminder-only export using LibSerialize plus standard raw DEFLATE and the matching print alphabet. Encoded strings have been accepted by the **actual Smart Reminders DecodePack** implementation. Initial export uses approximate pull-relative text reminders, for all players or a role. Encounter ID must be confirmed. Stage/boss-mod timing mappings are not inferred from spell IDs. Generated timing must be tested in game.
- Unlicensed pack inspection. Only the supported reminder-only subset can be copied into an editable plan; full profiles remain read-only. Derived packs keep their original attribution during editing/export. Account-licensed packs must be managed in the addon; no licensing restrictions are removed.
- Warcraft Logs report/fight selection, event pagination, caching and multiple-report import; cached timeline JSON import/export.
- **Encounter Lab:** compare several pulls of the same encounter/difficulty. Select boss and defensive spell IDs, player-name filter, cast/begincast anchor and matching window. Each defensive cast is matched to the nearest boss event once; repeated same-player/spell casts for one occurrence contribute the closest press. Display mean, median, range, population standard deviation and coverage. Occurrences are ordinal, so phase alignment requires review. Missing observations are not zeroes; unknown client builds remain unverified. Observed usage is not proof of an optimal or necessary defensive.
- General reference-file import: HTML, JSON and CSV. Embedded JSON with `presets`/`assignments` is recognized without class-specific rules. Static tables and flat JSON object arrays can be explicitly mapped to encounter, ability, boss/press time, occurrence, difficulty and independent-pull columns. Script-only rendered HTML may have no extractable data and is refused. No scripts, handlers or remote HTML resources execute.
- The user's Holy Paladin document is retained as an **example reference**, not a universal rule or source of recorded defensive presses. Its recommendations remain distinct from actual log measurements. New documents are parsed on import and can use different classes/encounters/columns.

## Hybrid AI

In Settings use **Load available models**, choose from **Available models**, then **Save Settings**. OpenAI, Claude and local/compatible servers each have their own model list. Manual Model ID entry remains available if a server does not expose a list. In Describe a feature, **AI SOURCE** chooses Local/Cloud and **Choose model in Settings** opens configuration without losing the request.

In Settings, configure an **OpenAI-compatible** endpoint/model. A local model is not bundled. For example, install Ollama on Windows, run `ollama pull qwen2.5-coder:7b`, keep its server running, and use `http://127.0.0.1:11434/v1` with model `qwen2.5-coder:7b`. Hardware requirements depend on the chosen model. For cloud assistance select OpenAI / GPT (ChatGPT model family), Anthropic / Claude, or another OpenAI-compatible API. Enter a model ID and that provider’s API key, then Save Settings. OpenAI uses Responses; Claude uses Messages; compatible/local servers use Chat Completions. Web ChatGPT/Claude subscriptions do not supply API access. Models and session keys are separate per provider; switching providers clears the key input. Live calls require your own API access and have not been validated with user credentials.

**Analyze selected file** first shows a bounded source fragment (up to 24,000 source characters), build and trimmed issue details. Choose the focus line for large files. **Send fragment** sends only that displayed context. The actual provider/model is displayed and bound to the reviewed context; changing it requires a new preview. A complete enclosing function is preferred; clipped single-line generated data is analysis-only. Returned fragments are merged into the original source, preserving other lines. **Test local/cloud connection** checks the configured server and model list; no cloud key is sent to localhost. Desktop requests use Electron’s system network/proxy stack with TLS verification enabled. Returned source is never applied automatically; it still requires preview, validation and a backup. Keys are **memory-only for the current session**, cleared on exit/disconnect; endpoint and model settings persist. Automated note drafting and automatic dependency-wide repair are not implemented. No automatic Git commits or pushes are performed in connected addon repositories.

**Describe a feature** is available from Diagnostics, Patch Assistant and Project Tools. Describe the desired behavior in Russian or English, optionally choose an existing Lua file, then prepare and review the exact context. The app supplies a bounded file index, loader and up to four source fragments. **Generate code proposal** asks your configured local/cloud model for a single-file change with a unique exact source anchor. The result identifies the Lua file, insertion line and position, then opens a syntax-checked diff. Ambiguous anchors, unprovided paths, stale source and invalid Lua block the proposal. If the model needs new modules, several files or more context, it should explain that instead of proposing a write. Generated code still needs in-game review.

**Suggest Fix** checks verified local rules without a model. The first rule covers the reported ConsumableBar `ns.ModuleOn` nil call when the matching macro-settings implementation is available in the complete source tree or in the separately connected sibling NaowhForever_Utilities folder. It offers a compatibility fallback to loaded macro settings; this does not repair the core loader or establish why `ModuleOn` was absent. Check earlier errors and addon versions. Other errors can use the hybrid model workflow.

**Connect several folders at once:** the + button opens a multi-selection folder picker (Ctrl/Shift on Windows). You can also select a common directory: addon TOCs at that level and in immediate subfolders are discovered and added as separate list entries, with no duplicates. The first connected folder is scanned initially; choose the others to scan them. Browser development mode accepts one folder path per line. Refresh also discovers new addon folders under the original selected directory. Folders explicitly removed from the list stay excluded from refresh until manually reconnected.

Right-click a connected addon for **Refresh / Delete folder**. Refresh reindexes new/deleted files and subfolders, rescans, and invalidates old patch/feature plans. Reimport runtime logs afterward. Delete folder removes only its workspace registration; disk files and ZIP backups are kept. `NaowhForever_JourneysData` can be connected by its TOC folder or indexed under the full addon repository.

## Large reminder packs

The decoder counts table entries per profile, matching the supplied NSR validation limit (100,000 entries / 32 data-table levels), rather than counting keys and values twice. Export of a 4,000-reminder plan and a 52,000-entry fixture was accepted by the unchanged addon decoder. Input remains capped at 130,000 encoded characters and 4,000,000 decompressed bytes. Additional inspection limits are 1,000,000 total entries, 16,000,000 expanded JSON bytes, 64 outer table levels and bounded processing time. Limits and license checks are not disabled.

Large previews are sampled to keep the interface usable. **Save decoded JSON** exports the complete decoded payload, not the sampled preview. Changing the input or a failed decode clears the old preview. Full-profile packs remain read-only; supported reminder-only packs retain the existing copy-to-plan workflow.

## Integrated WCL Lab

The **WCL** tab includes the supplied **bgmt x warcraftlogs lab 0.13.0** Windows x64 engine. Its original binary is bundled, checked by SHA256 and invoked in the background through its supported CLI. No separate parser window or installation is required.

- Start with **Check engine installation** or **Generate sample export**. The latter creates synthetic data; it cannot become a real encounter sample. Upstream 0.13.0 writes those built-in sample JSONL files in a different schema from its offline reader, so reanalyzing that sample reports a source-ID error. Use saved raw API exports for offline reanalysis.
- **Analyze saved export** accepts the engine's raw-export folder or ZIP. Offline reanalysis does not call WCL. HTML/CSV reference documents still use Encounter Lab's existing importer.
- **Export WCL links** accepts up to 30 links, one per line. Include fight/source parameters for the desired encounter and player.
- **Find & analyze top logs** accepts zone IDs and encounter IDs prefixed with `e`, plus top count, starting rank and a per-run limit. **Survey specializations** accepts `Class:Spec[:dps|hps]` pairs and encounter IDs. These use the original engine's CLI defaults; not every option from its separate GUI is exposed.
- Choose a specialization key such as `holypaladin`, `protpaladin`, `shadow` or `disc`. The engine owns its spell catalogs; the app's Retail/Forever selector does not rewrite them. Forever report availability and build-specific accuracy require real-data validation.

Each run has an independent output folder, bounded log, status and previewable JSON/JSONL/CSV/text files. Stop cancels the process; closing the app stops an active engine too. Partial and interrupted results are retained but cannot be imported as complete timelines. A one-hour process limit prevents an abandoned operation running indefinitely. Use **Open result folder** for complete files.

Live Lab commands require **V2 Client ID / Client Secret** saved in Settings, then **Connect saved V2 client to Lab** in WCL. A V1 key or standalone Access Token does not configure this engine. The secret is encrypted with Windows DPAPI, using stdin rather than command arguments or environment variables. The engine uses `%LOCALAPPDATA%\bgmt x warcraftlogs lab\credentials.dat`; an existing independent record is preserved and restored on disconnect. An outside change blocks automatic restoration. Forgetting the app's WCL key also disconnects a linked Lab client. Linking creates a persistent engine credential record even if the app's own Remember key option is off; disconnect Lab to remove that link.

**Import casts** beside an exported `fight.json` adds recorded hostile/selected-player casts to cached timelines. **Compare pulls & draft reminders** opens the existing comparison workflow. It preserves report/fight identity and milliseconds-to-pull-time conversion, removes duplicate events and refuses synthetic identities. This is a partial cast stream, not every raid member's casts. Engine analytics include decision context, pairing, resource/HP snapshots, cooldowns, auras, deaths and data-quality reports when supported by the source data.

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


## Source search

**Ctrl+F** in Patch Assistant opens literal search in the current editor, including unsaved edits. Enter/Shift+Enter and F3/Shift+F3 move through matches; Escape closes it. Case and whole-word options are available. **Ctrl+Shift+F**, or the search icon beside Addons, searches text across every connected addon root, including libraries and modules. Results show project, file, line and column; clicking opens the exact match. Temporary drafts survive file/project navigation in this session. Global search reads disk, so apply edits before expecting them in global results. It skips binary/oversized/non-UTF-8 files, symlinks and development caches and explicitly reports bounded/partial results. Text formats outside Lua/TOC/XML open read-only.

## Defensive profile planner

Open **WCL → Defensive profile planner**. Its workflow is **import an NSRPACK2 profile → inspect existing spec presets → choose dungeon/encounter mechanic spell IDs → attach recorded tables or cached casts → review observed means and proposed bindings → export a new NSRPACK2 profile string**. No addon or SavedVariables file is written; import the result into NSR and verify it in game. The original string is stored separately in the app's user data. Single and named-profile packs are supported; only the selected named profile is updated. Derived packs are supported with their original `derivedFrom` attribution retained for personal edits and curator hand-back. Account-licensed packs remain outside the supported re-export workflow.

- Attach HTML/CSV/JSON tables and map columns. A CSV header template is available. Recorded rows need dungeon, encounter, bossSpellId, specId, defensiveSpellId, bossTime, defensiveTime and an independent sample/pull ID; include player, occurrence, difficulty and build where known. Times are seconds or `m:ss`, on the same pull-relative clock. A row's spec ID is authoritative; one class's fallback priorities are not copied to another spec.
- Canonical JSON uses `{ "format": "pztk-defense-observations-v1", "observations": [...] }`. Each observation has those same fields. Aggregated rows may use `sampleCount` only after confirming disjoint samples. Their means are count-weighted; within-group variance is unavailable. Do not combine summaries with the individual presses they summarize.
- The supplied Holy Paladin priority HTML supplies suggested priority lists and mechanic times, **not recorded defensive presses**. It can seed mechanic selection and same-spec fallbacks; it cannot produce a defensive press mean by itself.
- Import multiple reports with the existing WCL tools, then assign cached fights to dungeon/encounter, player and spec. The planner matches recorded defensive casts from that spec's original presets (plus explicitly entered extra IDs) to the nearest mechanic in the chosen before/after window. A whole M+ run needs explicit encounter/pull segmentation first. Selection does not infer talents, verify mitigation, or prove an optimal cooldown rotation.
- Results keep dungeons, encounters, specs, known difficulty/build contexts and occurrences distinct. Exact duplicate observations are excluded; conflicting duplicates are refused. Mixed contexts that would overwrite the same binding must be filtered before export. Review means, counts, spread and per-occurrence results before selecting export rows.
- Confirm the actual in-game `dungeonEncounterID` for bosses, instance `mapID` for trash and the timer-provider spell key. A WCL spell ID can differ from a boss-mod key. Boss export updates `abilityBindings`; trash export uses the supplied NSR addon’s `integrationRules` and requires its ExBoss timer provider. Unsupported trash offsets are blocked rather than silently shifted.
- The current NSR schema stores **one lead time per ability/preset**. The export uses the pooled observed offset, while per-defense and per-occurrence means remain in the analysis. Generated lists rank observed usage, then retain same-spec reference/existing fallbacks; they do not enforce a time-specific rotation. Existing disabled bindings remain disabled. Generated healer-category bindings also follow NSR’s existing healer-reminder toggle; enable that category in the addon if needed.
- Preview shows before/after bindings. After reviewing, copy/save the new string. Existing presets, active choices, other profiles/settings and unrelated reminders are retained, including numeric Lua keys. Export compatibility is tested against the supplied Retail NSR schema; behavior in Retail/Forever remains an in-game check.
