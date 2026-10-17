Pztk x Glyalith 0.1.4 — Windows x64

- Added a dedicated V1 Client Key mode for Warcraft Logs. Legacy keys use V1 report/event GET endpoints, not V2 Bearer authorization. V2 Access Token and Client ID / Secret remain separate options; client-credentials tokens renew automatically.
- Remember Warcraft Logs key saves credentials with Windows DPAPI. Keys are outside workspace exports and addon backups, restored after restart, and removable with Forget saved key. No plaintext fallback.
- Added Test WCL connection and Check report access, plus specific HTTP/authentication diagnostics. Live access to the user's report still needs validation with their key; this cloud network blocks WCL.
- Multi-folder connection in one action: Ctrl/Shift selection or a common parent folder. Addon folders appear as separate entries without duplicates; refresh discovers new modules while respecting folders removed from the list.
- Removed the subtitle below the application name.
- Right-click an addon for Refresh / Delete folder. Refresh indexes new subfolders and expires old plans; deletion removes only the registration, keeping local source and backups.
- Bounded AI source context with a preview before sending and fragment merging, instead of sending oversized full files. Added model connection tests and actionable connection errors; desktop requests use the system network stack.
- Suggest Fix offers a verified local compatibility proposal for ConsumableBar's missing ns.ModuleOn call when the matching macro implementation is present, including a separately connected sibling Utilities addon. Review earlier core errors and consistent addon versions too.
- Describe a feature: request a change in Russian or English, review context, then generate code with a concrete existing Lua file and exact insertion anchor. One file per proposal, syntax-checked diff, verified backup before applying. Requires your configured model.
- Windows ZIP uses zlib compression and application ASAR packaging. The build checks Windows extraction and launches the packaged desktop before publishing.

Extract the entire ZIP into a new folder and launch Pztk x Glyalith.exe. Keep its resources/DLLs beside it. Existing workspace settings and backups remain in the user-data directory. No Node.js installation is needed to run the bundle. The app does not commit or push to addon repositories.

The application is unsigned. In-game behavior, complete WoW API compatibility and live credential-backed provider/report access still require user validation. Local models are installed separately. Backups contain source files, not the entire WoW installation or WTF folder. See README.md and VALIDATION.md.
