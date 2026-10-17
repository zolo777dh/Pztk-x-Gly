Pztk x Glyalith 0.1.5 — Windows x64

- Fixed a false "Decoded pack exceeds limits" failure when exporting large reminder plans. Count/depth handling now matches per-profile NSR limits; Lua stack reservation handles valid deep tables. Export of 4,000 reminders and a 52,000-entry fixture passed the unchanged real addon decoder.
- Added bounded previews for large packs and Save decoded JSON for the complete result. Invalid/edited input clears stale decoded previews. Entry, depth, decompression, expansion, processing and license checks remain enforced.
- Added explicit OpenAI / ChatGPT GPT-model and Anthropic Claude integrations. OpenAI uses Responses API, Claude uses Messages API; other compatible/local endpoints keep Chat Completions. Models and session API keys are separate per provider. Provider/model/destination changes require preparing context again; incomplete output cannot become a partial replacement.
- Full Russian CHANGELOG.md now records versions 0.1.0–0.1.5. Existing multi-folder, reviewed patch/backup, WCL V1/V2 and DPAPI credential features remain available.

Extract the entire ZIP into a new folder and launch Pztk x Glyalith.exe. API keys for OpenAI/Claude are required separately from web subscriptions; cloud model keys remain session-only. WCL encrypted saved credentials stay in the Windows user-data directory. Code proposals still require review and in-game validation. Live provider calls with user credentials have not been verified here. Third-party EXE parser integration is not included: the user's file has not yet been supplied.
