# Pztk x Glyalith 0.4.1 + Pztk Reminders 0.1.1

Pztk x Glyalith is a Windows desktop app for planning profiles for **Pztk Reminders**, a separate WoW addon that combines defensive priorities, raid assignments and timed encounter reminders. Addon maintenance and AI tools remain in the same desktop application.

- **One native export:** PZTK1 contains configured defensive sets, Mythic+ / raid mechanic bindings and scheduled assignments. Import it in Pztk Reminders with `/pztkr`.
- **In-game diagnostics:** `/pztkr debug` prepares a copyable client, build, provider-version and connection report for troubleshooting alongside BugSack errors.
- **Reminder model:** time, phase, ability timer or mechanic message → specialization, role, player or everyone → spell icon, text, sound or player-frame glow. Bar/countdown, circle and TTS displays are also supported.
- **Timeline planning:** inspect reminders and drag markers to prepare new times, then save explicitly.
- **Defensive planning:** all 40 specializations, shared M+ / Raid set editors, and supported HTML/JSON imports. Public spell readiness selects available priorities / Together groups; inaccessible cooldown data is not guessed.
- **Migration:** existing NSRPACK2 working profiles and supported current NSRT Profile / full EncounterAlert schedules; warnings, skipped entries and original NSRT strings are retained for review. Unsupported source sections remain in the desktop working copy. TimelineReminders export strings require a confirmed format/sample and are not advertised as decoded.
- **Two clients:** Retail 12.1.5.70448 and Forever 1.60.1.70425, with separate profile workspaces. Retail catalogs use the supplied Midnight S1/S2 reference snapshot: eight M+ dungeons and 20 raid bosses. Forever uses imported/manual encounters.
- **Addon maintenance:** multiple folders, batch scans, refresh and source search. Removing an entry never deletes files. Diagnostics cover Lua syntax, TOC/XML load references, interface declarations and advisory GetSpellInfo / GetSpellCooldown / GetSpellCharges / GetItemSpell migration checks; BugSack/BugGrabber imports are supported.
- **Optional AI:** selected-module context, saved conversations, local/cloud APIs and a ChatGPT/Claude website panel with manual transfer. Cloud requests send reviewed source/error context; website subscriptions and API billing are separate.
- **Reviewed source changes:** per-file diffs, syntax validation, verified backups, stale-source protection and restoration. Tasks, profiles and backups are local; API keys are session-only. Addons starts empty each launch.

The separate addon has its own runtime, displays, SavedVariables and PZTK1 import/export. It pauses live reminders when NSR, NSRT or TimelineReminders is loaded, preventing competing engines. It does not modify or uninstall those addons. Boss timers and phases need matching provider events; ExBoss supplies trash timers. Glows require supported visible frames. No live game or authenticated assistant website session was tested in the build environment.

See [START-HERE.txt](START-HERE.txt) and the included addon INSTALL.txt for installation.
