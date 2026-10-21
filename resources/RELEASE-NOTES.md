Pztk x Glyalith 0.5.0 + Pztk Reminders 0.2.0

NSR migration now handles native aura sounds and authored defensive reminders instead of skipping them with one warning per rule.

- Supported NSR custom reminders become editable native entries with specialization, priority set, occurrence condition and delay. Counter OR/AND conditions are compiled as data; imported Lua is never executed. Unknown conditions are reported rather than silently widened.
- ExBoss and auraSound rules, custom callout text, default lead time, fallback and supported voice/display settings survive PZTK1 conversion. The report groups issues and identifies the specialization and source rule, with a downloadable JSON report.
- Open editable migrated copy creates a native profile for changes while retaining the original source. Dynamic defensive actions choose available spells from the assigned set at dispatch. Referenced sets cannot be deleted without reassignment.
- Aura sounds use the game's native C_UnitAuras.AddAuraSound API. Registrations are scoped to specialization, instance and map, deduplicated and deferred during restrictions. Stoneform/Shadowmeld cues use private sound files gated by public racial readiness. Unavailable/secret readiness stays muted; missing native APIs are reported in /pztkr debug. No aura contents are read.
- Repeated mechanic messages keep independent delayed reminders. Opening BigWigs messages survive encounter-start callback ordering; stale opening messages are discarded. Existing bar pause/resume and ExBoss cycle protections remain.
- Migration retains unavailable settings but reports them: cdmGlow, coveredSkip, coveredSkipDefaultOn and coveredCastWindow do not have runtime implementations. Missing preset references need review; ExBoss's existing empty-text active-set fallback is preserved. A conversion report is not a claim of complete behavioral equivalence.

Replace the desktop with the complete Windows ZIP and the PztkReminders folder with addon 0.2.0 while WoW is closed. Keep PztkRemindersDB SavedVariables. Profiles using the new behavior require addon 0.2.0. Keep NSR / NSRT / TimelineReminders disabled while testing this separate addon.

Targets remain Retail 12.1.5.70448 and Forever 1.60.1.70425. Native aura sounds require the corresponding public client API; Forever support is not inferred from Retail. Provider packages are installed separately. No live WoW session was available: codec roundtrips, source replays and controlled API tests cover the documented paths. Original addon sources and private user profiles are not published or changed. Licensed source packs remain excluded from conversion.
