# Pztk x Glyalith 0.3.0 — application capabilities

Pztk x Glyalith is a Windows desktop app for WoW addon maintenance and defensive reminder planning, focused on NaowhForever, its modules, Naowh Smart Reminders (NSR), and Northern Sky Raid Tools (NSRT) profiles.

- **Retail & Forever:** separate client targets and profile workspaces.
- **Addon management:** connect multiple folders, batch scan, refresh, remove from the list, and search source files.
- **Diagnostics:** check Lua syntax, loader dependencies, interface declarations, and selected API migration issues; import BugSack/BugGrabber errors.
- **AI Workspace:** investigate errors, explain code, and generate features using context from selected addon modules, with saved tasks and conversations.
- **ChatGPT & Claude:** embedded website panel with manual prompt/reply transfer, plus optional local and cloud APIs. Website subscriptions and API billing are separate.
- **Reviewed code changes:** per-file diffs, syntax validation, verified backups, stale-source protection, and restoration.
- **NSR planning:** import supported HTML/JSON or existing profiles, edit defensive sets for all 40 specializations, and assign them to Mythic+ or raid mechanics. Export one NSR profile covering configured M+ and raid rules.
- **Raid support:** Heroic/Mythic selection, native NSRT profile editing and export, and generation from shared raid assignments using reference phase schedules.
- **Local persistence:** saved tasks, profiles, and backups; the Addons list starts empty each launch. API keys are session-only.

NSR and NSRT use separate export strings. NSRT displays scheduled reminders rather than reproducing NSR's cooldown-based defensive selection. Diagnostics are advisory, and game behavior still requires testing in WoW. The bundled encounter catalogs cover Retail Midnight; Forever encounters use imported or manually configured data. WCL/BGMT parsing is not included.

See [START-HERE.txt](START-HERE.txt) for usage instructions.
