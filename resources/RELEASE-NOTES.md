Pztk x Glyalith 0.4.0 + Pztk Reminders 0.1.0

This release includes a separate in-game addon, Pztk Reminders. Existing NSR / NSRT addons are not modified.

- Reminders workspace: one working profile for defensive sets, Mythic+ / raid mechanic bindings, raid assignments and timed reminders. Export one native PZTK1 string and import it with /pztkr.
- Time / phase / ability-timer / mechanic-message triggers; spec / role / player / everyone recipients; spell icons, text, sounds and frame glows, with additional bar/circle/TTS displays. Timeline dragging prepares an edit that must be saved.
- Independent in-game scheduler, target/difficulty filters, defensive priority/Together selection, BigWigs / DBM callbacks and ExBoss trash timers. Profile imports create new saved copies and are separated by client. Conflicting NSR / NSRT / TimelineReminders installations pause live dispatch; disable those addons when using Pztk Reminders.
- Migrate supported NSRPACK2 and current NSRT scheduled alerts through the desktop. OR target conditions and countdown lead times are preserved for supported entries. Review exclusions before export; source data remains local. No guessed TimelineReminders string decoder is included without a verified format/sample.
- Retail 12.1.5.70448 and Forever 1.60.1.70425 targets remain unchanged. Bundled Midnight S1/S2 encounter references belong to Retail; Forever uses manual/imported encounters.
- Existing all-40-spec set imports, diagnostics, source search, AI Workspace and source backup/recovery remain available. Legacy NSR / NSRT compatibility editors are retained separately.

Install: extract the Windows bundle and run Pztk x Glyalith.exe. Extract PztkReminders-0.1.0.zip into WoW Interface/AddOns, disable NSR / NSRT / TimelineReminders and import the desktop's PZTK1 string through /pztkr. Test in both live clients. Interface declarations and code tests do not verify every game API or provider trigger. The addon does not press abilities or bypass secret cooldown data.
