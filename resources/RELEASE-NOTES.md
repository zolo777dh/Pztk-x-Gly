Pztk x Glyalith 0.3.0 — Windows x64

A unified desktop workspace for addon diagnostics, AI-assisted source changes and NSR / NSRT profile preparation.

- AI Workspace: persistent tasks and conversations, selected-project context, related Lua symbol candidates, TOC/XML loader references, bounded source excerpts and explicit Retail / Forever build context. Review the request before sending.
- ChatGPT / Claude websites can open in a sandboxed panel inside the application. Use your website account and subscription; copy the request into the site and paste its JSON reply into the task. External browser fallback remains available. Website login support depends on the provider.
- Optional local API and cloud API use the same workspace. Cloud model lists are loaded for your API key; API access is separate from a website subscription. API keys are kept only for the current app session.
- Review changes across multiple addon modules, select files, validate Lua 5.1 syntax and apply with a verified ZIP backup. New Lua/TOC/XML files are supported in existing addon directories. Source changes invalidate stale proposals. Failed writes roll back earlier writes; task backups can restore the original files.
- Native NSRT profiles: import/export current !NSRT:Profile: and full !NSRT:EncounterAlert: strings; visually edit raid reminders, phase schedules, Heroic/Mythic difficulty and specialization filters. Unknown imported fields are retained. Previous profile revisions can be restored.
- Raid assignments can build a separate NSRT profile, optionally based on a copy of an existing NSRT profile. Source phase schedules produce reminders for the assigned defensive set, with its first spell icon. NSRT does not reproduce NSR's cooldown-based selection. Generation reports skipped assignments.
- Retail and Forever have separate NSR / NSRT working profile lists and active NSR drafts. The bundled eight-dungeon M+ and 20-boss raid catalogs are Retail Midnight data. Forever uses its imported / manually configured encounters, rather than the Retail catalog.
- Existing selected-addon batch scans, BugSack/BugGrabber imports, code search, folder selection / refresh / removal, shared M+ and raid NSR exports and all 40 specialization choices remain available. Addons starts empty each launch; profile and task history persist.
- WCL / BGMT integration and timing-average analysis remain removed. App changes do not publish local addon edits to their GitHub repositories.

Extract the complete ZIP into a normal folder, then launch “Pztk x Glyalith.exe”. No Node.js installation is required.

See START-HERE.txt and resources/APP-CAPABILITIES.md in the source repository for the complete workflow and limitations. Check generated patches and reminder behavior inside WoW. Account-licensed addon packs remain subject to the addon's licensing rules.
