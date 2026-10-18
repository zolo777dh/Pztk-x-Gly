Pztk x Glyalith 0.2.0 — Windows x64

- WCL / BGMT Lab and Encounter Notes are replaced by Defensive Planner (M+) and Raid Planner.
- One shared NSR profile contains defensive sets for all 40 specializations, Mythic+ boss/trash bindings and raid bindings. Import HTML sets or an existing NSRPACK2 profile, edit sets, assign mechanics and export one string.
- M+ uses the existing eight-dungeon Mythic+ catalog. Raid has 20 bosses from the supplied NorthernSkyRaidTools reference, with Heroic / Mythic ability filters. Shared abilities use the same assignment; no automatic difficulty switching is needed.
- Browser assistant: prepare/review a request, copy it into ChatGPT or Claude in your normal browser, then paste/upload the JSON reply. Lua validation and patch preview precede a separate Backup & Apply action. No API key is needed in Browser mode. Optional local/cloud API modes remain available.
- Removed bundled BGMT engine, WCL credentials UI, online log imports, run history and defensive timing averages. Existing local profiles/backups and original addon files are preserved.

Quick start: extract the whole archive to a normal folder, then launch “Pztk x Glyalith.exe”.
Defensive Planner / Raid Planner → select specialization → Import profile / HTML → select dungeon/boss and ability → choose a defensive set → Export NSR. Sets and assignments are shared across both tabs and saved locally.

The NSR decoder accepts the exported combined profile. In-game triggers still depend on the installed boss-mod events: the raid catalog records source spell IDs and confirmed NSR aliases, not a live verification of every boss-mod timer. Test the profile inside WoW. Trash reminders require NSR's ExBoss integration. This application does not press abilities or modify the original addon repositories.
